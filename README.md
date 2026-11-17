# Crate (Dopamine Rootless)

[![Platform: iOS 16.0+](https://img.shields.io/badge/platform-iOS%2016.0%2B-blue.svg)](https://apple.com)
[![Architecture: arm64 / arm64e](https://img.shields.io/badge/arch-arm64%20%7C%20arm64e-success.svg)](https://en.wikipedia.org/wiki/AArch64)
[![Jailbreak: Dopamine Rootless / RootHide](https://img.shields.io/badge/jailbreak-Dopamine%20Rootless%20%7C%20RootHide-orange.svg)](https://github.com/opa334/Dopamine)
[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-green.svg)](LICENSE)
[![Release: v1.0.0](https://img.shields.io/badge/release-v1.0.0-purple.svg)](build/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb)

An autonomous, rootless jailbreak port of **[Crate iOS](https://github.com/oneamendez/crate-ios)** for **[Dopamine](https://github.com/opa334/Dopamine)** and **[Dopamine RootHide](https://github.com/roothide/Dopamine-roothide)** jailbreaks on iOS & iPadOS 16.0 through 16.5.1.

Crate is a high-performance virtual machine manager that runs full Linux distributions directly on Apple Silicon iOS devices. This port transforms Crate into a self-contained, rootless Debian package (`.deb`) with **native, autonomous JIT code execution**—eliminating all tethering, debugger companions, pairing profiles, and computer dependencies.

---

## Key Features

- **Autonomous Direct JIT Activation**:
  Leverages native Dopamine jailbreak task debugging flags (`CS_DEBUGGED`) and memory protection transitions (`mprotect` / `MAP_JIT`). No StikJIT, StikDebug, LocalDevVPN, NetworkExtension pairing profiles, or external computers required.
- **Rootless Subsystem Compliance**:
  Installed strictly to `/var/jb/Applications/Crate.app` with zero modifications to the sealed system volume (SSV). Automatically registers with SpringBoard via `uicache` maintainer hooks.
- **Retargeted for iOS / iPadOS 16**:
  Backported from iOS 18 APIs to iOS 16.0 deployment target across both the main binary and all 7 bundled dynamic frameworks (`slirp`, `glib`, `EGL`, `GLESv2`, `epoxy`, `virglrenderer.1`, `MoltenVK`).
- **Preserved Rust Virtualization Engine**:
  Maintains the full upstream `crate-core` emulation architecture, including dynamic AArch64 translation cache (`crate-jit`), VirtIO MMIO bus (`crate-devices`), VirtIO-GPU 3D acceleration over Metal, and SLIRP userspace networking.
- **Optimized for 4 GB Devices**:
  Calibrated memory allocation boundaries and Jetsam limits specifically for A12X (iPad Pro 11-inch 2018) and A13 (iPhone 11 Pro) hardware.

---

## Device Compatibility

| Device Profile | SoC | Architecture | Tested OS | Jailbreak Environment | JIT Mode | Status |
|---|---|---|---|---|---|---|
| **iPad Pro 11" (1st Gen, 2018)** *(Primary Target)* | Apple A12X Bionic | `arm64e` | iPadOS 16.1.1 | Dopamine RootHide / Rootless | Autonomous In-Process | **Verified** |
| **iPhone 11 Pro** *(Secondary Target)* | Apple A13 Bionic | `arm64e` | iOS 16.1 – 16.5 | Dopamine Rootless | Autonomous In-Process | **Verified** |
| **iPad Pro 11" / 12.9" (2020)** | Apple A12Z Bionic | `arm64e` | iPadOS 16.0 – 16.5.1 | Dopamine RootHide / Rootless | Autonomous In-Process | **Compatible** |
| **iPhone 12 / 13 / 14 Series** | Apple A14 / A15 / A16 | `arm64e` | iOS 16.0 – 16.5.1 | Dopamine Rootless | Autonomous In-Process | **Compatible** |
| **iPad Air / Pro (M1 / M2)** | Apple M1 / M2 | `arm64e` | iPadOS 16.0 – 16.5.1 | Dopamine Rootless | Autonomous In-Process | **Compatible** |
| **iPhone X / 8 / 8 Plus** | Apple A11 Bionic | `arm64` | iOS 15.0 – 16.7.x | palera1n Rootless | Standard `CS_DEBUGGED` | **Compatible** |

---

## Repository Structure

```text
crate-dopamine-rootless/
├── README.md               # Main project overview and documentation
├── LICENSE                 # Mozilla Public License Version 2.0 (MPL-2.0)
├── NOTICE                  # Upstream copyright and third-party notices
├── AUTHORS.md              # Attribution of upstream authors and port maintainers
├── CHANGELOG.md            # Version release notes and changes
├── CONTRIBUTING.md         # Contribution and issue reporting guidelines
├── SECURITY.md             # Security policy and vulnerability disclosure
├── .gitignore              # Git ignore rules for macOS, Xcode, Rust, and Python
├── .gitattributes          # Line ending and binary file handling
├── docs/
│   ├── installation.md     # Detailed installation instructions (Sileo, Zebra, dpkg)
│   ├── compatibility.md    # Hardware profiles, Jetsam memory, and OS support matrix
│   ├── build.md            # Step-by-step instructions to compile from source
│   ├── troubleshooting.md  # Common errors, crash logs, and diagnostic steps
│   └── credits.md          # Comprehensive acknowledgments and upstream repositories
├── packaging/
│   ├── Crate.entitlements  # Jailbreak entitlements for dynamic codesigning
│   └── DEBIAN/
│       ├── control         # Debian package metadata
│       ├── postinst        # Installation hook running uicache -p
│       └── prerm           # Uninstallation hook running uicache -u
├── scripts/
│   ├── build_crate.sh      # Complete automated build and packaging pipeline
│   ├── package_deb.py      # Debian archive packager targeting /var/jb/
│   └── verify_suite.py     # Automated audit and integrity verification script
├── tests/
│   ├── jit_test.c          # Standalone verification for in-process W^X memory
│   └── verify_suite.py     # Static analysis and package validation tests
├── build/
│   ├── crate-dopamine-rootless_1.0.0_iphoneos-arm.deb  # Release package
│   ├── checksums.txt       # SHA-256 and MD5 cryptographic hashes
│   └── verification_report.md # Comprehensive test results
└── src/                    # Ported application source tree
    ├── Crate.xcodeproj     # Xcode project file
    ├── project.yml         # XcodeGen specification
    ├── Frameworks/         # Retargeted dynamic frameworks (minos 16.0)
    ├── Resources/          # Application assets, icon catalogs, and entitlements
    ├── Scripts/            # Upstream asset fetch and build helpers
    └── Sources/            # Swift & C application source code
```

---

## Quick Installation

### Method 1: Sileo or Zebra (Recommended)
1. Download `crate-dopamine-rootless_1.0.0_iphoneos-arm.deb` from the [build directory](build/) or releases.
2. Transfer to your iOS device via AirDrop, Filza, or local web server.
3. Open the file in **Sileo** or **Zebra** and tap **Install**.
4. The package manager installs the payload into `/var/jb/Applications/Crate.app` and updates SpringBoard icons.

### Method 2: Command Line (SSH or Mobile Terminal)
```bash
# Transfer package to device
scp build/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb mobile@<DEVICE_IP>:/var/mobile/

# Install via dpkg on the device
ssh mobile@<DEVICE_IP> "sudo dpkg -i /var/mobile/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"
```

For detailed setup and removal instructions, refer to [docs/installation.md](docs/installation.md).

---

## How Autonomous JIT Works

Standard iOS enforces strict code signing policies: memory pages cannot be simultaneously writable and executable ($W \oplus X$), and mapping executable memory requires explicit debugger approval. Upstream Crate required a tethered companion app (StikJIT) to attach an external debugger over a local VPN tunnel.

Under **Dopamine Rootless**:
1. The jailbreak kernel and BaseBin grant the target application process the `CS_DEBUGGED` code signing status.
2. The package embeds the following entitlements:
   - `dynamic-codesigning` (`<true/>`)
   - `com.apple.private.cs.debugger` (`<true/>`)
   - `get-task-allow` (`<true/>`)
3. The virtualization translation engine allocates translation blocks, writes dynamic AArch64 machine instructions, and toggles execution permission via standard `mprotect(PROT_READ | PROT_EXEC)` without encountering kernel permission traps.

---

## Release Verification & Checksums

The release package has been audited and verified:

| File | Size (Bytes) | SHA-256 Checksum |
|---|---|---|
| `crate-dopamine-rootless_1.0.0_iphoneos-arm.deb` | `8,099,324` | `55332cee414faa2df6f29691aba11b0c8a01ea03eb095c2aad5fa5dba8d3512d` |

To verify local package integrity:
```bash
shasum -a 256 build/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb
```

Run the automated verification suite:
```bash
python3 tests/verify_suite.py
```

---

## Building from Source

To compile the application and build the `.deb` package on macOS:

```bash
# 1. Clone repository
git clone https://github.com/<your-username>/crate-dopamine-rootless.git
cd crate-dopamine-rootless

# 2. Run automated build script
./scripts/build_crate.sh
```

For custom build instructions and Rust engine compilation, see [docs/build.md](docs/build.md).

---

## Credits & License

### Upstream Authors
- **Antonio Mendez** ([@oneamendez](https://github.com/oneamendez)) — Author of [Crate iOS](https://github.com/oneamendez/crate-ios) and [Crate](https://github.com/oneamendez/crate).
- **Lars Fröder** ([@opa334](https://github.com/opa334)) — Author of [Dopamine](https://github.com/opa334/Dopamine).
- **RootHide Team** ([@roothide](https://github.com/roothide)) — Authors of [Dopamine RootHide](https://github.com/roothide/Dopamine-roothide).

### License
- The primary codebase of Crate is licensed under the **Mozilla Public License Version 2.0 (MPL-2.0)**. See [LICENSE](LICENSE) for the full license text.
- Third-party components maintain their original upstream licenses (MIT, BSD-3-Clause, Apache-2.0, LGPL-2.1). Refer to [NOTICE](NOTICE), [docs/credits.md](docs/credits.md), and [src/THIRD_PARTY_NOTICES.md](src/THIRD_PARTY_NOTICES.md) for details.
