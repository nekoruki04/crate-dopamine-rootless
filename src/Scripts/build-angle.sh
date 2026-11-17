#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build ANGLE (BSD-3-Clause), Google's OpenGL ES on top of Vulkan, from upstream
# source, as Frameworks/GPU/EGL.framework and GLESv2.framework: the GL the
# VM's 3D is drawn with. crate opens EGL.framework when a machine has a 3D
# display, and virglrenderer draws the guest's GL with it.
#
#     ./Scripts/build-angle.sh
#
# ANGLE runs on Vulkan, which is MoltenVK (Scripts/build-moltenvk.sh), rather
# than on its own Metal backend: that one stops at OpenGL ES 3.0, and the
# guest's GL can go no higher than the host's. On Vulkan it reaches ES 3.1, with
# compute shaders. patches/angle-vulkan.patch makes that work in an app, and
# says what each change is for.
#
# Uses depot_tools and a gclient checkout of about 4 GB once the test suites and
# the OpenCL and WebGPU trees are left out. ANGLE_SRC and DEPOT_TOOLS reuse
# checkouts that already exist; otherwise both go in .deps/. The build, about
# two minutes on an M3, goes in its own out/ directory, so it can share a
# checkout with other builds. iPhones only, like MoltenVK.
set -euo pipefail

REV=9addc2983b90152f628cfdaea194983b46b254bd
MIN_IOS=18.0

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ANGLE="${ANGLE_SRC:-$REPO/.deps/angle}"
DEPOT="${DEPOT_TOOLS:-$REPO/.deps/depot_tools}"
PATCH="$REPO/Scripts/patches/angle-vulkan.patch"
DEST="$REPO/Frameworks/GPU"
OUT=out/crate-ios-arm64
STAMP="ANGLE $REV"
export PATH="$DEPOT:$PATH" DEPOT_TOOLS_METRICS=0

if [ "$(cat "$DEST/ANGLE.version" 2>/dev/null)" = "$STAMP" ] \
    && [ -d "$DEST/EGL.framework" ] && [ -d "$DEST/GLESv2.framework" ]; then
    echo "$STAMP already in Frameworks/GPU/"
    exit 0
fi

[ -d "$DEPOT" ] || git clone --quiet --depth 1 \
    https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT"
if [ ! -d "$ANGLE/.git" ]; then
    git init --quiet "$ANGLE"
    git -C "$ANGLE" fetch --quiet --depth 1 https://chromium.googlesource.com/angle/angle.git "$REV"
    git -C "$ANGLE" checkout --quiet FETCH_HEAD
    cat > "$ANGLE/.gclient" <<'EOF'
solutions = [{
  "name": ".",
  "url": "https://chromium.googlesource.com/angle/angle.git",
  "deps_file": "DEPS",
  "managed": False,
  "custom_deps": {
    "third_party/VK-GL-CTS/src": None,
    "third_party/catapult": None,
    "third_party/SwiftShader": None,
    "third_party/perfetto": None,
    "third_party/vulkan-validation-layers/src": None,
    "third_party/lunarg-vulkantools/src": None,
    "third_party/vulkan-tools/src": None,
    "third_party/OpenCL-Docs/src": None,
    "third_party/cherry": None,
    "tools/perf": None,
    "tools/md_browser": None,
    "tools/skia_goldctl/mac_amd64": None,
    "tools/skia_goldctl/mac_arm64": None,
  },
  "custom_vars": {"checkout_angle_cl_deps": False, "checkout_angle_dawn_deps": False},
}]
target_os = ["ios"]
EOF
    (cd "$ANGLE" && gclient sync --no-history --shallow -j8)
fi
[ "$(git -C "$ANGLE" rev-parse HEAD)" = "$REV" ] || { echo "$ANGLE isn't at $REV" >&2; exit 1; }
if git -C "$ANGLE" apply --check "$PATCH" 2>/dev/null; then
    git -C "$ANGLE" apply "$PATCH"
elif ! git -C "$ANGLE" apply --check -R "$PATCH" 2>/dev/null; then
    echo "angle-vulkan.patch neither applies to $ANGLE nor is applied" >&2
    exit 1
fi

mkdir -p "$ANGLE/$OUT"
cat > "$ANGLE/$OUT/args.gn" <<EOF
target_os = "ios"
target_environment = "device"
target_cpu = "arm64"
ios_deployment_target = "$MIN_IOS"
ios_enable_code_signing = false
is_debug = false
is_component_build = false
symbol_level = 0
dcheck_always_on = false
# virglrenderer only draws offscreen: no window surfaces.
angle_use_vulkan_null_display = true
angle_enable_vulkan = true
# MoltenVK directly; the Khronos loader isn't built.
angle_use_custom_libvulkan = false
# Kept, for trying ANGLE's own Metal backend (CRATE_ANGLE_PLATFORM=metal).
angle_enable_metal = true
angle_enable_gl = false
angle_enable_null = false
angle_enable_swiftshader = false
angle_enable_wgpu = false
angle_enable_cl = false
angle_build_tests = false
angle_has_frame_capture = false
angle_enable_perfetto = false
angle_enable_vulkan_validation_layers = false
EOF
echo "==> ANGLE ${REV:0:7}"
(cd "$ANGLE" && gn gen "$OUT" >/dev/null && third_party/ninja/ninja -C "$OUT" libEGL libGLESv2 >/dev/null)

# Each as a framework under the name crate and libepoxy open, and the one
# libEGL dispatches to: one GLESv2, so one ANGLE with one current context.
mkdir -p "$DEST"
for name in EGL GLESv2; do
    framework="$DEST/$name.framework"
    rm -rf "$framework"
    mkdir -p "$framework"
    cp "$ANGLE/$OUT/lib$name.framework/lib$name" "$framework/$name"
    install_name_tool -id "@rpath/$name.framework/$name" "$framework/$name"
    cat > "$framework/Info.plist" <<PLIST
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
done
# Its headers, which libepoxy and virglrenderer build against.
rm -rf "$REPO/.deps/angle-include"
cp -R "$ANGLE/include" "$REPO/.deps/angle-include"
echo "$STAMP" > "$DEST/ANGLE.version"
echo "$STAMP in Frameworks/GPU/"
