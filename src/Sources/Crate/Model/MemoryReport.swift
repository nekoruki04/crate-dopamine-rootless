// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os

/// What iOS lets Crate have, read fresh each time one is made.
struct MemoryReport {
    /// STUB: whether the build carries the increased-memory-limit entitlement.
    /// iOS has no public call that reads a process's own entitlements, and this
    /// project always asks for it (project.yml), so the answer is fixed for now.
    let hasIncreasedLimit = true

    /// RAM in the device.
    let physical: UInt64

    /// What Crate could allocate right now before jetsam kills it. Nil in the
    /// Simulator, which has no jetsam limit and reports 0.
    let available: UInt64?

    /// The most Crate can ever hold: what it holds now plus what is left.
    var limit: UInt64? {
        available.map { $0 + footprint }
    }

    /// Memory charged to Crate right now.
    let footprint: UInt64

    init() {
        physical = ProcessInfo.processInfo.physicalMemory
        let free = UInt64(os_proc_available_memory())
        available = free == 0 ? nil : free
        footprint = Self.currentFootprint()
    }

    /// The figure jetsam compares against the limit (phys_footprint).
    private static func currentFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
