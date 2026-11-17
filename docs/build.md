# Build & Packaging Guide

Instructions for building Crate from source and generating the rootless Debian package.

---

## Build Requirements

- macOS 14 (Sonoma) or 15 (Sequoia)
- Xcode 15 or 16 with iPhoneOS SDK
- Rust toolchain with target `aarch64-apple-ios`
- `ldid` (pseudo-code signer)
- `vtool` (Mach-O build version modifier)
- Python 3

---

## 1. Rust Virtualization Engine (`crate-core`)

The virtualization engine is compiled as a static library (`libcrate_ffi.a`) and wrapped into `Crate.xcframework`:

```bash
# Install target if needed
rustup target add aarch64-apple-ios

# Build release static library
cd src/crate-core
IPHONEOS_DEPLOYMENT_TARGET=16.0 cargo build -p crate-ffi --release --target aarch64-apple-ios

# Update framework binary
cp target/aarch64-apple-ios/release/libcrate_ffi.a ../src/Frameworks/Crate.xcframework/ios-arm64/libcrate_ffi.a
```

---

## 2. iOS Application (`xcodebuild`)

Compile the main application bundle:

```bash
cd src

xcodebuild -project Crate.xcodeproj \
  -scheme Crate \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

The compiled bundle is located at:
`DerivedData/Build/Products/Release-iphoneos/Crate.app`

---

## 3. Retargeting and Signing

Set the minimum deployment target to iOS 16.0 and sign with jailbreak entitlements:

```bash
APP_PATH="DerivedData/Build/Products/Release-iphoneos/Crate.app"

# Retarget main binary
vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_PATH/Crate" "$APP_PATH/Crate"

# Sign main binary with entitlements
ldid -S"../packaging/Crate.entitlements" "$APP_PATH/Crate"

# Retarget and sign bundled frameworks
for fw in "$APP_PATH/Frameworks/"*.framework; do
    fw_name=$(basename "$fw" .framework)
    if [ -f "$fw/$fw_name" ]; then
        vtool -set-build-version ios 16.0 16.0 -replace -output "$fw/$fw_name" "$fw/$fw_name" || true
        ldid -S "$fw/$fw_name"
    fi
done
```

---

## 4. Packaging the `.deb`

Generate the rootless Debian package:

```bash
python3 scripts/package_deb.py \
  --app "src/DerivedData/Build/Products/Release-iphoneos/Crate.app" \
  --output "build/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"
```

The script structures the payload into `./var/jb/Applications/Crate.app/` with permissions `0755` and `root:wheel` ownership.

---

## 5. Automated Build Script

To run all steps automatically:

```bash
./scripts/build_crate.sh
```

To run verification checks against the generated package:

```bash
python3 tests/verify_suite.py
```
