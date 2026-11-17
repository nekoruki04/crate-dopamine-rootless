# Build & Packaging Guide

This guide details the procedure for building the **Crate Dopamine Rootless** application and generating the rootless Debian package (`.deb`).

---

## Build Environment Requirements

- **Host Machine**: macOS 14 (Sonoma) or macOS 15 (Sequoia) running on Apple Silicon or Intel.
- **Xcode**: Xcode 15 or 16 with iPhoneOS SDK (SDK 16.0 through 18.x supported).
- **Tooling**:
  - `rustup` with target `aarch64-apple-ios`
  - `ldid` (Jailbreak pseudo-code signer)
  - `vtool` (Mach-O build version inspection and modification tool)
  - `dpkg-deb` or Python 3 for Debian packaging
  - `xcodegen` (optional, for regenerating Xcode projects)

---

## Step 1: Rust Virtualization Engine (`crate-core`)

The virtualization engine is implemented in Rust and linked as a static archive (`libcrate_ffi.a`) inside `Crate.xcframework`.

To compile the Rust engine for iOS ARM64:

```bash
# Add iOS compilation target
rustup target add aarch64-apple-ios

# Build the release archive targeting iOS 16.0
cd src/crate-core
IPHONEOS_DEPLOYMENT_TARGET=16.0 cargo build -p crate-ffi --release --target aarch64-apple-ios

# Update the XCFramework archive
cp target/aarch64-apple-ios/release/libcrate_ffi.a ../src/Frameworks/Crate.xcframework/ios-arm64/libcrate_ffi.a
```

---

## Step 2: Crate iOS Application (`xcodebuild`)

Compile the main application bundle:

```bash
cd src

# Compile Release build without code signing
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

The resulting application bundle will be located at:
`DerivedData/Build/Products/Release-iphoneos/Crate.app`

---

## Step 3: Mach-O Deployment Target Retargeting & Signing

To ensure the Mach-O binary runs reliably on iOS 16.0 devices:

```bash
APP_PATH="DerivedData/Build/Products/Release-iphoneos/Crate.app"

# Verify and set minimum OS version to 16.0
vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_PATH/Crate" "$APP_PATH/Crate"

# Sign application binary and bundled frameworks with jailbreak entitlements
ldid -S"../packaging/Crate.entitlements" "$APP_PATH/Crate"

for fw in "$APP_PATH/Frameworks/"*.framework; do
    fw_name=$(basename "$fw" .framework)
    if [ -f "$fw/$fw_name" ]; then
        ldid -S "$fw/$fw_name"
    fi
done
```

---

## Step 4: Debian Package Generation (`.deb`)

Package the application bundle into a canonical rootless `.deb`:

```bash
python3 scripts/package_deb.py \
  --app "src/DerivedData/Build/Products/Release-iphoneos/Crate.app" \
  --output "build/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"
```

The packaging script organizes the filesystem payload into:
```text
./var/jb/Applications/Crate.app/
```
and embeds the maintainer scripts (`control`, `postinst`, `prerm`) with appropriate ownership (`0:0`) and permissions (`0755`).

---

## Automated Verification

Run the verification test suite:

```bash
python3 tests/verify_suite.py
```
Checks:
- Debian package archive integrity (valid ar archive with `debian-binary`, `control.tar.gz`, `data.tar.gz`)
- Rootless payload hierarchy (`./var/jb/Applications/Crate.app`)
- Mach-O 64-bit architecture and iOS 16.0 minimum OS target
- Required entitlements present (`dynamic-codesigning`, `com.apple.private.cs.debugger`, etc.)
- All 7 bundled dynamic frameworks properly signed and linked
- Correct control metadata and maintainer script executable permissions
