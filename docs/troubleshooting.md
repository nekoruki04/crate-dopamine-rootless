# Troubleshooting & Diagnostics

This document provides diagnostic solutions for common issues encountered during installation, execution, or VM operation in Dopamine Rootless environments.

---

## 1. Installation & SpringBoard Icon Issues

### Problem: Application icon does not appear on SpringBoard after installation
- **Cause**: SpringBoard icon cache (`uicache`) did not refresh automatically.
- **Solution**:
  Run `uicache` manually via SSH or a mobile terminal:
  ```bash
  /var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app
  ```
  If the icon still does not show, perform a user space reboot:
  ```bash
  /var/jb/usr/bin/launchctl reboot userspace
  ```

### Problem: `dpkg: error: cannot access archive`
- **Cause**: The transferred `.deb` file is corrupted or incomplete.
- **Solution**:
  Verify the SHA-256 checksum of your `.deb` file against `build/checksums.txt`:
  ```bash
  shasum -a 256 crate-dopamine-rootless_1.0.0_iphoneos-arm.deb
  # Expected: 55332cee414faa2df6f29691aba11b0c8a01ea03eb095c2aad5fa5dba8d3512d
  ```

---

## 2. Launch & Crash Diagnostics

### Problem: App crashes instantly on launch with `EXC_CRASH (SIGKILL)` or `EXC_BAD_ACCESS`
- **Check 1: Entitlements and Code Signing**
  Verify that the main binary has valid jailbreak pseudo-signatures:
  ```bash
  ldid -e /var/jb/Applications/Crate.app/Crate
  ```
  Ensure `dynamic-codesigning` is set to `<true/>`.
- **Check 2: Minimum OS Mismatch**
  If testing on iOS 16.1.1, inspect the Mach-O load commands:
  ```bash
  vtool -show-build /var/jb/Applications/Crate.app/Crate
  ```
  Confirm `minos` is `16.0`.

### Problem: Guest VM terminates abruptly under load (Jetsam Crash)
- **Cause**: Out-of-memory kill by kernel Jetsam daemon.
- **Diagnostics**:
  Inspect the crash logs in `Settings` -> `Privacy & Security` -> `Analytics & Improvements` -> `Analytics Data` for `JetsamEvent-*`.
- **Solution**:
  Lower the guest RAM allocation in the machine settings to **1536 MB** or **2048 MB**. Avoid allocating greater than 2.5 GB on 4 GB physical RAM devices.

---

## 3. JIT & Virtualization Issues

### Problem: Linux kernel stops or hangs during boot
- **Check JIT Status**:
  Inside Crate, navigate to **Settings** -> **JIT Status**.
  Confirm that JIT shows as active.
- **Test Executable Memory**:
  You can run the standalone verification tool to confirm whether W^X / memory protection transitions succeed on your device:
  ```bash
  gcc -arch arm64 -o jit_test tests/jit_test.c
  ldid -S"packaging/Crate.entitlements" jit_test
  ./jit_test
  ```

---

## 4. Network & Internet Connectivity in Guest

### Problem: Guest Linux system has no network or internet connection
- **Cause**: Userspace SLIRP networking initialization failure.
- **Solution**:
  1. Ensure the host iOS device is connected to Wi-Fi or cellular data.
  2. Verify that guest network configuration uses DHCP.
  3. Ensure guest nameserver is set to `10.0.2.3` (SLIRP default DNS forwarder).
