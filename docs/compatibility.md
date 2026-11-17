# Compatibility & Hardware Guide

This document details hardware, operating system, and memory constraints for Crate in a Dopamine Rootless jailbreak environment.

---

## Hardware Verification Status

Compatibility is classified strictly into tested and untested targets.

### Tested Targets

| Device | Processor | Architecture | OS Version | Jailbreak | Test Result |
|---|---|---|---|---|---|
| iPad Pro 11-inch (1st Gen, 2018) | Apple A12X (4P + 4E) | `arm64e` | iPadOS 16.1.1 | Dopamine RootHide / Rootless | **Working** |

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
| iPhone 11 Pro | Apple A13 | `arm64e` | iOS 16.0 – 16.5.1 | Untested | Shares ARM64e architecture and deployment target; requires $\le 2\text{ GB}$ guest RAM. |
| Other Apple Silicon (A12–A16, M1/M2) | Various | `arm64e` | iOS 16.0 – 16.5.1 | Untested | Binary slice is compatible, but unverified on physical hardware. |
| Pre-A12 Devices (iPhone X, 8) | Apple A11 | `arm64` | iOS 15.0 – 16.7 | Untested | Uses checkm8/palera1n rather than Dopamine; binary slice contains `arm64`. |

---

## System Architecture

### 1. Rootless Filesystem Layout
Dopamine Rootless does not modify the Sealed System Volume (SSV). All jailbreak payloads, libraries, and applications reside within the `/var/jb` prefix:
- Application path: `/var/jb/Applications/Crate.app/`
- Binary executable: `/var/jb/Applications/Crate.app/Crate`
- Bundled frameworks: `/var/jb/Applications/Crate.app/Frameworks/`
- Maintainer tools: `/var/jb/usr/bin/uicache`

No hardcoded rootful paths (`/Applications` or `/Library/MobileSubstrate`) are used.

### 2. JIT Execution Mechanism
In standard iOS, pages mapped as executable cannot be written to without special entitlements and debugger approval. 

Under Dopamine Rootless:
- The jailbreak kernel and BaseBin set the `CS_DEBUGGED` flag on the process.
- The binary is signed with:
  - `dynamic-codesigning` (`true`)
  - `com.apple.private.cs.debugger` (`true`)
  - `get-task-allow` (`true`)
- Dynamic code generation allocates memory buffers with `PROT_READ | PROT_WRITE`, compiles ARM64 instruction blocks, and switches permissions to `PROT_READ | PROT_EXEC` via `mprotect` without kernel traps.

### 3. Memory & Jetsam Limits
Devices with 4 GB physical RAM (e.g., iPad Pro 2018, iPhone 11 Pro) share system memory between SpringBoard, background daemons, and Crate:
- System headroom requirement: approximately 1.5 GB – 2.0 GB.
- Safe guest allocation: **1536 MB to 2048 MB**.
- Allocating $\ge 2560\text{ MB}$ will trigger kernel Jetsam kills (`EXC_RESOURCE / MEMORY`).
