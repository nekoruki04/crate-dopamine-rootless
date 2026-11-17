# Installation Guide

This guide details how to install and run **Crate Dopamine Rootless** on a jailbroken iOS / iPadOS device running Dopamine Rootless or Dopamine RootHide.

---

## Prerequisites

- **Jailbreak Environment**:
  - Dopamine (v2.x) or Dopamine RootHide
  - iOS / iPadOS 16.0 through 16.5.1
- **Hardware**:
  - Primary Target: Apple A12X (iPad Pro 11-inch 2018), A12Z, A13 (iPhone 11 Pro), A14, A15, M1/M2
  - RAM: 4 GB minimum recommended (2 GB guest allocation ceiling)
- **Package Manager or Tools**:
  - Sileo or Zebra
  - Alternatively: Filza File Manager, NewTerm, or SSH access with `dpkg` and `uicache`

---

## Package Details

- **Package Filename**: `crate-dopamine-rootless_1.0.0_iphoneos-arm.deb`
- **Package ID**: `com.amendez.crate`
- **Installation Path**: `/var/jb/Applications/Crate.app`
- **Architecture**: `iphoneos-arm` (compatible with `arm64` and `arm64e` iOS 16 devices)

---

## Method 1: Sileo / Zebra Package Manager (Recommended)

1. Download or transfer `crate-dopamine-rootless_1.0.0_iphoneos-arm.deb` to your iOS device via AirDrop, Safari, or local file transfer.
2. In the Files app or Filza, tap the `.deb` file and select **Share** -> **Sileo** (or **Zebra**).
3. Confirm the package installation.
4. The package manager will unpack the payload into `/var/jb/Applications/Crate.app` and execute the maintainer script (`postinst`).
5. `postinst` triggers `/var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app` to register the application bundle with SpringBoard.
6. The **Crate** application icon will appear on your Home Screen.

---

## Method 2: Command Line (SSH or Local Terminal)

If you prefer terminal installation via SSH or NewTerm:

1. Copy the `.deb` file to your device:
   ```bash
   scp build/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb mobile@<DEVICE_IP>:/var/mobile/
   ```

2. Open an SSH session to your device:
   ```bash
   ssh mobile@<DEVICE_IP>
   ```

3. Install the package using `dpkg`:
   ```bash
   sudo dpkg -i /var/mobile/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb
   ```

4. If the icon does not appear immediately on SpringBoard, manually register the app cache:
   ```bash
   /var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app
   ```

---

## Verification After Installation

1. Tap the **Crate** icon on your Home Screen to launch the application.
2. Verify that the application opens directly to the VM manager without companion prompts or pairing dialogues.
3. Check **Settings** -> **JIT Status**:
   - Status should read `Native Direct Execution (Active)`.
   - No external pairing files or VPN helper services are required.
4. Launch or create a virtual machine to test execution.

---

## Uninstallation

### Via Sileo or Zebra
1. Navigate to the **Installed** tab.
2. Search for `Crate (Dopamine Rootless)`.
3. Select **Uninstall** / **Remove** and confirm.
4. The pre-removal script (`prerm`) unregisters the application cache (`uicache -u /var/jb/Applications/Crate.app`) and cleanly removes the files.

### Via Command Line
```bash
sudo dpkg -r com.amendez.crate
/var/jb/usr/bin/uicache -u /var/jb/Applications/Crate.app
```
