#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
ARCH="${ARCH:-arm64}"
base="ScreensaversForMac-v$VERSION-$ARCH"
work=$(mktemp -d "${TMPDIR:-/tmp}/screensavers-verify.XXXXXX")
mounted=0
cleanup() {
    if [[ "$mounted" == 1 ]]; then hdiutil detach -quiet "$work/mount" || true; fi
    rm -rf "$work"
}
trap cleanup EXIT
(cd dist && shasum -a 256 -c SHA256SUMS)
/usr/bin/ditto -x -k "dist/$base.zip" "$work/zip"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$work/mount" "dist/$base.dmg"
mounted=1
for location in "$work/zip" "$work/mount"; do
    ids=()
    for name in 'World Clock Room' 'City Drift'; do
        bundle="$location/$name.saver"
        [[ -d "$bundle" ]]
        plutil -lint "$bundle/Contents/Info.plist"
        id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$bundle/Contents/Info.plist")
        ids+=("$id")
        exe=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$bundle/Contents/Info.plist")
        [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$bundle/Contents/Info.plist")" == "$VERSION" ]]
        file "$bundle/Contents/MacOS/$exe"
        lipo -verify_arch "$ARCH" "$bundle/Contents/MacOS/$exe"
        codesign --verify --strict "$bundle"
        otool -hv "$bundle/Contents/MacOS/$exe" | grep -q BUNDLE
    done
    [[ "${ids[0]}" != "${ids[1]}" ]]
done
echo 'Verified checksums, mounted DMG, expanded ZIP, bundle metadata, architecture and signatures.'
