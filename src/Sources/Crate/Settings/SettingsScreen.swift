// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// JIT, memory, logs and the licenses.
struct SettingsScreen: View {
    @Environment(JITSession.self) private var jit

    @AppStorage(SettingsKey.jitMethod) private var jitMethod = JITMethod.standard.rawValue
    @AppStorage(SettingsKey.jitAtLaunch) private var jitAtLaunch = true
    @AppStorage(SettingsKey.codeRegionMB) private var codeRegionMB = CodeRegion.standard
    @AppStorage(SettingsKey.logsEnabled) private var logsEnabled = true
    @AppStorage(SettingsKey.logsTrackMemory) private var trackMemory = true

    @State private var memory = MemoryReport()
    @State private var logURL: URL?
    @ScaledMetric(relativeTo: .body) private var statusDotSize = 9

    var body: some View {
        NavigationStack {
            Form {
                jitSection
                memorySection
                logsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task { await refreshMemory() }
            .onAppear { logURL = logsEnabled ? LogExport.prepare() : nil }
        }
    }

    // MARK: - JIT

    private var jitSection: some View {
        Section {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: statusDotSize, height: statusDotSize)
                    Text(statusText)
                }
            }
            if !jit.isOn {
                Button {
                    Task { await jit.turnOn(JITMethod(rawValue: jitMethod) ?? .standard) }
                } label: {
                    HStack {
                        Label("Turn On JIT", systemImage: "bolt.fill")
                        if jit.isTurningOn {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(jit.isTurningOn || jit.state == .checking || jit.state == .off(.notEligible))
            }
            Picker("Method", selection: $jitMethod) {
                ForEach(JITMethod.allCases) { method in
                    Text(method.title).tag(method.rawValue)
                }
            }
            .pickerStyle(.menu)
            Button {
                jit.showingSetup = true
            } label: {
                Label("JIT Diagnostics & Status", systemImage: "bolt.badge.checkmark")
            }
            Toggle("Turn on JIT when crate opens", isOn: $jitAtLaunch)
            Picker("Code region", selection: $codeRegionMB) {
                ForEach(CodeRegion.choices, id: \.self) { mb in
                    Text("\(mb) MB").tag(mb)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("JIT")
        } footer: {
            Text(jitFooter)
        }
    }

    private var statusText: String {
        switch jit.state {
        case .checking: "Checking…"
        case .on(let mb): "On, \(mb) MB code region"
        case .off where jit.isOn: "Pretending On"
        case .off: "Off"
        case .failed: "Didn't Work"
        }
    }

    private var statusColor: Color {
        switch jit.state {
        case .on: .green
        case .failed: .orange
        case .off where jit.isOn: .green
        case .checking, .off: .gray
        }
    }

    private var selectedMethod: JITMethod {
        JITMethod(rawValue: jitMethod) ?? .standard
    }

    private var jitFooter: String {
        var parts: [String] = []
        if let problem = jit.problem { parts.append(problem) }
        parts.append("Dopamine RootHide JIT is activated natively in-process. Crate needs JIT memory to execute translated instructions for virtual machines.")
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Memory

    private var memorySection: some View {
        Section {
            LabeledContent("Increased limit",
                           value: memory.hasIncreasedLimit ? "Yes" : "No")
            LabeledContent("Memory limit") {
                Text(memory.limit.map { Format.memory($0) } ?? "Not reported")
                    .monospacedDigit()
            }
            LabeledContent("Available memory") {
                Text(memory.available.map { Format.memory($0, decimals: 2) } ?? "Not reported")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            LabeledContent("Total memory") {
                Text(Format.memory(memory.physical))
                    .monospacedDigit()
            }
        } header: {
            Text("Memory")
        } footer: {
            Text(memoryFooter)
        }
    }

    private var memoryFooter: String {
        if memory.available == nil {
            return "The Simulator has no memory limit, so iOS reports nothing here. On an iPhone these come from iOS and update every few seconds."
        }
        return "A VM's memory comes out of the available memory, up to the limit iOS sets. The increased-memory-limit entitlement raises the limit."
    }

    /// Re-reads the figures every few seconds while Settings is on screen.
    private func refreshMemory() async {
        while !Task.isCancelled {
            withAnimation { memory = MemoryReport() }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    // MARK: - Logs

    private var logsSection: some View {
        Section {
            Toggle("Collect Logs", isOn: $logsEnabled)
                .onChange(of: logsEnabled) { _, on in
                    AppLog.setEnabled(on)
                    logURL = on ? LogExport.prepare() : nil
                }
            Toggle("Track Memory Use", isOn: $trackMemory)
                .disabled(!logsEnabled)
            if let logURL {
                ShareLink(item: logURL) {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("Logs")
        } footer: {
            Text(logsFooter)
        }
    }

    private var logsFooter: String {
        guard logsEnabled else {
            return "crate isn't logging, and has deleted its logs."
        }
        var text = "crate logs what it and the VM engine do, this launch and the last, so "
            + "Export Logs can share them for a bug report."
        if trackMemory {
            text += " Track Memory Use adds crate's memory use every \(MemoryLog.interval) seconds "
                + "while a VM runs, about 40 KB an hour, so the log shows if iOS closed crate for using too much."
        }
        return text
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            NavigationLink("Acknowledgements") { AcknowledgementsScreen() }
        } header: {
            Text("About")
        } footer: {
            Text("crate is open source under the MPL-2.0, and carries code from other projects under their own licenses.")
        }
    }
}
