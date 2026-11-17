// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Pick a system image from the catalog and a memory limit, give the account
/// to make in it, then install it.
struct InstallScreen: View {
    @Environment(MachineStore.self) private var store
    @Environment(Installer.self) private var installer
    @Environment(\.dynamicTypeSize) private var typeSize

    let onShowHome: () -> Void

    @State private var catalog = CatalogState.loading
    @State private var selectedID: String?
    @AppStorage(SettingsKey.installMemoryGB) private var memoryGB = 6
    /// The size last picked, which may not be one this image or device offers:
    /// `diskGB` is the one that's used.
    @AppStorage(SettingsKey.installDiskGB) private var pickedDiskGB = DiskSize.standard
    @State private var askingForAccount = false
    @State private var confirmingCancel = false

    /// The memory limits a VM can have, here and in its settings.
    static let memoryChoices = [2, 4, 6, 8, 10, 12]

    /// The disk sizes the slider stops at, for the selected image.
    private var diskStops: [Int] {
        DiskSize.stops(for: selected, deviceBytes: Format.totalDiskBytes())
    }

    /// The VM's disk: the size picked, or the nearest this image and device
    /// allow. A sparse file, so it takes only what the guest writes.
    private var diskGB: Int {
        DiskSize.nearest(to: pickedDiskGB, in: diskStops)
    }

    enum CatalogState {
        case loading
        case loaded([CatalogImage])
        case failed(String)
    }

    private var images: [CatalogImage] {
        if case .loaded(let images) = catalog { return images }
        return []
    }

    private var selected: CatalogImage? {
        images.first { $0.id == selectedID } ?? images.first
    }

    /// Nil when iOS doesn't say, in which case Install stays available.
    private var freeBytes: Int64? { Format.freeDiskBytes() }

    /// The disk as unpacked, and one part of the download beside it.
    private func neededBytes(_ image: CatalogImage) -> Int64 {
        image.installedBytes + (image.disk.parts.map(\.size).max() ?? 0)
    }

    private var hasRoom: Bool {
        guard let selected else { return false }
        return freeBytes.map { $0 >= neededBytes(selected) } ?? true
    }

    var body: some View {
        NavigationStack {
            List {
                imagesSection
                    .disabled(installer.isBusy)

                Section {
                    Picker("Memory limit", selection: $memoryGB) {
                        ForEach(Self.memoryChoices, id: \.self) { gb in
                            Text("\(gb) GB").tag(gb)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Memory Limit")
                } footer: {
                    Text(memoryFooter)
                }
                .disabled(installer.isBusy)

                Section {
                    diskSlider
                } header: {
                    Text("Disk Size")
                } footer: {
                    Text(diskFooter)
                }
                .disabled(installer.isBusy)

                // At the accessibility text sizes a pinned bar would cover half
                // the screen, so Install scrolls with the list instead.
                if typeSize.isAccessibilitySize {
                    Section {
                        installControls
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Install Vms")
            .safeAreaInset(edge: .bottom) {
                if !typeSize.isAccessibilitySize, selected != nil || installer.phase != .idle {
                    installControls
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .background(.bar)
                }
            }
            .task { await loadCatalog() }
            .refreshable { await loadCatalog() }
            .onChange(of: selectedID) {
                // A finished install belongs to the image it was for.
                if case .done = installer.phase { installer.reset() }
            }
            .sheet(isPresented: $askingForAccount) {
                if let selected {
                    AccountSheet(image: selected) { owner in
                        askingForAccount = false
                        installer.install(selected, memoryGB: memoryGB, diskGB: diskGB, owner: owner, into: store)
                    }
                }
            }
            .alert(cancelTitle, isPresented: $confirmingCancel) {
                Button("Stop Installing", role: .destructive) { installer.cancel() }
                Button("Keep Installing", role: .cancel) {}
            } message: {
                Text("What's downloaded so far is discarded.")
            }
        }
    }

    @ViewBuilder
    private var imagesSection: some View {
        Section {
            switch catalog {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .foregroundStyle(.secondary)
                    Button("Try Again") { Task { await loadCatalog() } }
                }
                .padding(.vertical, 4)
            case .loaded(let images):
                ForEach(images) { image in
                    CatalogRow(
                        image: image,
                        isSelected: image.id == selected?.id,
                        isInstalled: store.isInstalled(image)
                    ) {
                        selectedID = image.id
                    }
                }
            }
        } header: {
            Text("Linux")
        }
    }

    private func loadCatalog() async {
        if case .loaded = catalog {} else { catalog = .loading }
        do {
            let fetched = try await Catalog.fetch()
            catalog = .loaded(fetched.images)
        } catch {
            if case .loaded = catalog { return }
            catalog = .failed(error.localizedDescription)
        }
    }

    private var memoryFooter: String {
        var text = "The most memory the VM may use. You can change it later in the VM's settings."
        if let limit = MemoryReport().limit, UInt64(memoryGB) << 30 > limit {
            text += " crate can only claim \(Format.memory(limit)) on this \(UIDevice.current.localizedModel), so the VM gets less."
        }
        return text
    }

    // MARK: - Disk size

    /// The size, then a slider over the stops.
    @ViewBuilder
    private var diskSlider: some View {
        let stops = diskStops
        LabeledContent("Disk", value: "\(diskGB) GB")
            .monospacedDigit()
        if stops.count > 1 {
            Slider(value: diskStopIndex(in: stops), in: 0...Double(stops.count - 1), step: 1) {
                Text("Disk Size")
            } minimumValueLabel: {
                Text("\(stops[0]) GB")
            } maximumValueLabel: {
                Text("\(stops[stops.count - 1]) GB")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityValue("\(diskGB) GB")
        }
    }

    private func diskStopIndex(in stops: [Int]) -> Binding<Double> {
        Binding(
            get: { Double(stops.firstIndex(of: diskGB) ?? 0) },
            set: { pickedDiskGB = stops[min(stops.count - 1, max(0, Int($0.rounded())))] })
    }

    /// The free space isn't given as a number here: the disk's size is binary
    /// GB, as memory's is, and the Install bar's free space decimal, as the
    /// Settings app's is, so a number here would disagree with one or the other.
    private var diskFooter: String {
        let device = UIDevice.current.localizedModel
        var text = "The most the VM can store. It's set now and can't be changed once the VM is installed. "
            + "It takes up space on this \(device) as the VM writes, plus up to about "
            + "\(Format.memory(DiskSize.setAside(diskGB))) that Linux sets aside as it starts using a disk this size."
        if let free = freeBytes, Int64(diskGB) << 30 > free {
            text += " That's more than this \(device) has free: "
                + "if the \(device) fills up first, the VM can't save anything more."
        }
        return text
    }

    private var cancelTitle: String {
        "Stop Installing \(installer.image?.name ?? "")?"
    }

    // MARK: - Install controls

    @ViewBuilder
    private var installControls: some View {
        VStack(spacing: 8) {
            switch installer.phase {
            case .idle:
                if let selected {
                    Button {
                        askingForAccount = true
                    } label: {
                        Label("Install \(selected.name)", systemImage: "arrow.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(!hasRoom)
                    Text(spaceNeeded(selected))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            case .downloading(let done, let total):
                progress(title: "Downloading \(installer.image?.name ?? "")…",
                         value: total > 0 ? Double(done) / Double(total) : 0,
                         detail: "\(Format.bytes(done)) of \(Format.bytes(total)) · Keep crate open until it's done.",
                         cancellable: true)
            case .unpacking(let done, let total):
                progress(title: "Unpacking \(installer.image?.name ?? "")…",
                         value: total > 0 ? Double(done) / Double(total) : 0,
                         detail: "\(Format.bytes(done)) of \(Format.bytes(total)) · Keep crate open until it's done.",
                         cancellable: true)
            case .finishing:
                progress(title: "Installing \(installer.image?.name ?? "")…", value: nil,
                         detail: "Checking the disk and setting up your account", cancellable: false)
            case .done(let machine):
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("\(machine.name) is installed")
                            .font(.headline)
                        Text("Its first start sets up your account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Go to Home") {
                        installer.reset()
                        onShowHome()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            case .failed(let message):
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.subheadline)
                    Spacer()
                    Button("OK") { installer.reset() }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            }
        }
    }

    private func progress(title: String, value: Double?, detail: String, cancellable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if cancellable {
                    Button("Cancel") { confirmingCancel = true }
                }
            }
            if let value {
                ProgressView(value: value)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func spaceNeeded(_ image: CatalogImage) -> String {
        let needed = neededBytes(image)
        guard let free = freeBytes else {
            return "Downloads \(Format.bytes(image.downloadBytes)) · needs \(Format.bytes(needed)) of storage"
        }
        if free < needed {
            return "Free up \(Format.bytes(needed - free)) to install \(image.name)."
        }
        return "Downloads \(Format.bytes(image.downloadBytes)) · needs \(Format.bytes(needed)) · \(Format.bytes(free)) available"
    }
}

/// The disk sizes a new VM can have, in GB (binary, as the memory limit's are).
enum DiskSize {
    /// Finer where a few GB matter, coarser where they don't.
    static let allStops = [16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024]
    static let standard = 32
    /// Room for the guest to write beyond the image's own filesystem, at least.
    static let headroomGB = 8

    /// The stops for `image`: from its filesystem plus some room, up to the
    /// device's whole capacity. The disk is sparse, so more than is free now
    /// is allowed, but not more than the device could ever hold.
    static func stops(for image: CatalogImage?, deviceBytes: Int64?) -> [Int] {
        let gib = Int64(1) << 30
        let imageGB = image.map { Int(($0.disk.size + gib - 1) / gib) } ?? 0
        let smallest = allStops.first { $0 >= imageGB + headroomGB } ?? allStops[allStops.count - 1]
        let largest = deviceBytes.map { Int($0 / gib) } ?? Int.max
        let stops = allStops.filter { $0 >= smallest && $0 <= largest }
        return stops.isEmpty ? [smallest] : stops
    }

    /// What Linux writes across a new ext4 disk of `gb` once it's grown to
    /// it: zeroed inode tables, 256 bytes for every 16 KiB, a 64th of the
    /// disk. crate's disk can't be told to leave zeros unwritten, so they take
    /// real space on the device. btrfs (Omarchy) writes none of it.
    static func setAside(_ gb: Int) -> UInt64 {
        (UInt64(gb) << 30) / 64
    }

    /// The stop nearest `picked`: a size picked for one image may not be
    /// offered for another.
    static func nearest(to picked: Int, in stops: [Int]) -> Int {
        stops.min { abs($0 - picked) < abs($1 - picked) } ?? standard
    }
}

/// The account to make in the VM, asked for before installing: the user name
/// and password to sign in with, and the computer's name.
struct AccountSheet: View {
    let image: CatalogImage
    let onInstall: (SeedDisk) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var user = ""
    @State private var password = ""
    @State private var hostname = ""
    /// The password in the clear: with no second field to type it again in,
    /// it's how a typo gets caught.
    @State private var showsPassword = false
    @FocusState private var passwordFocused: Bool

    private var userValid: Bool { SeedDisk.isValid(user: user) }
    private var hostnameValid: Bool { SeedDisk.isValid(hostname: hostname) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("User Name", text: $user)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    passwordField(shown: showsPassword)
                } header: {
                    Text("Your Account")
                } footer: {
                    if !user.isEmpty && !userValid {
                        Text("Lowercase letters, numbers, \"-\" and \"_\", starting with a letter.")
                    } else {
                        Text("What you sign in to \(image.name) with. crate keeps only a hash of the password.")
                    }
                }
                Section {
                    TextField("Computer Name", text: $hostname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if !hostname.isEmpty && !hostnameValid {
                        Text("Lowercase letters, numbers and \"-\".")
                    } else {
                        Text("The name \(image.name) goes by on the network.")
                    }
                }
            }
            .navigationTitle("Install \(image.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Install") {
                        onInstall(SeedDisk(user: user, password: password, hostname: hostname,
                                           timeZone: TimeZone.current.identifier,
                                           vendorData: image.vendorData))
                    }
                    .disabled(!userValid || password.isEmpty || !hostnameValid)
                }
            }
            .onAppear {
                if hostname.isEmpty { hostname = image.distributionID }
            }
        }
    }

    /// The password field, and the eye that shows or hides what's in it.
    /// Swapping the field drops the keyboard, so focus is put back.
    private func passwordField(shown: Bool) -> some View {
        HStack {
            Group {
                if shown {
                    TextField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("Password", text: $password)
                }
            }
            .textContentType(.newPassword)
            .focused($passwordFocused)
            Button(shown ? "Hide Password" : "Show Password",
                   systemImage: shown ? "eye.slash" : "eye") {
                let wasFocused = passwordFocused
                showsPassword.toggle()
                if wasFocused { DispatchQueue.main.async { passwordFocused = true } }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }
}

/// One downloadable image: its name with the version beside it, and a check
/// when selected. At the accessibility text sizes the version goes under the
/// name.
struct CatalogRow: View {
    let image: CatalogImage
    let isSelected: Bool
    let isInstalled: Bool
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 14) {
                text
                Spacer(minLength: 0)
                checkmark
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 3) {
            let nameAndVersion = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
            nameAndVersion {
                Text(image.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .layoutPriority(1)
                Text(image.version)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            Text(details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
        }
    }

    /// "KDE Plasma · 1.5 GB", and "· Installed" once there's a copy on Home.
    private var details: String {
        var parts = [image.desktop, Format.bytes(image.downloadBytes)]
        if isInstalled { parts.append("Installed") }
        return parts.joined(separator: " · ")
    }

    private var checkmark: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
    }
}
