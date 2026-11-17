// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UIKit

/// crate's memory in the log while a VM runs (Settings > Logs > Track Memory
/// Use). When iOS closes crate for using too much, it gives no warning crate
/// could log: these lines, the last ones before the log stops, are what show it.
///
/// Each reading is two calls into iOS about crate itself, never the guest, on a
/// timer of its own, so the VM doesn't notice it.
@MainActor
final class MemoryLog {
    /// Seconds between lines: about 60 bytes each, so some 40 KB an hour.
    static let interval = 5

    private var timer: DispatchSourceTimer?

    /// Whether Settings > Logs leaves memory tracking on.
    nonisolated static var isTracking: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.logsTrackMemory) as? Bool ?? true
    }

    /// A line now, then one every `interval` while the setting is on; turning
    /// it off or on takes effect at the next one.
    func start() {
        stop()
        Self.writeLine()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + .seconds(Self.interval), repeating: .seconds(Self.interval),
                       leeway: .seconds(1))
        timer.setEventHandler { Self.writeLine() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    nonisolated private static func writeLine() {
        guard isTracking else { return }
        AppLog.write("memory: " + reading())
    }

    /// "footprint 2310 MiB, available 1290 MiB": what iOS charges crate, and
    /// how much more it lets crate have before closing it.
    nonisolated static func reading() -> String {
        let memory = MemoryReport()
        return "footprint \(memory.footprint >> 20) MiB, "
            + "available \(memory.available.map { "\($0 >> 20) MiB" } ?? "n/a")"
    }

    /// iOS's low-memory warnings, logged whether or not memory is tracked:
    /// they're rare, and say the most.
    static func watchWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { _ in
            AppLog.write("memory: iOS warned crate memory is low; " + reading())
        }
    }
}
