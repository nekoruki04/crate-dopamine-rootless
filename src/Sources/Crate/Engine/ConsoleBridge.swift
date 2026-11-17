// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CrateEngine
import Foundation

/// The VM's serial console, between crate's threads and the screen.
///
/// Output comes from the guest's CPU threads, a byte or a few at a time, and
/// must not wait on the screen: it's queued, and handed to the view on the main
/// thread in batches. Everything this boot printed is kept, up to a limit, so a
/// view that opens later starts with the boot so far. Input goes the other way:
/// the UART takes only a few bytes at a time, so what it refuses waits until
/// crate says it has room again.
///
/// The output also goes to Library/Caches/console.log, a boot's worth, so a
/// boot can be read from a Mac (devicectl copies files; it can't show a screen).
final class ConsoleBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var machine: OpaquePointer?
    /// The serial console is the machine's first and only console.
    private let index: UInt32 = 0

    private var shown: [UInt8] = []
    private var unsent: [UInt8] = []
    private var flushScheduled = false
    private var typed: [UInt8] = []
    private var sink: (@MainActor ([UInt8]) -> Void)?
    #if DEBUG
    private var pretending = false
    #endif

    /// A boot's worth and more: what a view opened later replays.
    private static let keep = 1 << 20

    static let logURL = URL.cachesDirectory.appendingPathComponent("console.log")
    private let logQueue = DispatchQueue(label: "com.amendez.crate.console-log", qos: .utility)
    private var logPending: [UInt8] = []
    private var logScheduled = false
    private var logged = 0

    /// For crate_config_add_console; `self` outlives the machine.
    var callbacks: crate_console_callbacks {
        crate_console_callbacks(
            size: MemoryLayout<crate_console_callbacks>.size,
            context: Unmanaged.passUnretained(self).toOpaque(),
            output: { context, _, bytes, length in
                guard let context, let bytes else { return }
                Unmanaged<ConsoleBridge>.fromOpaque(context).takeUnretainedValue()
                    .output(UnsafeBufferPointer(start: bytes, count: length))
            },
            input_ready: { context, _ in
                guard let context else { return }
                Unmanaged<ConsoleBridge>.fromOpaque(context).takeUnretainedValue().inputReady()
            })
    }

    /// A new boot: forget the last one's output and anything unsent.
    func reset() {
        lock.withLock {
            shown.removeAll()
            unsent.removeAll()
            typed.removeAll()
            logPending.removeAll()
            logged = 0
        }
        // Logging off (Settings > Logs) keeps no file of the console.
        guard AppLog.isOn else { return }
        logQueue.async { try? Data().write(to: Self.logURL) }
    }

    func attach(machine: OpaquePointer) {
        lock.withLock { self.machine = machine }
    }

    /// The machine stopped: typing goes nowhere now.
    func detach() {
        lock.withLock {
            machine = nil
            typed.removeAll()
        }
    }

    // MARK: - The screen's side, on the main thread

    /// Starts sending output to `sink`, beginning with everything so far.
    @MainActor
    func connect(_ sink: @escaping @MainActor ([UInt8]) -> Void) {
        let replay = lock.withLock { () -> [UInt8] in
            self.sink = sink
            unsent.removeAll()
            return shown
        }
        if !replay.isEmpty { sink(replay) }
    }

    @MainActor
    func disconnect() {
        lock.withLock { sink = nil }
    }

    /// What the person typed, for the guest.
    func send(_ bytes: ArraySlice<UInt8>) {
        #if DEBUG
        if lock.withLock({ pretending }) {
            // Return as a new line, delete as rubbing out, the rest as itself.
            let echo = bytes.flatMap { $0 == 13 ? [13, 10] : $0 == 127 ? [8, 32, 8] : [$0] }
            echo.withUnsafeBufferPointer { output($0) }
            return
        }
        #endif
        lock.withLock {
            typed.append(contentsOf: bytes)
            writeTyped()
        }
    }

    #if DEBUG
    /// Debug builds pretending JIT is on: `text` as if the guest printed it,
    /// and typing echoed from then on, so the terminal can be tried without a
    /// VM.
    func pretend(_ text: String) {
        lock.withLock { pretending = true }
        Array(text.utf8).withUnsafeBufferPointer { output($0) }
    }
    #endif

    // MARK: - crate's side, on the guest's threads

    private func output(_ bytes: UnsafeBufferPointer<UInt8>) {
        lock.withLock {
            shown.append(contentsOf: bytes)
            if shown.count > Self.keep { shown.removeFirst(shown.count - Self.keep) }
            if logged < Self.keep, AppLog.isOn {
                logPending.append(contentsOf: bytes)
                logged += bytes.count
                if !logScheduled {
                    logScheduled = true
                    logQueue.asyncAfter(deadline: .now() + 0.25) { self.writeLog() }
                }
            }
            guard sink != nil else { return }
            unsent.append(contentsOf: bytes)
            if !flushScheduled {
                flushScheduled = true
                DispatchQueue.main.async { self.flush() }
            }
        }
    }

    private func inputReady() {
        lock.withLock { writeTyped() }
    }

    /// Offers what's typed and unsent; crate takes what fits. Under `lock`.
    private func writeTyped() {
        guard let machine, !typed.isEmpty else { return }
        let taken = typed.withUnsafeBufferPointer { crate_console_write(machine, index, $0.baseAddress, $0.count) }
        typed.removeFirst(taken)
    }

    private func writeLog() {
        let bytes = lock.withLock { () -> [UInt8] in
            defer {
                logPending.removeAll(keepingCapacity: true)
                logScheduled = false
            }
            return logPending
        }
        guard !bytes.isEmpty, let handle = try? FileHandle(forWritingTo: Self.logURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(bytes))
    }

    @MainActor
    private func flush() {
        let (bytes, sink) = lock.withLock { () -> ([UInt8], (@MainActor ([UInt8]) -> Void)?) in
            defer {
                unsent.removeAll(keepingCapacity: true)
                flushScheduled = false
            }
            return (unsent, self.sink)
        }
        if !bytes.isEmpty { sink?(bytes) }
    }
}
