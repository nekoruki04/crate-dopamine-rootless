// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Photos
import SwiftUI
import UIKit

/// A picture of a VM's screen as crate holds it: the guest's own pixels at its
/// own size, without the letterboxing around it or the toolbar.
struct Screenshot: Identifiable {
    let id = UUID()
    let image: UIImage
    /// The same as a PNG, for the share sheet.
    let file: URL
    /// Whether it went into Photos.
    var saved = false

    /// Encodes `image` as a PNG named for the VM and the time, as iOS names
    /// its own screenshots, off the main thread.
    static func make(_ image: CGImage, of machine: String) async -> Screenshot? {
        await Task.detached(priority: .userInitiated) {
            let picture = UIImage(cgImage: image)
            guard let png = picture.pngData() else { return nil }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Screenshots")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("\(machine) Screenshot \(stamp.string(from: .now)).png")
            guard (try? png.write(to: file)) != nil else { return nil }
            return Screenshot(image: picture, file: file)
        }.value
    }

    /// Adds it to Photos, which asks the first time. Add-only: crate never
    /// sees what else is there.
    func saveToPhotos() async -> Bool {
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: file, options: nil)
            }
            return true
        } catch {
            AppLog.write("screenshot: Photos refused it: \(error)")
            return false
        }
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()
}

/// A VM's card picture: its screen as it was when last stopped, small, in the
/// VM's own folder, so it goes when the VM does. Separate from screenshots,
/// which go to Photos.
enum MachinePreview {
    /// At most this wide: about what a card is on the widest screen.
    private static let width: CGFloat = 1280

    /// Writes `image` to `url` as a JPEG, off the main thread.
    static func save(_ image: CGImage, to url: URL) async -> Bool {
        await Task.detached(priority: .utility) {
            let scale = min(1, width / CGFloat(image.width))
            let size = CGSize(width: (CGFloat(image.width) * scale).rounded(),
                              height: (CGFloat(image.height) * scale).rounded())
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let jpeg = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { _ in
                UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
            }
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try jpeg.write(to: url, options: .atomic)
                return true
            } catch {
                AppLog.write("preview: not saved: \(error)")
                return false
            }
        }.value
    }

    /// The saved preview, decoded off the main thread; nil if there's none.
    static func load(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)?.preparingForDisplay()
        }.value
    }
}

/// The system share sheet, for a screenshot's file.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
