# Installation Guide

Instructions for installing Crate on a jailbroken iOS device running Dopamine Rootless or Dopamine RootHide.

---

## Package Overview

- **File**: `crate-dopamine-rootless_1.0.0_iphoneos-arm.deb`
- **Identifier**: `com.amendez.crate`
- **Destination**: `/var/jb/Applications/Crate.app`
- **Architecture**: `iphoneos-arm` (compatible with `arm64` and `arm64e` iOS 16 devices)

---

## Method 1: Sileo or Zebra (Recommended)

1. Download the `.deb` file on your iOS device or transfer it via AirDrop / Filza.
2. Open the `.deb` in **Sileo** or **Zebra**.
3. Tap **Install** / **Get** and confirm.
4. The package manager will unpack the payload into `/var/jb/Applications/Crate.app` and execute `postinst`, which runs `/var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app`.
5. The Crate icon will appear on your Home Screen.

---

## Method 2: Command Line (SSH or Terminal)

1. Copy the `.deb` file to your device:
   ```bash
   scp crate-dopamine-rootless_1.0.0_iphoneos-arm.deb mobile@<device-ip>:/var/mobile/
   ```

2. SSH into your device and install with `dpkg`:
   ```bash
   ssh mobile@<device-ip>
   sudo dpkg -i /var/mobile/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb
   ```

3. If the app icon does not appear on SpringBoard immediately:
   ```bash
   /var/jb/usr/bin/uicache -p /var/jb/Applications/Crate.app
   ```

---

## Uninstallation

### Via Sileo or Zebra
1. Locate `Crate (Dopamine Rootless)` under **Installed Packages**.
2. Tap **Modify** -> **Remove**.
3. The package manager runs `prerm` to unregister the icon cache and removes the bundle files.

### Via Command Line
```bash
sudo dpkg -r com.amendez.crate
/var/jb/usr/bin/uicache -u /var/jb/Applications/Crate.app
```
