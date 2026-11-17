# Crate Jailbreak

Run Linux VMs on iPhone and iPad for Jailbreak with native in-process JIT and no companion app.

---

## Overview

[Crate](https://github.com/oneamendez/crate-ios) is an iOS application that runs Linux virtual machines directly on iOS and iPadOS using a custom ARM64 dynamic binary translation engine (`crate-core`) and VirtIO devices. On stock iOS, executing JIT-compiled code requires an external debugger or a companion application (such as StikJIT) connected over a local VPN tunnel.

**Crate Jailbreak** adapts Crate for jailbreak environments running [Dopamine](https://github.com/opa334/Dopamine) (Dopamine 2 and Dopamine 3) and Dopamine RootHide on iOS 16. It enables direct in-process executable memory execution without companion apps or computer pairing, and packages the application as a standard rootless Debian package (`.deb`).

---

## What This Port Changes

- **Direct in-process JIT**: Removed the StikJIT companion application, LocalDevVPN, pairing profiles, and network extension helper code. The application uses jailbreak code-signing flags (`CS_DEBUGGED`) and entitlements (`dynamic-codesigning`, `com.apple.private.cs.debugger`) to allocate and execute translated code directly via `mprotect`.
- **Rootless filesystem layout**: Packaged to install under `/var/jb/Applications/Crate.app` following rootless package conventions. Maintainer scripts handle `uicache` registration and deregistration on install and removal.
- **Deployment target retargeting**: Patched the main Mach-O executable and all 7 bundled dynamic frameworks (`slirp`, `glib`, `EGL`, `GLESv2`, `epoxy`, `virglrenderer.1`, `MoltenVK`) to an iOS 16.0 minimum deployment target using `vtool`.
- **UI backports**: Replaced iOS 18-specific SwiftUI tab and scene modifiers with iOS 16-compatible equivalents for stable rendering on iPadOS 16.1.1.
- **Engine preservation**: The underlying Rust virtualization engine (`crate-core`), translation cache (`crate-jit`), VirtIO subsystems (`crate-devices`), SLIRP userspace networking, and virglrenderer GPU pipelines are preserved without modification to their core emulation logic.

---

## Requirements

- **Jailbreak**: Dopamine 2 (2.0 – 2.4.x), Dopamine 3 (3.0 – 3.0.x), or Dopamine RootHide
- **Operating system**: iOS / iPadOS 16.0 – 26.0.1 (iOS 16.0 minimum deployment target; Dopamine 3 supports up to iOS 18.7.1 on arm64 and 26.0 – 26.0.1 on A12/A13)
- **Architecture**: 64-bit ARM (`arm64` / `arm64e`)
- **Package manager**: Sileo, Zebra, or terminal access (`dpkg`)
- **Memory**: 4 GB device RAM minimum recommended (e.g. iPad Pro 2018 A12X or later)

---

## Installation

Download the latest `.deb` package from [Releases](https://github.com/nekoruki04/crate-dopamine-rootless/releases/latest).

### Option A: Sileo or Zebra (Recommended)

1. Download or transfer `crate-dopamine-rootless_1.0.0_iphoneos-arm.deb` to your device (via AirDrop, Safari, or Filza).
2. Open the file in **Sileo** or **Zebra** and tap **Install**.
3. Confirm installation. The maintainer script will register the application with SpringBoard (`uicache`).

### Option B: Terminal (SSH)

```bash
# Transfer package to device
scp crate-dopamine-rootless_1.0.0_iphoneos-arm.deb mobile@<device-ip>:/var/mobile/

# Install via dpkg
ssh mobile@<device-ip> "sudo dpkg -i /var/mobile/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"
```

If the icon does not appear on your Home Screen immediately:
```bash
/var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app
```

For uninstallation instructions, see [docs/installation.md](docs/installation.md).

---

## Building from Source

### Prerequisites

- macOS 14+ with Xcode 15 or 16
- iPhoneOS SDK (16.0+)
- Rust toolchain with target `aarch64-apple-ios`
- `ldid` and `vtool`
- Python 3

### Automated Build

```bash
# Clone the repository
git clone https://github.com/nekoruki04/crate-dopamine-rootless.git
cd crate-dopamine-rootless

# Build application and generate .deb package
./scripts/build_crate.sh
```

For instructions on compiling the Rust virtualization static library (`libcrate_ffi.a`) from source, see [docs/build.md](docs/build.md).

---

## Compatibility

Environment and hardware compatibility is categorized strictly by verification status.

### Jailbreak Environment Status

| Jailbreak | Compatibility Status | Notes |
|---|---|---|
| **Dopamine 2** (2.0 – 2.4.x) | Verified on Physical Device | Fully tested on iPad Pro 11" (2018, A12X, iPadOS 16.1.1). In-process JIT, rootless install, and VM boot verified. |
| **Dopamine 3** (3.0 – 3.0.x) | Architecturally Supported | Supports iOS 15.0 – 17.3.1 (PPL/SPTM), iOS 15.0 – 18.7.1 and 26.0 – 26.0.1 (A12/A13), and iOS 15.0 – 18.7.1 (arm64). Shares `/var/jb` prefix, BaseBin conventions, `CS_DEBUGGED` execution, and `iphoneos-arm` packaging. Untested on physical device. |
| **Dopamine RootHide** | Verified on Physical Device | Fully tested on iPad Pro 11" (2018, A12X, iPadOS 16.1.1) in RootHide rootless mode. |

### Hardware Targets

#### Tested Targets

| Device | iOS/iPadOS | Jailbreak | Status | Notes |
|---|---|---|---|---|
| iPad Pro 11-inch (1st Gen, 2018, A12X) | iPadOS 16.1.1 | Dopamine RootHide / Dopamine 2 | Working | Verified on physical device. In-process JIT, rootless install, VM boot, and verification suite all pass. |

#### Untested Targets

| Device | iOS/iPadOS | Jailbreak | Status | Notes |
|---|---|---|---|---|
| iPhone 11 Pro (A13) | iOS 16.0 – 26.0.1 | Dopamine 2 / Dopamine 3 | Untested | Shares ARM64e architecture and deployment target; requires $\le 2\text{ GB}$ guest RAM. Supported up to 26.0.1 via Dopamine 3. |
| Other Apple Silicon (A12–A16, M-series) | iOS 16.0 – 18.7.1 / 26.0.1 | Dopamine 2 / Dopamine 3 | Untested | Binary slice is compatible, but not tested on physical hardware. |

See [docs/compatibility.md](docs/compatibility.md) for detailed memory constraints and architecture notes.

---

## Known Limitations

- **RAM and Jetsam limits**: On devices with 4 GB of total RAM, allocating more than 2 GB (2048 MB) to a guest VM will trigger Jetsam memory kills from the iOS kernel. Keep guest RAM at 1536 MB – 2048 MB.
- **No hardware hypervisor**: Apple's Hypervisor framework (`/dev/hypervisor`) is not exposed on iOS. Crate uses dynamic binary translation (`crate-jit`), which incurs an emulation overhead compared to native hypervisor virtualization.
- **iOS version range**: Tested on iOS 16.1.1. iOS 17.4+ introduced additional debugger memory traps (`brk #0x69`) that may affect direct JIT execution without further patches.
- **3D graphics**: 3D acceleration routes guest OpenGL commands through `virglrenderer` and MoltenVK onto Metal. Complex 3D rendering may throttle under sustained thermal load.

See [docs/troubleshooting.md](docs/troubleshooting.md) for crash diagnosis and common fixes.

---

## Credits

- **nekoruki** ([@nekoruki04](https://github.com/nekoruki04)) — Crate Jailbreak port maintainer.
- **Antonio Mendez** ([@oneamendez](https://github.com/oneamendez)) — Author of [Crate iOS](https://github.com/oneamendez/crate-ios) and [Crate](https://github.com/oneamendez/crate).
- **Lars Fröder** ([@opa334](https://github.com/opa334)) — Author of [Dopamine](https://github.com/opa334/Dopamine).
- **RootHide Team** ([@roothide](https://github.com/roothide)) — Authors of [Dopamine RootHide](https://github.com/roothide/Dopamine-roothide).
- **Third-party libraries**: SwiftTerm (MIT), GLib (LGPL-2.1+), libslirp (BSD-3-Clause), MoltenVK (Apache-2.0), virglrenderer (MIT), libepoxy (MIT), ANGLE (BSD-3-Clause). See [NOTICE](NOTICE) and [src/THIRD_PARTY_NOTICES.md](src/THIRD_PARTY_NOTICES.md) for full notices.

Full acknowledgments are detailed in [docs/credits.md](docs/credits.md).

---

## License

This project is licensed under the Mozilla Public License Version 2.0 (MPL-2.0). See [LICENSE](LICENSE) for the full license text.
