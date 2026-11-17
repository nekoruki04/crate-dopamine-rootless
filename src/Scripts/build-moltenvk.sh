#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build MoltenVK (Apache-2.0), Khronos's Vulkan on Metal, from its release's
# source, as Frameworks/GPU/MoltenVK.framework: what ANGLE renders the VM's 3D
# on. See Scripts/build-angle.sh for why ANGLE runs on Vulkan rather than on
# Metal directly.
#
#     ./Scripts/build-moltenvk.sh
#
# For iPhones only: the Simulator has no GPU acceleration, and crate falls back
# to a plain 2D display there. fetchDependencies builds MoltenVK's own
# dependencies (SPIRV-Cross, SPIRV-Tools, glslang, the Vulkan headers) at the
# revisions this release names; a clean build is about 15 minutes.
set -euo pipefail

VERSION=1.4.2
COMMIT=db66022459ffb663aa2b50f6b018bc2e124f5edf   # tag v1.4.2

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/.deps/src/MoltenVK-$VERSION"
DEST="$REPO/Frameworks/GPU"
STAMP="MoltenVK $VERSION"

if [ "$(cat "$DEST/MoltenVK.version" 2>/dev/null)" = "$STAMP" ] && [ -d "$DEST/MoltenVK.framework" ]; then
    echo "$STAMP already in Frameworks/GPU/"
    exit 0
fi

if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone --quiet --depth 1 --branch "v$VERSION" https://github.com/KhronosGroup/MoltenVK.git "$SRC"
fi
[ "$(git -C "$SRC" rev-parse HEAD)" = "$COMMIT" ] || { echo "MoltenVK v$VERSION isn't $COMMIT" >&2; exit 1; }

cd "$SRC"
echo "==> MoltenVK's dependencies"
# Not --parallel-build: that kills its whole process group on exit, this
# script with it.
./fetchDependencies --ios >/dev/null
echo "==> MoltenVK $VERSION"
make ios >/dev/null

BUILT="$SRC/Package/Release/MoltenVK/dynamic/MoltenVK.xcframework/ios-arm64/MoltenVK.framework"
[ -d "$BUILT" ] || { echo "no $BUILT" >&2; exit 1; }
mkdir -p "$DEST"
rm -rf "$DEST/MoltenVK.framework"
cp -R "$BUILT" "$DEST/"
echo "$STAMP" > "$DEST/MoltenVK.version"
echo "$STAMP in Frameworks/GPU/"
