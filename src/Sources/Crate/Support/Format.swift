// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum Format {
    /// "5.8 GB", "107 GB", "384 MB". Decimal units, as the Settings app uses,
    /// with one decimal only where it says something.
    static func bytes(_ count: Int64) -> String {
        let gb = Double(count) / 1e9
        if gb >= 10 { return "\(Int(gb.rounded())) GB" }
        if gb >= 1 { return "\(gb.formatted(.number.precision(.fractionLength(1)))) GB" }
        return "\(Int((Double(count) / 1e6).rounded())) MB"
    }

    /// Memory in the binary units it's sold in: an "8 GB" iPhone has 8 GiB, and
    /// a VM given "4 GB" gets 4 GiB. Up to one decimal place, or exactly
    /// `decimals` for a figure that moves, so it doesn't look round when it isn't.
    static func memory(_ count: UInt64, decimals: Int? = nil) -> String {
        let gib = Double(count) / 1_073_741_824
        let places = decimals.map { $0...$0 } ?? 0...1
        if gib >= 1 { return "\(gib.formatted(.number.precision(.fractionLength(places)))) GB" }
        return "\(Int((Double(count) / 1_048_576).rounded())) MB"
    }

    /// "1 hour ago". Nil reads as "Never".
    static func relative(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(.relative(presentation: .named))
    }

    /// Free space on the volume that holds the app's data.
    static func freeDiskBytes() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// The size of the volume that holds the app's data, free or not.
    static func totalDiskBytes() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey])
        return values?.volumeTotalCapacity.map(Int64.init)
    }
}
