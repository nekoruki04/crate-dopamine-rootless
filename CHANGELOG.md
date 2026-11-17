# Changelog

All notable changes to the Crate Dopamine Rootless project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-11-17

### Added
- **Rootless Debian Package Architecture**:
  - Full rootless packaging pipeline installing to canonical `/var/jb/Applications/Crate.app/`.
  - Maintainer scripts (`postinst`, `prerm`) with automatic SpringBoard icon cache (`uicache`) management.
  - Compatibility with Sileo, Zebra, Filza, and command-line `dpkg`.
- **Autonomous Direct JIT Activation**:
  - Integrated in-process executable memory allocation using `dynamic-codesigning` and `com.apple.private.cs.debugger` entitlements.
  - Zero-companion workflow: no StikJIT, StikDebug, LocalDevVPN, pairing profiles, or computer pairing required.
- **Mach-O iOS 16 Deployment Retargeting**:
  - Retargeted main executable and all 7 dynamic frameworks (`slirp`, `glib`, `EGL`, `GLESv2`, `epoxy`, `virglrenderer.1`, `MoltenVK`) to `minos 16.0`.
- **Automated Verification Suite**:
  - Standalone verification script (`tests/verify_suite.py`) validating package hierarchy, Mach-O architecture, load commands, code signatures, entitlements, and deb archive headers.
  - Standalone C JIT test (`tests/jit_test.c`) verifying writable-executable memory transitions.

### Changed
- **UI & SwiftUI Backports**:
  - Replaced iOS 18-specific tab syntax with iOS 16-compatible `.tabItem` and `.tag()` views.
  - Removed speculative APIs in `TabRail.swift` and `MachineScreen.swift` for stable execution on iPadOS 16.1.1.
- **App Icons & Assets**:
  - Added required 1024x1024 application asset catalog icons to satisfy `actool` compiler requirements.

### Removed
- **Companion Helper Dependencies**:
  - Removed `CrateJITHelper` target, StikJIT frameworks, and pairing code.
  - Removed VPN-based developer pairing and remote pairing port listeners.
