// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// How Crate gets JIT turned on for itself.
enum JITMethod: String, CaseIterable, Identifiable {
    case dopamineNative = "dopamineNative"

    var id: Self { self }

    var title: String {
        switch self {
        case .dopamineNative:
            "Dopamine Native JIT (\(DopamineEnvironment.currentFlavor))"
        }
    }

    static let standard = Self.dopamineNative
}

/// The settings Crate keeps in UserDefaults, by key, so every `@AppStorage`
/// that reads one spells it the same way.
enum SettingsKey {
    static let jitMethod = "jit.method"
    static let jitAtLaunch = "jit.turnOnAtLaunch"
    static let codeRegionMB = "jit.codeRegionMB"
    static let installMemoryGB = "install.memoryGB"
    static let installDiskGB = "install.diskGB"
    /// Settings > Logs: whether crate logs at all, and whether it logs its
    /// memory while a VM runs. Both on unless turned off.
    static let logsEnabled = "logs.enabled"
    static let logsTrackMemory = "logs.trackMemory"

    /// Debug builds: pretend JIT is on (see `JITSession.previewOn`).
    static let previewJIT = "preview.jitOn"
}

/// Sizes offered for the JIT code region, in MB. It is claimed once per launch,
/// so a change applies the next time crate opens. The default is the largest:
/// more room for translated code means less retranslating.
enum CodeRegion {
    static let choices = [128, 256, 384, 512, 768, 1024]
    static let standard = 1024
    /// When the size chosen doesn't fit where the debugger can authorize it,
    /// crate takes the largest gap that does, down to this.
    static let minimumFallback = 256
}
