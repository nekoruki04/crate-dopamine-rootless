#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Fetch crate, the VM engine, as Frameworks/Crate.xcframework: the release of
# github.com/oneamendez/crate pinned below, checked against its SHA-256, so
# moving to another engine is a commit here. Imported in Swift as `CrateEngine`.
# Scripts/build-crate.sh builds it from a checkout instead, for changing crate.
#
#     ./Scripts/fetch-crate.sh
#
# VERIFY_ATTESTATION=1 also checks, with gh, that crate's release workflow
# built the zip (the ipa workflow sets it). CRATE_ZIP=path uses a zip made by
# crate's tools/xcframework.sh instead of downloading, with CRATE_SHA256 its
# hash, to try a build before it's released.
set -euo pipefail

VERSION=v0.1.1
SHA256=52fab3b7729feb4937566b9e4874cbf31e437626c46bb09295b56a1d0c9ea6ad
SHA256="${CRATE_SHA256:-$SHA256}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO/Frameworks"
if [ -z "${CRATE_ZIP:-}" ] && [ "$(cat "$DEST/Crate.version" 2>/dev/null)" = "$VERSION" ] \
        && [ -d "$DEST/Crate.xcframework" ]; then
    echo "crate $VERSION already in Frameworks/"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if [ -n "${CRATE_ZIP:-}" ]; then
    cp "$CRATE_ZIP" "$WORK/Crate.xcframework.zip"
    VERSION="$(basename "$CRATE_ZIP")"
else
    curl --fail --location --silent --show-error --output "$WORK/Crate.xcframework.zip" \
        "https://github.com/oneamendez/crate/releases/download/$VERSION/Crate.xcframework.zip"
fi
echo "$SHA256  $WORK/Crate.xcframework.zip" | shasum -a 256 --check --quiet
if [ "${VERIFY_ATTESTATION:-}" = 1 ]; then
    gh attestation verify "$WORK/Crate.xcframework.zip" --repo oneamendez/crate \
        --signer-workflow oneamendez/crate/.github/workflows/release.yml >/dev/null
    echo "crate $VERSION: attested by crate's release workflow"
fi
mkdir "$WORK/out"
ditto -x -k "$WORK/Crate.xcframework.zip" "$WORK/out"
[ -d "$WORK/out/Crate.xcframework" ] || { echo "no Crate.xcframework in the zip" >&2; exit 1; }
mkdir -p "$DEST"
rm -rf "$DEST/Crate.xcframework"
mv "$WORK/out/Crate.xcframework" "$DEST/"
echo "$VERSION" > "$DEST/Crate.version"
echo "crate $VERSION in Frameworks/"
