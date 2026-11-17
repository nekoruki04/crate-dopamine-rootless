// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import UIKit

/// What crate did: JIT, pairing, and the engine's own lines, kept in
/// `Library/Caches/crate.log` (a phone's unified log can't be read from a Mac, a
/// file can) and shared by Settings > Export Logs.
///
/// Each launch starts a new log and keeps the one before as
/// `crate-previous.log`: when iOS closes crate, opening it again to export is a
/// new launch, and the log of the one that was closed is the one that matters.
/// Settings > Logs can turn logging off, which deletes both.
enum AppLog {
    static let url = URL.cachesDirectory.appendingPathComponent("crate.log")
    static let previousURL = URL.cachesDirectory.appendingPathComponent("crate-previous.log")
    /// The files. Held across file reads and writes.
    private static let lock = NSLock()
    private static let started = Date.now
    /// Whether logging is on: its own lock, never held across file work, so
    /// the VM's console output can ask (isOn) without waiting on the files.
    private static let enabledLock = NSLock()
    private static var enabledFlag = true
    /// Lines written while iOS has crate prewarmed, before the log starts (see
    /// begin). Read and written under `lock`.
    private static var held: [String]?

    private static var enabled: Bool {
        get { enabledLock.withLock { enabledFlag } }
        set { enabledLock.withLock { enabledFlag = newValue } }
    }

    /// Whether Settings > Logs leaves logging on.
    static var isEnabledInSettings: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.logsEnabled) as? Bool ?? true
    }

    /// Starts this launch's log, keeping the last launch's beside it, or with
    /// logging turned off, deletes both.
    ///
    /// iOS may prewarm crate: start it in the background before it's opened,
    /// and maybe throw it away unused. Starting the log then would push out the
    /// log being kept, which after a crash is the one that matters, for a
    /// launch nobody saw. So while prewarmed, lines are held, and the log
    /// starts when crate first becomes active.
    static func begin() {
        let on = isEnabledInSettings
        enabled = on
        if on, ProcessInfo.processInfo.environment["ActivePrewarm"] == "1" {
            lock.withLock { held = [] }
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                if let observer { NotificationCenter.default.removeObserver(observer) }
                observer = nil
                startLog()
            }
        } else {
            startLog()
        }
        // The date, to match the log with iOS's own reports of the launch.
        write("crate \(appVersion) launched \(Date.now.formatted(.iso8601)), "
              + "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
    }

    /// The last launch's log aside and a new one started, with any lines held
    /// meanwhile; or with logging off, every log deleted.
    private static func startLog() {
        let on = enabled
        lock.withLock {
            let files = FileManager.default
            let lines = held ?? []
            held = nil
            try? files.removeItem(at: previousURL)
            if on {
                try? files.moveItem(at: url, to: previousURL)
                try? Data(lines.joined().utf8).write(to: url)
            } else {
                try? files.removeItem(at: url)
                removeOtherLogs()
            }
        }
    }

    /// Settings turned logging on or off. Off stops it and deletes both logs.
    static func setEnabled(_ on: Bool) {
        enabled = on
        lock.withLock {
            if on {
                try? Data().write(to: url)
            } else {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: previousURL)
                removeOtherLogs()
            }
        }
        if on { write("logs: turned on \(Date.now.formatted(.iso8601))") }
    }

    /// Whether crate is logging: Settings > Logs, as it was at launch or
    /// since. The VM's console and idevice keep their own logs only while it is.
    static var isOn: Bool { enabled }

    /// The rest of what crate keeps of what happened: the copies Export Logs
    /// made to share (LogExport), the VM's console output (ConsoleBridge) and
    /// idevice's pairing messages (OnDevicePairing).
    private static func removeOtherLogs() {
        let files = FileManager.default
        let temporary = files.temporaryDirectory
        let exported = (try? files.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)) ?? []
        for file in exported where file.lastPathComponent.hasPrefix("crate-") && file.pathExtension == "log" {
            try? files.removeItem(at: file)
        }
        try? files.removeItem(at: ConsoleBridge.logURL)
    }

    static func write(_ line: String) {
        let stamped = String(format: "[%7.3f] ", Date.now.timeIntervalSince(started)) + line + "\n"
        guard enabled else { return }
        lock.withLock {
            if held != nil {
                held?.append(stamped)
                return
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(stamped.utf8))
        }
    }

    /// This launch's log.
    static func contents() -> String {
        lock.withLock { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    }

    /// The last launch's log, if there was one.
    static func previousContents() -> String? {
        lock.withLock { try? String(contentsOf: previousURL, encoding: .utf8) }
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
