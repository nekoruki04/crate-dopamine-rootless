#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build idevice's C library (github.com/jkcoxson/idevice, MIT) from source, at a pinned
# release, as Frameworks/IDevice.xcframework: what crate's app links to pair this iPhone with
# itself (iOS 27's device-initiated pairing) for Built-in StikJIT. StikJIT carries its own copy
# of idevice but exports none of it, so the pairing calls come from this build.
#
#     ./Scripts/build-idevice.sh
#
# One patch, Scripts/patches/idevice-pairable-host.patch, to the pairable host:
# - pairable_host_set_setup_code, so crate picks the pairing code and shows it before the
#   person goes to Settings (upstream draws it once the device has connected, while crate is
#   in the background);
# - the host's identifier as its identity, where upstream leaves it empty, so the pairing can
#   appear in Settings' list of paired computers.
#
# Only the remote_pairing feature (pairable host, RemotePairing pairing files), with the
# pure-Rust rustcrypto provider: idevice needs a TLS backend to compile its pairing file, and
# rustcrypto has no C or assembly to cross-compile. Only the static library is built.
# Needs Rust with the aarch64-apple-ios and aarch64-apple-ios-sim targets.
set -euo pipefail

TAG=v0.1.68
COMMIT=d32c8189c51c2789496b0768039419c3705498c3
FEATURES="remote_pairing rustcrypto"
TARGETS="aarch64-apple-ios aarch64-apple-ios-sim"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/.deps/idevice"
OUT="$REPO/Frameworks/IDevice.xcframework"
PATCH="$REPO/Scripts/patches/idevice-pairable-host.patch"
export PATH="$HOME/.cargo/bin:$PATH"
STAMP="$TAG $FEATURES $(shasum -a 256 "$PATCH" | cut -c1-12)"

if [ "$(cat "$REPO/Frameworks/IDevice.version" 2>/dev/null)" = "$STAMP" ] && [ -d "$OUT" ]; then
    echo "idevice $TAG already in Frameworks/"
    exit 0
fi

if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$REPO/.deps"
    git clone --quiet --depth 1 --branch "$TAG" https://github.com/jkcoxson/idevice.git "$SRC"
fi
[ "$(git -C "$SRC" rev-parse HEAD)" = "$COMMIT" ] || {
    echo "idevice at $SRC isn't $TAG ($COMMIT)" >&2; exit 1; }
# Back to the pinned source, then the patch.
git -C "$SRC" checkout --quiet -- .
git -C "$SRC" apply "$PATCH"

for target in $TARGETS; do
    rustup target list --installed | grep -qx "$target" || rustup target add "$target"
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ARGS=()
for target in $TARGETS; do
    (cd "$SRC" && IPHONEOS_DEPLOYMENT_TARGET=18.0 cargo rustc --quiet --release --locked \
        -p idevice-ffi --no-default-features --features "$FEATURES" \
        --crate-type staticlib --target "$target")
    mkdir -p "$WORK/$target"
    cp "$SRC/target/$target/release/libidevice_ffi.a" "$WORK/$target/"
    strip -S -x "$WORK/$target/libidevice_ffi.a" 2>/dev/null || true
    ARGS+=(-library "$WORK/$target/libidevice_ffi.a" -headers "$WORK/include")
done

# cbindgen writes ffi/idevice.h during the build; plist.h sits beside it. In a
# folder named for the module, so its module map can't collide with another
# library's when Xcode copies headers into the build's include/.
mkdir -p "$WORK/include/IDevice"
cp "$SRC/ffi/idevice.h" "$SRC/ffi/plist.h" "$WORK/include/IDevice/"
cat > "$WORK/include/IDevice/module.modulemap" <<'MAP'
module IDevice {
    header "idevice.h"
    export *
}
MAP

rm -rf "$OUT"
mkdir -p "$REPO/Frameworks"
xcodebuild -create-xcframework "${ARGS[@]}" -output "$OUT" >/dev/null
echo "$STAMP" > "$REPO/Frameworks/IDevice.version"
echo "idevice $TAG ($FEATURES) in Frameworks/"
