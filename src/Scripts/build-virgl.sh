#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build virglrenderer (MIT) and the libepoxy it needs (MIT) from their releases'
# sources, as Frameworks/GPU/virglrenderer.1.framework and epoxy.framework: what
# turns the guest's virtio-gpu 3D commands into OpenGL ES calls on ANGLE.
# crate opens virglrenderer.1.framework when a machine has a 3D display.
#
#     ./Scripts/build-virgl.sh
#
# Needs Scripts/build-angle.sh first, for ANGLE's EGL headers. Upstream
# virglrenderer already builds for Apple systems; libepoxy needs
# patches/libepoxy-ios-angle.patch to find ANGLE in an app, and virglrenderer's
# patches (patches/virglrenderer-*.patch) fit it to ANGLE on MoltenVK. iPhones
# only, like ANGLE. Needs meson, ninja and pkg-config (Homebrew), and Python's
# PyYAML, which virglrenderer's build uses.
#
# VIRGL_DIAGNOSTIC=1 builds virglrenderer with its debug output, which the
# VREND_DEBUG environment variable then turns on (tex, gles, bgra, ...): for
# finding out, not for shipping.
set -euo pipefail

EPOXY_VERSION=1.5.10
EPOXY_SHA256=a7ced37f4102b745ac86d6a70a9da399cc139ff168ba6b8002b4d8d43c900c15
VIRGL_VERSION=1.3.0
VIRGL_SHA256=065bc56e89e6f631f96101cd62eba0748e48eb888b434edc86e89d05395e76f3
MIN_IOS=18.0

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$REPO/.deps"
SRC="$DEPS/src"
WORK="$DEPS/virgl-build"
HEADERS="$DEPS/angle-include"
DEST="$REPO/Frameworks/GPU"
PATCHES=("$REPO"/Scripts/patches/virglrenderer-*.patch)
DIAGNOSTIC="${VIRGL_DIAGNOSTIC:-}"
STAMP="libepoxy $EPOXY_VERSION, virglrenderer $VIRGL_VERSION, ${#PATCHES[@]} patches${DIAGNOSTIC:+, diagnostic}"

if [ "$(cat "$DEST/virglrenderer.version" 2>/dev/null)" = "$STAMP" ] \
    && [ -d "$DEST/virglrenderer.1.framework" ] && [ -d "$DEST/epoxy.framework" ]; then
    echo "$STAMP already in Frameworks/GPU/"
    exit 0
fi
[ -f "$HEADERS/EGL/egl.h" ] || { echo "no ANGLE headers: run Scripts/build-angle.sh" >&2; exit 1; }
python3 -c 'import yaml' 2>/dev/null || { echo "virglrenderer's build needs PyYAML: python3 -m pip install pyyaml" >&2; exit 1; }

fetch() {  # url file sha256
    [ -f "$SRC/$2" ] || curl --fail --location --silent --show-error --output "$SRC/$2" "$1"
    echo "$3  $SRC/$2" | shasum -a 256 --check --quiet
}
mkdir -p "$SRC"
fetch "https://github.com/anholt/libepoxy/archive/refs/tags/$EPOXY_VERSION.tar.gz" \
      "libepoxy-$EPOXY_VERSION.tar.gz" "$EPOXY_SHA256"
fetch "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/$VIRGL_VERSION/virglrenderer-$VIRGL_VERSION.tar.gz" \
      "virglrenderer-$VIRGL_VERSION.tar.gz" "$VIRGL_SHA256"
rm -rf "$WORK"
mkdir -p "$WORK"
tar -xf "$SRC/libepoxy-$EPOXY_VERSION.tar.gz" -C "$WORK"
tar -xf "$SRC/virglrenderer-$VIRGL_VERSION.tar.gz" -C "$WORK"
patch --quiet -p1 -d "$WORK/libepoxy-$EPOXY_VERSION" < "$REPO/Scripts/patches/libepoxy-ios-angle.patch"
for p in "${PATCHES[@]}"; do
    patch --quiet -p1 -d "$WORK/virglrenderer-$VIRGL_VERSION" < "$p"
done

sysroot="$(xcrun --sdk iphoneos --show-sdk-path)"
target="arm64-apple-ios$MIN_IOS"
# ANGLE's headers stand in for the EGL ones iOS doesn't have, and each
# library finds the frameworks beside it in the app's Frameworks.
flags="'-target', '$target', '-isysroot', '$sysroot', '-I$HEADERS'"
links="'-target', '$target', '-isysroot', '$sysroot', '-Wl,-rpath,@loader_path/..'"
cat > "$WORK/cross.ini" <<CROSS
[binaries]
c = ['$(xcrun --sdk iphoneos -f clang)']
objc = ['$(xcrun --sdk iphoneos -f clang)']
cpp = ['$(xcrun --sdk iphoneos -f clang++)']
ar = '$(xcrun --sdk iphoneos -f ar)'
strip = '$(xcrun --sdk iphoneos -f strip)'
pkg-config = 'pkg-config'

[built-in options]
c_args = [$flags]
objc_args = [$flags]
cpp_args = [$flags]
c_link_args = [$links]
objc_link_args = [$links]
cpp_link_args = [$links]

[host_machine]
system = 'darwin'
subsystem = 'ios'
kernel = 'xnu'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
CROSS

prefix="$WORK/prefix"
mkdir -p "$prefix/lib/pkgconfig"
# Only what this build installs: never Homebrew's macOS libepoxy.
export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
export PKG_CONFIG_PATH=""

# Each build step runs quietly and shows its output only when it fails.
quietly() {
    "$@" > "$WORK/step.log" 2>&1 || { cat "$WORK/step.log" >&2; return 1; }
}

echo "==> libepoxy $EPOXY_VERSION"
quietly meson setup "$WORK/epoxy" "$WORK/libepoxy-$EPOXY_VERSION" --cross-file "$WORK/cross.ini" \
    --prefix "$prefix" --buildtype release --default-library shared \
    -Degl=yes -Dglx=no -Dx11=false -Dtests=false -Ddocs=false
quietly meson compile -C "$WORK/epoxy"
quietly meson install -C "$WORK/epoxy"

echo "==> virglrenderer $VIRGL_VERSION"
# check-gl-errors off: with it on, one GL call ANGLE refuses (Chrome's first
# CREATE_OBJECT gets GL_INVALID_ENUM) marks the guest's whole context broken
# and every later submit fails. Off, the error is logged and only that call is
# lost.
quietly meson setup "$WORK/virgl" "$WORK/virglrenderer-$VIRGL_VERSION" --cross-file "$WORK/cross.ini" \
    --prefix "$prefix" --buildtype release --default-library shared \
    -Dplatforms=egl -Dvenus=false -Dvideo=false -Dtests=false -Dfuzzer=false \
    -Dminigbm_allocation=false -Dtracing=none -Dcheck-gl-errors=false \
    ${DIAGNOSTIC:+-Db_ndebug=false}
quietly meson compile -C "$WORK/virgl"
quietly meson install -C "$WORK/virgl"

# A dylib as a framework: the binary under the framework's name, an @rpath
# install name, and an Info.plist.
framework() {  # dylib name
    local dylib="$1" name="$2"
    rm -rf "$DEST/$name.framework"
    mkdir -p "$DEST/$name.framework"
    cp "$dylib" "$DEST/$name.framework/$name"
    install_name_tool -id "@rpath/$name.framework/$name" "$DEST/$name.framework/$name"
    cat > "$DEST/$name.framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.amendez.crate.$name</string>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict></plist>
PLIST
}

mkdir -p "$DEST"
framework "$(ls "$prefix"/lib/libepoxy.*.dylib | head -1)" epoxy
# The name crate opens.
framework "$(ls "$prefix"/lib/libvirglrenderer.*.dylib | head -1)" virglrenderer.1
# virglrenderer names libepoxy by its install name; point it at the framework.
virgl="$DEST/virglrenderer.1.framework/virglrenderer.1"
old="$(otool -L "$virgl" | awk '/libepoxy/ {print $1}')"
install_name_tool -change "$old" "@rpath/epoxy.framework/epoxy" "$virgl"
echo "$STAMP" > "$DEST/virglrenderer.version"
echo "$STAMP in Frameworks/GPU/"
