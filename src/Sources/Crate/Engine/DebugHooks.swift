// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if DEBUG
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Debug builds only: a running VM driven from a Mac, which can read and write
/// the app's container (devicectl) but can't see the screen or type. Every
/// second it looks in `Library/Caches/debug/`:
///
/// - `screen`: the display's current frame goes to `screen.png`.
/// - `command.txt`: its text is typed into the serial console.
/// - `size.txt`: "WIDTHxHEIGHT" in points, fitted as if the view were that
///   size, as rotating or folding the iPhone would.
///
/// Each request file is removed once it's done.
@MainActor
final class DebugHooks {
    nonisolated static let folder = URL.cachesDirectory.appendingPathComponent("debug")
    private var timer: Timer?

    func start(console: ConsoleBridge, display: DisplayBridge) {
        stop()
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Self.poll(console: console, display: display)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private nonisolated static func poll(console: ConsoleBridge, display: DisplayBridge) {
        let files = FileManager.default
        let screen = folder.appendingPathComponent("screen")
        if files.fileExists(atPath: screen.path) {
            try? files.removeItem(at: screen)
            if let image = display.snapshot() {
                let url = folder.appendingPathComponent("screen.png") as CFURL
                if let out = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(out, image, nil)
                    CGImageDestinationFinalize(out)
                }
            }
        }
        let command = folder.appendingPathComponent("command.txt")
        if let text = try? Data(contentsOf: command) {
            try? files.removeItem(at: command)
            console.send(ArraySlice(text))
        }
        let size = folder.appendingPathComponent("size.txt")
        if let text = try? String(contentsOf: size, encoding: .utf8) {
            try? files.removeItem(at: size)
            let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }
            if numbers.count == 2 {
                let size = CGSize(width: numbers[0], height: numbers[1])
                Task { @MainActor in display.fit(size, window: size) }
            }
        }
    }
}
#endif
