#!/usr/bin/env bash
set -euo pipefail

# Build Crate Dopamine Rootless
# Generates release binary, patches Mach-O load commands, signs with ldid, and packages .deb

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
PACKAGING_DIR="$ROOT_DIR/packaging"

echo "=== [1/4] Building Crate Application with xcodebuild ==="
mkdir -p "$BUILD_DIR"
cd "$SRC_DIR"

xcodebuild -project Crate.xcodeproj \
  -scheme Crate \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/Crate.app"

if [ ! -d "$APP_PATH" ]; then
    echo "[-] Error: Built application bundle not found at $APP_PATH"
    exit 1
fi

echo "=== [2/4] Retargeting Mach-O Deployment to iOS 16.0 ==="
vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_PATH/Crate" "$APP_PATH/Crate"

for fw in "$APP_PATH/Frameworks/"*.framework; do
    fw_name=$(basename "$fw" .framework)
    if [ -f "$fw/$fw_name" ]; then
        vtool -set-build-version ios 16.0 16.0 -replace -output "$fw/$fw_name" "$fw/$fw_name" || true
    fi
done

echo "=== [3/4] Code Signing with Jailbreak Entitlements ==="
ldid -S"$PACKAGING_DIR/Crate.entitlements" "$APP_PATH/Crate"

for fw in "$APP_PATH/Frameworks/"*.framework; do
    fw_name=$(basename "$fw" .framework)
    if [ -f "$fw/$fw_name" ]; then
        ldid -S "$fw/$fw_name"
    fi
done

echo "=== [4/4] Creating Rootless Debian Package ==="
python3 "$ROOT_DIR/scripts/package_deb.py" \
  --app "$APP_PATH" \
  --output "$BUILD_DIR/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"

echo "[+] Successfully generated: $BUILD_DIR/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"
shasum -a 256 "$BUILD_DIR/crate-dopamine-rootless_1.0.0_iphoneos-arm.deb"
