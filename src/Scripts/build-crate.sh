#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build crate, the VM engine, from a checkout (~/Repos/crate) as
# Frameworks/Crate.xcframework, with crate's own tools/xcframework.sh: the same
# library its releases hold, imported in Swift as `CrateEngine`. For changing
# crate and the app at once; Scripts/fetch-crate.sh gets the pinned release.
#
#     ./Scripts/build-crate.sh                   # crate from ~/Repos/crate
#     CRATE_DIR=/path/to/crate ./Scripts/build-crate.sh
#
# Needs Rust with the aarch64-apple-ios, aarch64-apple-ios-sim and
# aarch64-apple-darwin targets. crate leaves libslirp to the app:
# Scripts/build-slirp.sh builds it.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CRATE_DIR="${CRATE_DIR:-$HOME/Repos/crate}"
export PATH="$HOME/.cargo/bin:$PATH"

[ -f "$CRATE_DIR/include/crate.h" ] || { echo "no crate checkout at $CRATE_DIR (set CRATE_DIR)" >&2; exit 1; }
grep -q "module CrateEngine" "$CRATE_DIR/tools/xcframework.sh" || {
    echo "crate at $CRATE_DIR builds an older XCFramework: it needs the CrateEngine module (crate 0.1.0)" >&2
    exit 1
}
VERSION="$(git -C "$CRATE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
VERSION="$VERSION$(git -C "$CRATE_DIR" diff --quiet 2>/dev/null || echo +changes)"
for target in aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin; do
    rustup target list --installed | grep -qx "$target" || rustup target add "$target"
done

mkdir -p "$REPO/Frameworks"
"$CRATE_DIR/tools/xcframework.sh" "$REPO/Frameworks/Crate.xcframework" >/dev/null
echo "$VERSION" > "$REPO/Frameworks/Crate.version"
echo "crate $VERSION in Frameworks/"
