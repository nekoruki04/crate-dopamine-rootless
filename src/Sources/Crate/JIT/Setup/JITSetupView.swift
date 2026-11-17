// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct JITSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JITSession.self) private var jit
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: jit.isOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(jit.isOn ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(jit.isOn ? "JIT Active" : "JIT Inactive")
                                .font(.headline)
                            Text(statusSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Jailbreak Environment") {
                    LabeledContent("Target", value: "Dopamine RootHide")
                    LabeledContent("Architecture", value: "arm64 / arm64e")
                    LabeledContent("Activation Mode", value: "In-Process Native")
                    if let region = jit.region {
                        LabeledContent("Code Region Size", value: "\(region.size >> 20) MB")
                        LabeledContent("Exec Base", value: String(format: "0x%llx", UInt64(UInt(bitPattern: region.executable))))
                        LabeledContent("Write Mirror", value: String(format: "0x%llx", UInt64(UInt(bitPattern: region.writable))))
                    }
                }

                Section("Verification") {
                    Button {
                        runDiagnostics()
                    } label: {
                        HStack {
                            Text("Re-test JIT Execution")
                            if testing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(testing)

                    if let testResult {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(testResult.contains("successful") ? .green : .red)
                    }
                }

                if let problem = jit.problem {
                    Section("Diagnostics") {
                        Text(problem)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("JIT Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statusSubtitle: String {
        switch jit.state {
        case .checking:
            return "Verifying memory execution…"
        case .on(let mb):
            return "\(mb) MB verified executable memory allocated"
        case .off:
            return "Waiting for jailbreak environment"
        case .failed(let err):
            return err
        }
    }

    private func runDiagnostics() {
        testing = true
        testResult = nil
        Task {
            if let region = jit.region {
                var testRegion = region
                let ok = crate_code_region_test(&testRegion)
                await MainActor.run {
                    testing = false
                    testResult = ok ? "Execution test successful: mov w0, #42; ret returned 42." : "Execution test failed."
                }
            } else {
                await jit.check()
                await MainActor.run {
                    testing = false
                    testResult = jit.isOn ? "JIT activated and verified successfully." : "JIT activation failed."
                }
            }
        }
    }
}
