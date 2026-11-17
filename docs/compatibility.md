# Compatibility & Hardware Guide

This document outlines hardware, operating system, and jailbreak environment compatibility for **Crate Dopamine Rootless**.

---

## Target Device Profiles

### Primary Test Target
- **Device**: iPad Pro 11-inch (1st Generation, 2018)
- **Processor**: Apple A12X Bionic (8-core CPU: 4x Vortex + 4x Tempest)
- **Architecture**: `arm64e` (ARMv8.3-A with Pointer Authentication)
- **RAM**: 4 GB LPDDR4X
- **OS Version**: iPadOS 16.1.1
- **Jailbreak**: Dopamine (RootHide / Rootless mode)

### Secondary Reference Target
- **Device**: iPhone 11 Pro
- **Processor**: Apple A13 Bionic (6-core CPU: 2x Lightning + 4x Thunder)
- **Architecture**: `arm64e` (ARMv8.4-A)
- **RAM**: 4 GB LPDDR4X
- **OS Version**: iOS 16.0 – 16.5.1
- **Jailbreak**: Dopamine Rootless

---

## Hardware & Environment Matrix

| Hardware / SoC | CPU Architecture | Supported OS Range | Jailbreak Mode | JIT Status | Recommended Guest RAM |
|---|---|---|---|---|---|
| **Apple A12X** (iPad Pro 11" 2018) | `arm64e` | iPadOS 16.0 – 16.5.1 | Dopamine Rootless / RootHide | Supported (Direct native JIT) | 1536 MB – 2048 MB |
| **Apple A12Z** (iPad Pro 11" 2020) | `arm64e` | iPadOS 16.0 – 16.5.1 | Dopamine Rootless / RootHide | Supported (Direct native JIT) | 2048 MB – 2560 MB |
| **Apple A13** (iPhone 11 Pro) | `arm64e` | iOS 16.0 – 16.5.1 | Dopamine Rootless / RootHide | Supported (Direct native JIT) | 1536 MB – 2048 MB |
| **Apple A14 / A15 / A16** | `arm64e` | iOS 16.0 – 16.5.1 | Dopamine Rootless / RootHide | Supported (Direct native JIT) | 2048 MB |
| **Apple M1 / M2 iPads** | `arm64e` | iPadOS 16.0 – 16.5.1 | Dopamine Rootless / RootHide | Supported (Direct native JIT) | 2048 MB – 4096 MB |
| **Apple A11 & Earlier** | `arm64` | iOS 15.0 – 16.7.x | palera1n Rootless | Supported (`CS_DEBUGGED` path) | 1024 MB |

---

## Architecture & Subsystem Compatibility

### 1. Rootless File System Layout
- Rootless jailbreaks store bootstrap binaries, libraries, and application packages within `/var/jb/` rather than modifying the immutable root filesystem (`/`).
- The application bundle is installed to `/var/jb/Applications/Crate.app/`.
- No rootful paths (such as `/Applications` or `/Library/MobileSubstrate`) are hardcoded.

### 2. JIT & Executable Memory Execution
- On iOS 16.0 – 16.5.1 under Dopamine, jailbreak processes possess `CS_DEBUGGED` flags and entitlements:
  - `dynamic-codesigning` (Boolean `true`)
  - `com.apple.private.cs.debugger` (Boolean `true`)
  - `get-task-allow` (Boolean `true`)
- Dynamic translation blocks are allocated with `PROT_READ | PROT_WRITE`, compiled by the Rust JIT engine, and switched to `PROT_READ | PROT_EXEC` (or dual-mapped with `MAP_JIT`), running natively on host hardware without external debuggers.

### 3. Jetsam & RAM Allocation Guidelines
On devices with 4 GB total physical RAM (such as iPad Pro 2018 and iPhone 11 Pro):
- The iOS operating system and SpringBoard require approximately 1.5 GB to 2.0 GB of headroom.
- Guest VMs should be configured with **1536 MB to 2048 MB** of RAM.
- Allocating more than 2560 MB to a single guest VM risks triggering kernel Jetsam kills (`EXC_RESOURCE / MEMORY`).
