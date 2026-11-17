// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The file Settings > Logs shares.
enum LogExport {
    /// Writes a few lines about the device, this launch's log, then the last
    /// launch's, and returns where the file is. The last launch's is there for
    /// when iOS closed crate: reopening it to export is a new launch.
    static func prepare() -> URL {
        let stamp = Date.now.formatted(
            Date.ISO8601FormatStyle(timeZone: .current).year().month().day().dateSeparator(.dash))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("crate-\(stamp).log")
        let memory = MemoryReport()
        var lines = [
            "crate \(AppLog.appVersion)",
            "date: \(Date.now.formatted(.iso8601))",
            "device: \(deviceModel), iOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "memory: physical \(Format.memory(memory.physical)), "
                + "available \(memory.available.map { Format.memory($0) } ?? "n/a"), "
                + "footprint \(Format.memory(memory.footprint))",
            "jit method: \(UserDefaults.standard.string(forKey: SettingsKey.jitMethod) ?? JITMethod.standard.rawValue)",
            "",
            "== This launch ==",
            AppLog.contents(),
        ]
        if let previous = AppLog.previousContents(), !previous.isEmpty {
            lines += ["== The launch before ==", previous]
        }
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
