// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import CryptoKit
import Foundation

/// Unpacks an xz-compressed disk image, fed a part at a time, into a sparse
/// file: blocks that are all zeros become holes, so an image's empty space
/// takes no room. Every byte goes through SHA-256, holes included.
///
/// Memory stays flat however big the disk: each part is read through one
/// buffer and the output gathered in another, both reused, since a Data that
/// grows and drops from its front holds on to everything it ever held.
final class DiskUnpacker {
    private let fd: Int32
    private var filter: OutputFilter!
    private var hasher = SHA256()
    private var offset: Int64 = 0
    private let block = 1 << 20
    private let buffer: UnsafeMutableRawPointer
    private let zeros: UnsafeMutableRawPointer
    private var filled = 0
    private let progress: (Int64) -> Void

    /// `progress` hears the bytes unpacked so far.
    init(to url: URL, progress: @escaping (Int64) -> Void) throws {
        fd = open(url.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        buffer = .allocate(byteCount: block, alignment: 16)
        zeros = .allocate(byteCount: block, alignment: 16)
        zeros.initializeMemory(as: UInt8.self, repeating: 0, count: block)
        self.progress = progress
        filter = try OutputFilter(.decompress, using: .lzma) { [unowned self] data in
            if let data { try self.take(data) }
        }
    }

    deinit {
        close(fd)
        buffer.deallocate()
        zeros.deallocate()
    }

    /// Unpacks the next part of the compressed stream, from a file.
    func unpack(part url: URL) throws {
        let input = open(url.path, O_RDONLY)
        guard input >= 0 else { throw CocoaError(.fileReadUnknown) }
        defer { close(input) }
        let size = 4 << 20
        let chunk = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        defer { chunk.deallocate() }
        while true {
            try Task.checkCancellation()
            let count = read(input, chunk, size)
            guard count >= 0 else { throw CocoaError(.fileReadUnknown) }
            if count == 0 { return }
            try filter.write(UnsafeRawBufferPointer(start: chunk, count: count))
        }
    }

    /// Ends the stream: the bytes unpacked and their SHA-256.
    func finish() throws -> (bytes: Int64, sha256: String) {
        try filter.finalize()
        try flush()
        guard ftruncate(fd, offset) == 0 else { throw CocoaError(.fileWriteUnknown) }
        return (offset, hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }

    /// Makes the file `size` long, the new space a hole.
    func extend(to size: Int64) throws {
        guard ftruncate(fd, max(size, offset)) == 0, fsync(fd) == 0 else {
            throw CocoaError(.fileWriteOutOfSpace)
        }
    }

    private func take(_ data: Data) throws {
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard var source = raw.baseAddress else { return }
            hasher.update(bufferPointer: raw)
            var left = raw.count
            while left > 0 {
                let count = min(left, block - filled)
                (buffer + filled).copyMemory(from: source, byteCount: count)
                filled += count
                source += count
                left -= count
                if filled == block { try flush() }
            }
        }
        progress(offset)
    }

    private func flush() throws {
        guard filled > 0 else { return }
        if filled < block || memcmp(buffer, zeros, block) != 0 {
            guard pwrite(fd, buffer, filled, off_t(offset)) == filled else {
                throw CocoaError(.fileWriteOutOfSpace)
            }
        }
        offset += Int64(filled)
        filled = 0
    }
}
