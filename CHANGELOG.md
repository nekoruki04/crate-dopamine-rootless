# Changelog

All notable changes to the Crate Dopamine Rootless port are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-11-17

### Added
- Rootless Debian package generation installing to `/var/jb/Applications/Crate.app/`.
- Maintainer scripts (`postinst`, `prerm`) managing SpringBoard icon registration via `uicache`.
- Direct in-process JIT enablement leveraging `dynamic-codesigning` and `com.apple.private.cs.debugger` entitlements under Dopamine.
- Version-aware jailbreak detection module (`DopamineEnvironment.swift`) detecting Dopamine 2, Dopamine 3, Dopamine RootHide, and generic rootless environments.
- Dual-fallback JIT activation in `CodeRegion.c`: child `ptrace(PT_ATTACH)` self-attach cycle with `/var/jb/basebin/jbctl proc_set_debugged` fallback.
- Deployment target retargeting to iOS 16.0 for the main executable and all 7 bundled dynamic frameworks.
- Verification test suite (`tests/verify_suite.py`) validating package hierarchy, Mach-O architecture, load commands, code signatures, and entitlements.
- C test utility (`tests/jit_test.c`) verifying writable-to-executable memory transitions.

### Changed
- Replaced iOS 18-specific tab syntax with iOS 16-compatible `.tabItem` and `.tag()` views.
- Removed speculative SwiftUI APIs in `TabRail.swift` and `MachineScreen.swift` for stable execution on iPadOS 16.1.1.
- Added application icon assets (1024x1024) to satisfy `actool` asset catalog compiler requirements.

### Removed
- Removed `CrateJITHelper` target, StikJIT frameworks, and pairing code.
- Removed VPN-based developer pairing and remote pairing port listeners.
