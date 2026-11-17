// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation

/// The installed VMs.
///
/// Persisted to UserDefaults as JSON; each VM's files are in its own folder
/// (GuestFiles).
@Observable
final class MachineStore {
    private(set) var machines: [Machine] {
        didSet { save() }
    }

    private static let machinesKey = "machines"

    init() {
        defer { removeStrayFiles() }
        let defaults = UserDefaults.standard
        // From when a starred VM booted at launch.
        defaults.removeObject(forKey: "defaultMachineID")
        if let data = defaults.data(forKey: Self.machinesKey),
           let saved = try? JSONDecoder().decode([Machine].self, from: data) {
            // v0.1 started with the sample VMs, which have no image and no files.
            machines = saved.filter { $0.imageID != nil || GuestFiles(for: $0).exists }
            for machine in saved where !machines.contains(machine) {
                AppLog.write("store: removed \(machine.name), which has no files")
            }
            if machines.count != saved.count { save() }
        } else {
            machines = []
        }
    }

    func add(_ machine: Machine) {
        machines.append(machine)
    }

    /// Saves a change to `machine`'s settings.
    func update(_ machine: Machine) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        machines[index] = machine
    }

    /// Removes `machine` from the list and its files from the iPhone.
    func delete(_ machine: Machine) {
        machines.removeAll { $0.id == machine.id }
        GuestFiles(for: machine).remove()
    }

    /// Its card's preview was saved: the card loads it again.
    func previewSaved(_ machine: Machine) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        machines[index].previewDate = .now
    }

    func markStarted(_ machine: Machine) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        machines[index].lastStarted = .now
    }

    func isInstalled(_ image: CatalogImage) -> Bool {
        machines.contains { $0.imageID == image.id }
    }

    /// Puts the sample VMs back, for previewing the UI.
    func restoreSamples() {
        machines = Machine.samples.map { var copy = $0; copy.id = UUID(); return copy }
    }

    /// An empty list, for previewing the UI (`--empty`): the VMs' files stay.
    func removeAll() {
        machines = []
    }

    /// Deletes VM folders no VM in the list names: what an install that was
    /// stopped partway (crate closed or suspended) left behind.
    private func removeStrayFiles() {
        let known = Set(machines.map(\.id.uuidString))
        let folders = (try? FileManager.default.contentsOfDirectory(at: GuestFiles.root,
                                                                     includingPropertiesForKeys: nil)) ?? []
        for folder in folders where UUID(uuidString: folder.lastPathComponent) != nil
            && !known.contains(folder.lastPathComponent) {
            try? FileManager.default.removeItem(at: folder)
            AppLog.write("store: removed \(folder.lastPathComponent), which no VM names")
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(machines) {
            UserDefaults.standard.set(data, forKey: Self.machinesKey)
        }
    }
}
