#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Publish the frameworks built on this Mac (idevice, libslirp and GLib, and the
# GPU stack: MoltenVK, ANGLE, libepoxy, virglrenderer) as one zip, a release of
# this repository, so Scripts/fetch-frameworks.sh and the ipa workflow get them
# without building them: ANGLE alone is a 4 GB checkout. Print the line that
# pins the release in fetch-frameworks.sh; commit that.
#
#     ./Scripts/release-frameworks.sh frameworks-2026.11.14
#
# Build them first with the scripts named in README.md. crate and StikJIT aren't
# in it: fetch-crate.sh and fetch-stikjit.sh get them from their own releases.
set -euo pipefail

TAG="${1:?usage: $0 TAG, e.g. frameworks-$(date +%Y.%m.%d)}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/Frameworks"
ITEMS="IDevice.xcframework IDevice.version Slirp.xcframework GLib.xcframework Slirp.version GPU"
for item in $ITEMS; do
    [ -e "$SRC/$item" ] || { echo "no Frameworks/$item: build it first" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/Frameworks"
for item in $ITEMS; do
    cp -R "$SRC/$item" "$WORK/Frameworks/"
done
(cd "$WORK" && ditto -c -k --keepParent Frameworks Frameworks.zip)
SHA256="$(shasum -a 256 "$WORK/Frameworks.zip" | cut -d' ' -f1)"
{
    echo "Frameworks the app builds with, from the scripts in Scripts/ at $(git -C "$REPO" rev-parse --short HEAD):"
    echo
    for version in IDevice.version Slirp.version GPU/MoltenVK.version GPU/ANGLE.version GPU/virglrenderer.version; do
        echo "- ${version%.version}: $(cat "$SRC/$version")"
    done
    echo
    echo "    SHA-256 $SHA256"
} > "$WORK/notes.md"

export GH_TOKEN="${GH_TOKEN:-$(gh auth token -u oneamendez)}"
# Never the repository's latest release: INSTALL.md's link to the latest
# release's IPA has to keep finding the app's.
gh release create "$TAG" -R oneamendez/crate-ios --title "Frameworks $TAG" --notes-file "$WORK/notes.md" --latest=false \
    "$WORK/Frameworks.zip"
echo "Pin it in Scripts/fetch-frameworks.sh:"
echo "VERSION=$TAG"
echo "SHA256=$SHA256"
