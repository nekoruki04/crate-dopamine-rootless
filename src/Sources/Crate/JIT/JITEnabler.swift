// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UIKit

/// Detection and compatibility helpers for Dopamine 2.x, 3.x, and RootHide environments.
public enum DopamineFlavor: String, CustomStringConvertible, Sendable {
    case dopamine2 = "Dopamine 2"
    case dopamine3 = "Dopamine 3"
    case dopamineRootHide = "Dopamine RootHide"
    case genericRootless = "Rootless Environment"
    case nonJailbroken = "Standard / Non-Jailbroken"

    public var description: String { rawValue }
}

public struct DopamineEnvironment: Sendable {
    /// Detects the active jailbreak flavor based on filesystem markers and BaseBin components.
    public static var currentFlavor: DopamineFlavor {
        let fm = FileManager.default

        // RootHide stealth basebin marker
        if fm.fileExists(atPath: "/var/jb/basebin/libroothider.dylib") {
            return .dopamineRootHide
        }

        // Dopamine 3 introduces dedicated hookd daemon in BaseBin
        if fm.fileExists(atPath: "/var/jb/basebin/hookd") {
            return .dopamine3
        }

        // Dopamine 2 uses BaseBin with jbctl but without hookd
        if fm.fileExists(atPath: "/var/jb/basebin/jbctl") {
            return .dopamine2
        }

        // Generic rootless symlink
        if fm.fileExists(atPath: "/var/jb") {
            return .genericRootless
        }

        return .nonJailbroken
    }

    /// Whether the device is operating in a rootless jailbreak filesystem (/var/jb).
    public static var isRootless: Bool {
        FileManager.default.fileExists(atPath: "/var/jb")
    }

    /// Path to the jbctl utility if available in the current environment.
    public static var jbctlPath: String? {
        let candidates = [
            "/var/jb/basebin/jbctl",
            "/var/jb/usr/bin/jbctl"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

/// Turning JIT on: activating Dopamine JIT natively in-process.
extension JITSession {
    /// Activates in-process JIT, claims the code region, and executes the validation test.
    func turnOn(_ method: JITMethod = .dopamineNative, interactive: Bool = true) async {
        guard !isTurningOn, !isOn else { return }
        enablerError = nil
        isTurningOn = true
        defer { isTurningOn = false }
        AppLog.write("jit: activating native in-process JIT for \(DopamineEnvironment.currentFlavor)")

        let activated = crate_jailbreak_activate_jit()
        AppLog.write("jit: activation cycle complete, status=\(activated)")
        await check()
    }

    /// crate is back in front: if JIT is off, attempt re-verification.
    func cameToFront() {
        cameToFrontCount += 1
        guard !isOn, !isTurningOn else { return }
        Task { await check() }
    }
}
