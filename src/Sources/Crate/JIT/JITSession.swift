// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation

/// Whether this launch of crate has JIT, and the code region it claimed.
///
/// On Dopamine RootHide, JIT is activated natively directly inside the process
/// without any external companion app, computer pairing, or network tunnels.
/// Once claimed, the executable code region remains active for the entire process lifetime.
@MainActor @Observable
final class JITSession {
    enum State: Equatable {
        case checking
        case off(OffReason)
        case on(regionMB: Int)
        case failed(String)
    }

    enum OffReason: Equatable {
        case noDebugger
        case debuggerLeft
        case notEligible
    }

    private(set) var state = State.checking

    /// The region itself, for the engine, once claimed.
    private(set) var region: crate_code_region?

    var isOn: Bool {
        if case .on = state { return true }
        return pretending
    }

    /// Why JIT isn't on, when there's more to say than "nothing attached".
    var problem: String? {
        if let enablerError { return enablerError }
        switch state {
        case .off(.debuggerLeft):
            return "JIT environment was detached unexpectedly."
        case .off(.notEligible):
            return "This copy of crate cannot use JIT: missing task entitlements or jailbreak environment."
        case .failed(let message):
            return message
        case .checking, .on, .off(.noDebugger):
            return nil
        }
    }

    /// What the last attempt to turn JIT on said went wrong, if it did.
    var enablerError: String?
    var isTurningOn = false
    var helperFailure: String?
    var waitingForVPN = false
    var cameToFrontCount = 0
    var showingSetup = false
    private(set) var isPaired = true

    func pairingChanged() {
        isPaired = true
    }

    /// Checks at launch: claims the region in the background.
    func start() {
        Task { await check() }
    }

    /// Activates RootHide JIT and claims the executable region.
    func check() async {
        if case .on = state { return }
        state = .checking
        let sizeMB = UserDefaults.standard.object(forKey: SettingsKey.codeRegionMB) as? Int ?? CodeRegion.standard
        let (state, region) = await Task.detached(priority: .userInitiated) {
            Self.claim(sizeMB: sizeMB)
        }.value
        self.state = state
        self.region = region
    }

    nonisolated static var debuggerReady: Bool {
        var flags: UInt32 = 0
        guard crate_jit_cs_flags(&flags) else { return false }
        return (flags & csDebugged != 0)
    }

    nonisolated private static let csDebugged: UInt32 = 0x1000_0000
    nonisolated private static let csGetTaskAllow: UInt32 = 0x0000_0004
    nonisolated private static let claimingKey = "jit.claimingInProgress"

    nonisolated private static func claim(sizeMB: Int) -> (State, crate_code_region?) {
        _ = crate_jailbreak_activate_jit()

        var flags: UInt32 = 0
        let gotFlags = crate_jit_cs_flags(&flags)
        let isDebugged = (flags & csDebugged != 0)
        let traced = crate_jit_traced()
        AppLog.write("jit: rootless status gotFlags=\(gotFlags) flags=0x\(String(flags, radix: 16)) debugged=\(isDebugged) traced=\(traced)")

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: claimingKey) {
            defaults.set(false, forKey: claimingKey)
            AppLog.write("jit: previous launch died claiming code region; resetting flag")
        }
        defaults.set(true, forKey: claimingKey)
        defaults.synchronize()
        defer {
            defaults.set(false, forKey: claimingKey)
        }

        let started = Date.now
        var region = crate_code_region()
        let minimumMB = min(sizeMB, CodeRegion.minimumFallback)
        if crate_code_region_map(sizeMB << 20, minimumMB << 20, false, &region) != CRATE_REGION_OK {
            let errorText = String(cString: strerror(errno))
            AppLog.write("jit: mmap failed for \(sizeMB) MB: \(errorText)")
            return failure("iOS refused to map \(sizeMB) MB for code: \(errorText)")
        }

        let claimedMB = region.size >> 20
        AppLog.write("jit: claiming \(claimedMB) MB at \(String(UInt(bitPattern: region.executable), radix: 16))")
        let status = crate_code_region_finish(&region, false)
        let errorText = String(cString: strerror(errno))
        switch status {
        case CRATE_REGION_OK:
            break
        case CRATE_REGION_REFUSED:
            return failure("The memory system refused to authorize the code region.")
        case CRATE_REGION_REMAP_FAILED:
            return failure("iOS refused to remap the code region for writing: \(errorText)")
        default:
            return failure("iOS refused to make the code region writable: \(errorText)")
        }

        let seconds = Date.now.timeIntervalSince(started)
        guard crate_code_region_test(&region) else {
            return failure("Test execution in JIT region failed. Verify that Dopamine RootHide JIT is permitted.")
        }

        AppLog.write("jit: native active, \(claimedMB) MB claimed and tested in \(String(format: "%.2f", seconds))s")
        return (.on(regionMB: claimedMB), region)
    }

    nonisolated private static func failure(_ message: String) -> (State, crate_code_region?) {
        AppLog.write("jit: failed: \(message)")
        return (.failed(message), nil)
    }

    // MARK: - UI preview

    var pretending: Bool = JITSession.storedPretending {
        didSet { UserDefaults.standard.set(pretending, forKey: SettingsKey.previewJIT) }
    }

    private static var storedPretending: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: SettingsKey.previewJIT)
        #else
        false
        #endif
    }
}
