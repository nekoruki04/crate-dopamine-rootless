// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CryptoKit
import Foundation

/// The owner's settings for a VM's first boot, as cloud-init's NoCloud
/// datasource reads them: a small FAT disk labelled CIDATA holding user-data
/// (the account, hostname and time zone), meta-data (the instance's identity)
/// and vendor-data (what the image needs for that account, from the catalog).
/// It stays attached, read-only, so cloud-init sees the same instance at
/// every boot and never sets the VM up again.
struct SeedDisk {
    let user: String
    let password: String
    let hostname: String
    let timeZone: String
    let vendorData: String?

    /// A user name Linux accepts: lowercase letters, digits, "_" and "-",
    /// starting with a letter or "_", at most 32 characters.
    static func isValid(user: String) -> Bool {
        user.wholeMatch(of: #/[a-z_][a-z0-9_-]{0,31}/#) != nil
            && !["root", "daemon", "bin", "sys", "nobody"].contains(user)
    }

    /// A hostname: lowercase letters, digits and "-", not starting or ending with "-".
    static func isValid(hostname: String) -> Bool {
        hostname.wholeMatch(of: #/[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?/#) != nil
    }

    var userData: String {
        """
        #cloud-config
        hostname: \(hostname)
        users:
          - name: \(user)
            gecos: \(user)
            shell: /bin/bash
            sudo: ALL=(ALL) ALL
            lock_passwd: false
            passwd: "\(SHA512Crypt.hash(password))"
        ssh_pwauth: true
        timezone: \(timeZone)

        """
    }

    func metaData(instance: UUID) -> String {
        "instance-id: \(instance.uuidString.lowercased())\nlocal-hostname: \(hostname)\n"
    }

    /// Writes the disk to `url`.
    func write(to url: URL, instance: UUID) throws {
        var files = [("user-data", Data(userData.utf8)),
                     ("meta-data", Data(metaData(instance: instance).utf8))]
        if let vendorData {
            files.append(("vendor-data", Data(vendorData.replacingOccurrences(of: "{{user}}", with: user).utf8)))
        }
        try FATImage.make(label: "CIDATA", files: files).write(to: url)
    }
}

/// A 1 MiB FAT12 image holding a few small files in its root directory, with
/// long file names, which is all a NoCloud seed needs.
enum FATImage {
    private static let sectorSize = 512
    private static let sectors = 2048
    private static let fatSectors = 6
    private static let rootEntries = 224
    private static var rootSectors: Int { rootEntries * 32 / sectorSize }
    /// The first data sector, cluster 2: boot sector, two FATs, the root directory.
    private static var dataStart: Int { 1 + 2 * fatSectors + rootSectors }

    static func make(label: String, files: [(name: String, contents: Data)]) -> Data {
        var image = Data(count: sectors * sectorSize)
        let paddedLabel = Array(label.uppercased().utf8.prefix(11)) + Array(repeating: 0x20, count: max(0, 11 - label.utf8.count))

        // Boot sector and BIOS parameter block.
        image.replaceSubrange(0..<3, with: [0xEB, 0x3C, 0x90])
        image.replaceSubrange(3..<11, with: Array("MSWIN4.1".utf8))
        put16(&image, 11, UInt16(sectorSize))
        image[13] = 1                       // sectors per cluster
        put16(&image, 14, 1)                // reserved sectors
        image[16] = 2                       // FATs
        put16(&image, 17, UInt16(rootEntries))
        put16(&image, 19, UInt16(sectors))
        image[21] = 0xF8                    // media
        put16(&image, 22, UInt16(fatSectors))
        put16(&image, 24, 32)               // sectors per track
        put16(&image, 26, 2)                // heads
        image[36] = 0x80                    // drive
        image[38] = 0x29                    // extended boot signature
        put32(&image, 39, UInt32.random(in: 1...UInt32.max))
        image.replaceSubrange(43..<54, with: paddedLabel)
        image.replaceSubrange(54..<62, with: Array("FAT12   ".utf8))
        image[510] = 0x55
        image[511] = 0xAA

        var fat = [UInt8](repeating: 0, count: fatSectors * sectorSize)
        setFAT(&fat, 0, 0xFF8)
        setFAT(&fat, 1, 0xFFF)
        var root = [UInt8](repeating: 0, count: rootSectors * sectorSize)
        var entry = 0
        func addEntry(_ bytes: [UInt8]) {
            root.replaceSubrange(entry * 32..<(entry + 1) * 32, with: bytes)
            entry += 1
        }
        // The volume label, which blkid reads too.
        var labelEntry = [UInt8](repeating: 0, count: 32)
        labelEntry.replaceSubrange(0..<11, with: paddedLabel)
        labelEntry[11] = 0x08
        addEntry(labelEntry)

        var cluster = 2
        for (index, file) in files.enumerated() {
            let short = Array(String(format: "FILE%04d   ", index).utf8)
            for long in longNameEntries(file.name, short: short) { addEntry(long) }
            let clusters = (file.contents.count + sectorSize - 1) / sectorSize
            var dirent = [UInt8](repeating: 0, count: 32)
            dirent.replaceSubrange(0..<11, with: short)
            dirent[11] = 0x20               // archive
            if clusters > 0 {
                dirent[26] = UInt8(cluster & 0xFF)
                dirent[27] = UInt8(cluster >> 8)
            }
            let size = UInt32(file.contents.count)
            for i in 0..<4 { dirent[28 + i] = UInt8((size >> (8 * UInt32(i))) & 0xFF) }
            addEntry(dirent)
            for i in 0..<clusters {
                setFAT(&fat, cluster + i, i == clusters - 1 ? 0xFFF : cluster + i + 1)
            }
            let offset = (dataStart + cluster - 2) * sectorSize
            image.replaceSubrange(offset..<offset + file.contents.count, with: file.contents)
            cluster += clusters
        }

        for copy in 0..<2 {
            let offset = (1 + copy * fatSectors) * sectorSize
            image.replaceSubrange(offset..<offset + fat.count, with: fat)
        }
        let rootOffset = (1 + 2 * fatSectors) * sectorSize
        image.replaceSubrange(rootOffset..<rootOffset + root.count, with: root)
        return image
    }

    /// The VFAT long-name entries for `name`, last part first, as they're stored.
    private static func longNameEntries(_ name: String, short: [UInt8]) -> [[UInt8]] {
        var checksum: UInt8 = 0
        for byte in short { checksum = ((checksum & 1) << 7) &+ (checksum >> 1) &+ byte }
        var units = Array(name.utf16) + [0]
        let count = (units.count + 12) / 13
        units += Array(repeating: 0xFFFF, count: count * 13 - units.count)
        var entries: [[UInt8]] = []
        for part in 0..<count {
            var e = [UInt8](repeating: 0, count: 32)
            e[0] = UInt8(part + 1) | (part == count - 1 ? 0x40 : 0)
            e[11] = 0x0F
            e[13] = checksum
            let chars = Array(units[part * 13..<(part + 1) * 13])
            let slots = [1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30]
            for (char, slot) in zip(chars, slots) {
                e[slot] = UInt8(char & 0xFF)
                e[slot + 1] = UInt8(char >> 8)
            }
            entries.append(e)
        }
        return entries.reversed()
    }

    private static func setFAT(_ fat: inout [UInt8], _ n: Int, _ value: Int) {
        let offset = n * 3 / 2
        if n % 2 == 0 {
            fat[offset] = UInt8(value & 0xFF)
            fat[offset + 1] = (fat[offset + 1] & 0xF0) | UInt8((value >> 8) & 0x0F)
        } else {
            fat[offset] = (fat[offset] & 0x0F) | UInt8((value << 4) & 0xF0)
            fat[offset + 1] = UInt8((value >> 4) & 0xFF)
        }
    }

    private static func put16(_ data: inout Data, _ offset: Int, _ value: UInt16) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8(value >> 8)
    }

    private static func put32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        for i in 0..<4 { data[offset + i] = UInt8((value >> (8 * UInt32(i))) & 0xFF) }
    }
}

/// glibc's SHA-512 crypt ("$6$"), the password hash /etc/shadow and
/// cloud-init's `passwd` take, so the seed never holds the password itself.
enum SHA512Crypt {
    private static let alphabet = Array("./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".utf8)

    static func hash(_ password: String, salt: String? = nil) -> String {
        let salt = salt ?? String((0..<16).map { _ in Character(UnicodeScalar(alphabet.randomElement()!)) })
        let p = Array(password.utf8), s = Array(salt.utf8.prefix(16))
        let digest = { (parts: [[UInt8]]) -> [UInt8] in
            var h = SHA512()
            for part in parts { h.update(data: part) }
            return Array(h.finalize())
        }

        let b = digest([p, s, p])
        var a = SHA512()
        a.update(data: p)
        a.update(data: s)
        var n = p.count
        while n > 64 { a.update(data: b); n -= 64 }
        a.update(data: Array(b[0..<n]))
        n = p.count
        while n > 0 {
            a.update(data: n & 1 == 1 ? b : p)
            n >>= 1
        }
        var result = Array(a.finalize())

        let dp = digest(Array(repeating: p, count: p.count))
        let pSequence = (0..<p.count).map { dp[$0 % 64] }
        let ds = digest(Array(repeating: s, count: 16 + Int(result[0])))
        let sSequence = (0..<s.count).map { ds[$0 % 64] }

        for round in 0..<5000 {
            var c = SHA512()
            c.update(data: round & 1 == 1 ? pSequence : result)
            if round % 3 != 0 { c.update(data: sSequence) }
            if round % 7 != 0 { c.update(data: pSequence) }
            c.update(data: round & 1 == 1 ? result : pSequence)
            result = Array(c.finalize())
        }

        let order: [(Int, Int, Int)] = [
            (0, 21, 42), (22, 43, 1), (44, 2, 23), (3, 24, 45), (25, 46, 4), (47, 5, 26),
            (6, 27, 48), (28, 49, 7), (50, 8, 29), (9, 30, 51), (31, 52, 10), (53, 11, 32),
            (12, 33, 54), (34, 55, 13), (56, 14, 35), (15, 36, 57), (37, 58, 16), (59, 17, 38),
            (18, 39, 60), (40, 61, 19), (62, 20, 41),
        ]
        var encoded = [UInt8]()
        func emit(_ b2: UInt8, _ b1: UInt8, _ b0: UInt8, _ count: Int) {
            var w = (UInt32(b2) << 16) | (UInt32(b1) << 8) | UInt32(b0)
            for _ in 0..<count {
                encoded.append(alphabet[Int(w & 0x3F)])
                w >>= 6
            }
        }
        for (i, j, k) in order { emit(result[i], result[j], result[k], 4) }
        emit(0, 0, result[63], 2)
        return "$6$" + String(decoding: s, as: UTF8.self) + "$" + String(decoding: encoded, as: UTF8.self)
    }
}
