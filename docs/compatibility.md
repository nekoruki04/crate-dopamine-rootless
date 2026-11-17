# Compatibility & Hardware Guide

This document details hardware, operating system, and memory constraints for Crate across Dopamine 2 and Dopamine 3 rootless jailbreak environments.

---

## Jailbreak Environment Support

| Environment | Supported OS Range | Architecture | Verification Status | Notes |
|---|---|---|---|---|
| **Dopamine 2** (2.0 – 2.4.x) | iOS 15.0 – 16.5.1 (`arm64e`)<br>iOS 15.0 – 16.6.1 (`arm64`) | `arm64`, `arm64e` | **Verified on Physical Device** | Tested on iPad Pro 11" 2018 (A12X, iPadOS 16.1.1). Direct JIT, rootless installation, and VM boot verified. |
| **Dopamine 3** (3.0 – 3.0.x) | iOS 15.0 – 17.3.1 (`arm64e`)<br>iOS 15.0 – 18.7.1 (`arm64`) | `arm64`, `arm64e` | **Architecturally Supported** | Uses shared `/var/jb` rootless prefix, identical BaseBin paths (`jbctl`), and `CS_DEBUGGED` primitives. Untested on physical device. |
| **Dopamine RootHide** | iOS 15.0 – 16.5.1 | `arm64`, `arm64e` | **Verified on Physical Device** | Tested on iPad Pro 11" 2018 (A12X, iPadOS 16.1.1) in RootHide rootless mode. |

---

## Hardware Verification Status

Compatibility is classified strictly into tested and untested targets.

### Tested Targets

| Device | Processor | Architecture | OS Version | Jailbreak | Test Result |
|---|---|---|---|---|---|
| iPad Pro 11-inch (1st Gen, 2018) | Apple A12X (4P + 4E) | `arm64e` | iPadOS 16.1.1 | Dopamine RootHide / Dopamine 2 | **Working** |

**Verification Details for iPad Pro 11" 2018 (A12X):**
- In-process JIT execution verified without external debugger.
- Rootless filesystem installation verified at `/var/jb/Applications/Crate.app`.
- Sileo and `dpkg -i` package installations verified.
- SpringBoard icon cache registration (`uicache -p`) verified.
- Automated static and Mach-O verification test suite passed.

---

### Untested Targets

| Device | Processor | Architecture | Target OS | Expected Status | Notes |
|---|---|---|---|---|---|
| iPhone 11 Pro | Apple A13 | `arm64e` | iOS 16.0 – 17.3.1 | Untested | Shares ARM64e architecture and deployment target; requires $\le 2\text{ GB}$ guest RAM. |
| Other Apple Silicon (A12–A16, M1/M2) | Various | `arm64e` | iOS 16.0 – 17.3.1 | Untested | Binary slice is compatible, but unverified on physical hardware. |
| Pre-A12 Devices (iPhone X, 8) | Apple A11 | `arm64` | iOS 15.0 – 16.7 | Untested | Uses checkm8/palera1n rather than Dopamine; binary slice contains `arm64`. |

---

## Dopamine 2 vs Dopamine 3 Comparison

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│           Dopamine 2            │       │           Dopamine 3            │
│       (iOS 15.0 – 16.5.1)       │       │       (iOS 15.0 – 17.3.1)       │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ • Exploits: kfd / multicast     │       │ • Exploits: DarkSword / Titan   │
│ • BaseBin: launchdhook          │       │ • BaseBin: hookd daemon         │
│ • JIT: CS_DEBUGGED + mprotect   │       │ • JIT: CS_DEBUGGED + txm_fix    │
│ • Rootless Prefix: /var/jb      │───────│ • Rootless Prefix: /var/jb      │
│ • Package ABI: iphoneos-arm     │───────│ • Package ABI: iphoneos-arm     │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

### 1. Rootless Filesystem Layout
Both Dopamine 2 and Dopamine 3 use `/var/jb` as the canonical rootless prefix (symlinked to `/private/preboot/<UUID>/jb-.../procursus`):
- Application bundle: `/var/jb/Applications/Crate.app/`
- Binary executable: `/var/jb/Applications/Crate.app/Crate`
- Bundled dynamic frameworks: `/var/jb/Applications/Crate.app/Frameworks/`
- Maintainer tools: `/var/jb/usr/bin/uicache`
- Control utility: `/var/jb/basebin/jbctl`

No hardcoded rootful paths (`/Applications` or `/Library/MobileSubstrate`) are used.

### 2. BaseBin Architecture & Injection
- **Dopamine 2**: Uses `launchdhook` and `systemhook.dylib` injected via environment variables and mach message interception.
- **Dopamine 3**: Introduces a dedicated `hookd` daemon managing process registration, alongside TXM (Trusted Execution Monitor) address space workarounds (`txm_fork_fix`) on iOS 17+.
- **Compatibility Handling**: Crate uses the dedicated `DopamineEnvironment` Swift module to probe the active environment. Because Crate executes standalone as a GUI application without requiring tweak injection into foreign daemons, it functions identically across both BaseBin architectures.

### 3. JIT Execution Mechanism
In standard iOS, memory pages mapped as executable cannot be written to without special entitlements and external debugger attachment.

Under Dopamine 2 and 3:
1. The kernel and BaseBin set the `CS_DEBUGGED` flag on the process.
2. The binary is signed with:
   - `dynamic-codesigning` (`true`)
   - `com.apple.private.cs.debugger` (`true`)
   - `get-task-allow` (`true`)
3. `CodeRegion.c` employs dual-fallback JIT activation:
   - Primary: Self-attach cycle via `fork()` and `ptrace(PT_ATTACH, getppid(), 0, 0)` to guarantee `CS_DEBUGGED` state.
   - Fallback: `/var/jb/basebin/jbctl proc_set_debugged <pid>` invocation if available.
4. Dynamic translation allocates memory buffers with `PROT_READ | PROT_WRITE`, compiles ARM64 instruction blocks, and switches permissions to `PROT_READ | PROT_EXEC` via `mprotect` without kernel traps.

### 4. Unified Package Rationale
A single `.deb` package supports both Dopamine 2 and Dopamine 3:
- The filesystem layout (`/var/jb/Applications/Crate.app`) is identical.
- The package ABI (`iphoneos-arm`) is shared across Procursus bootstraps.
- The control dependencies (`firmware >= 16.0`) align across both environments.
- Maintainer scripts (`postinst`, `prerm`, `postrm`) use identical `uicache` invocations.
Maintaining separate packages would introduce duplicate release artifacts without technical necessity.

---

## Memory & Jetsam Limits
Devices with 4 GB physical RAM (e.g., iPad Pro 2018, iPhone 11 Pro) share system memory between SpringBoard, background daemons, and Crate:
- System headroom requirement: approximately 1.5 GB – 2.0 GB.
- Safe guest allocation: **1536 MB to 2048 MB**.
- Allocating $\ge 2560\text{ MB}$ will trigger kernel Jetsam kills (`EXC_RESOURCE / MEMORY`).
