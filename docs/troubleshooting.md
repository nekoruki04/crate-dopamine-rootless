# Troubleshooting

Diagnostic guidance for common issues in Dopamine Rootless environments.

---

## 1. App Icon Not Appearing on SpringBoard

- **Cause**: SpringBoard icon cache did not register the new bundle.
- **Solution**:
  Run `uicache` manually from a terminal or SSH session:
  ```bash
  /var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app
  ```
  If it still does not appear, restart user space:
  ```bash
  /var/jb/usr/bin/launchctl reboot userspace
  ```

---

## 2. Crash on Launch (`EXC_CRASH` / `SIGKILL`)

- **Check Entitlements**:
  Inspect the entitlements embedded in the installed binary:
  ```bash
  ldid -e /var/jb/Applications/Crate.app/Crate
  ```
  Ensure `dynamic-codesigning` is set to `<true/>` and `com.apple.private.cs.debugger` is present.
- **Check Deployment Target**:
  Verify the binary load commands:
  ```bash
  vtool -show-build /var/jb/Applications/Crate.app/Crate
  ```
  Confirm `minos` is `16.0`.

---

## 3. Virtual Machine Terminates Unexpectedly (Jetsam Kill)

- **Cause**: Memory limit exceeded. On 4 GB devices (iPad Pro 2018, iPhone 11 Pro), allocating $> 2\text{ GB}$ to a guest VM leaves insufficient memory for iOS background daemons, causing the kernel Jetsam daemon to terminate Crate.
- **Diagnostics**:
  Check `Settings` -> `Privacy & Security` -> `Analytics & Improvements` -> `Analytics Data` for `JetsamEvent-*` crash logs.
- **Solution**:
  In Crate machine settings, reduce guest RAM to **1536 MB** or **2048 MB**.

---

## 4. JIT Execution Errors

- **Check JIT Status**:
  Inside Crate, navigate to **Settings** -> **JIT Status** to confirm that direct execution is active.
- **Verify W^X Memory Transitions**:
  Run the standalone test tool to verify writable-to-executable memory transitions:
  ```bash
  gcc -arch arm64 -o jit_test tests/jit_test.c
  ldid -S"packaging/Crate.entitlements" jit_test
  ./jit_test
  ```

---

## 5. Guest Networking Issues

- Ensure the host iOS device is connected to Wi-Fi or cellular data.
- Verify guest interface is configured for DHCP.
- Ensure the guest DNS nameserver is set to `10.0.2.3` (SLIRP default).
