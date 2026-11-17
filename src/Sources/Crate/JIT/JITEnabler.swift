// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import UIKit

/// Turning JIT on: activating Dopamine RootHide JIT natively in-process.
extension JITSession {
    /// Activates RootHide JIT, claims the code region, and executes the validation test.
    func turnOn(_ method: JITMethod = .nativeRootHide, interactive: Bool = true) async {
        guard !isTurningOn, !isOn else { return }
        enablerError = nil
        isTurningOn = true
        defer { isTurningOn = false }
        AppLog.write("jit: activating native Dopamine RootHide JIT")

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
