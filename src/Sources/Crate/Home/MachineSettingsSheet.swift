// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// One VM's settings, from its card's menu: its memory, and on iPhone Duo how
/// its screen sits.
struct MachineSettingsSheet: View {
    let machine: Machine

    @Environment(MachineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hasHinge) private var hasHinge

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Memory limit", selection: memoryGB) {
                        ForEach(memoryChoices, id: \.self) { gb in
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

                if hasHinge {
                    Section {
                        Toggle("Full Width in Landscape", isOn: fullWidth)
                    } header: {
                        Text("Display")
                    } footer: {
                        Text("With iPhone Duo open in landscape, the desktop runs under the toolbar to the edge of the screen, the toolbar's buttons over it. Off, it stops beside them.")
                    }
                }
            }
            .navigationTitle("\(machine.name) Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Memory

    /// What Install offers, and the VM's own if it's something else.
    private var memoryChoices: [Int] {
        Set(InstallScreen.memoryChoices + [current.memoryGB]).sorted()
    }

    /// The guest learns its memory as it boots, so a change waits for the next
    /// start: a running VM keeps what it started with.
    private var memoryFooter: String {
        var text = "The most memory the VM may use. A change applies the next time the VM starts."
        if let limit = MemoryReport().limit, UInt64(current.memoryGB) << 30 > limit {
            text += " crate can only claim \(Format.memory(limit)) on this \(UIDevice.current.localizedModel), so the VM gets less."
        }
        return text
    }

    private var memoryGB: Binding<Int> {
        Binding(
            get: { current.memoryGB },
            set: { gb in
                var changed = current
                changed.memoryGB = gb
                store.update(changed)
            })
    }

    // MARK: - Display

    /// Saved as it changes, from the store's copy: the sheet's own may be stale.
    private var fullWidth: Binding<Bool> {
        Binding(
            get: { current.isFullWidthInLandscape },
            set: { on in
                var changed = current
                changed.fullWidthInLandscape = on
                store.update(changed)
            })
    }

    private var current: Machine {
        store.machines.first { $0.id == machine.id } ?? machine
    }
}
