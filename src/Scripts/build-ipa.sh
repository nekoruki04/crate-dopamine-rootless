#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build crate as an unsigned IPA, as the ipa workflow does: an iPhone Release
# archive with signing off, Payload/Crate.app zipped. Anyone can then sign it
# with their own certificate; Scripts/sign-ipa.sh does it with this team's.
#
#     ./Scripts/build-ipa.sh [OUT]     # default build/crate-unsigned.ipa
#
# Needs Frameworks/ (Scripts/fetch-frameworks.sh, fetch-stikjit.sh and
# fetch-crate.sh, or the build scripts) and XcodeGen.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$REPO/build/crate-unsigned.ipa}"
mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$REPO"
xcodegen generate --quiet
xcodebuild archive -quiet -project Crate.xcodeproj -scheme Crate -configuration Release \
    -destination generic/platform=iOS -derivedDataPath "$WORK/derived" -archivePath "$WORK/Crate.xcarchive" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
mkdir "$WORK/Payload"
cp -R "$WORK/Crate.xcarchive/Products/Applications/Crate.app" "$WORK/Payload/"
rm -f "$OUT"
(cd "$WORK" && ditto -c -k --keepParent Payload "$OUT")
echo "$OUT"
