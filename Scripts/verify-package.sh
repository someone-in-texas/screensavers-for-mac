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
    for name in 'World Clock Room' 'City Drift' 'Voxel Cosmos'; do
        bundle="$location/$name.saver"
        [[ -d "$bundle" ]]
        for image in thumbnail.png thumbnail@2x.png thumbnail.tiff; do
            [[ -s "$bundle/Contents/Resources/$image" ]]
        done
        plutil -lint "$bundle/Contents/Info.plist"
        id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$bundle/Contents/Info.plist")
        ids+=("$id")
        exe=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$bundle/Contents/Info.plist")
        [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$bundle/Contents/Info.plist")" == "$VERSION" ]]
        if [[ "$name" == 'City Drift' ]]; then
            [[ -s "$bundle/Contents/Resources/StarterMaps/streets.json" ]]
            [[ -s "$bundle/Contents/Resources/StarterMaps/ODbL-1.0.txt" ]]
            [[ -s "$bundle/Contents/Resources/StarterMaps/README.md" ]]
        fi
        file "$bundle/Contents/MacOS/$exe"
        lipo "$bundle/Contents/MacOS/$exe" -verify_arch "$ARCH"
        codesign --verify --strict "$bundle"
        otool -hv "$bundle/Contents/MacOS/$exe" | grep -q BUNDLE
    done
    [[ "${ids[0]}" != "${ids[1]}" && "${ids[0]}" != "${ids[2]}" && "${ids[1]}" != "${ids[2]}" ]]
done
echo 'Verified checksums, mounted DMG, expanded ZIP, bundle metadata, architecture and signatures.'
