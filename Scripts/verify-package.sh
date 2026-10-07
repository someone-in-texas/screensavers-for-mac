#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
ARCH="${ARCH:-arm64}"
work=$(mktemp -d "${TMPDIR:-/tmp}/screensavers-verify.XXXXXX")
mounted=0
cleanup() {
    if [[ "$mounted" == 1 ]]; then hdiutil detach -quiet "$work/mount" || true; fi
    rm -rf "$work"
}
trap cleanup EXIT
(cd dist && shasum -a 256 -c SHA256SUMS)
for pack in standard ai; do
    if [[ "$pack" == standard ]]; then
        base="ScreensaversForMac-v$VERSION-$ARCH"
        names=('World Clock Room.saver' 'City Drift.saver' 'Voxel Cosmos.saver' 'Paper Sky.saver' 'Dapple.saver' 'Flourish.saver' 'Lattice.saver' 'Strawberry Fields Forever.saver' 'Good Research Takes Time.saver' 'Years in Bloom.saver')
    else
        base="ScreensaversForMac-AI-v$VERSION-$ARCH"
        names=('Commonplace.saver' 'Screensavers AI Helper.app')
    fi
    /usr/bin/ditto -x -k "dist/$base.zip" "$work/$pack"
    hdiutil attach -quiet -readonly -nobrowse -mountpoint "$work/mount" "dist/$base.dmg"
    mounted=1
    for location in "$work/$pack" "$work/mount"; do
        [[ ! -e "$location/install.sh" && ! -e "$location/install-ai.sh" && ! -e "$location/Install.sh" ]]
        [[ -s "$location/LICENSE" && -s "$location/THIRD_PARTY_NOTICES.md" ]]
        ids=()
        for name in "${names[@]}"; do
            bundle="$location/$name"
            [[ -d "$bundle" ]]
            plist="$bundle/Contents/Info.plist"
            plutil -lint "$plist"
            id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist");ids+=("$id")
            expected=${name%.saver};expected=${expected// /};expected=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
            [[ "$name" != 'Screensavers AI Helper.app' ]] || expected=aihelper
            [[ "$id" == "com.someoneintexas.screensavers.$expected" ]]
            exe=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$plist")
            [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")" == "$VERSION" ]]
            [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")" == "$VERSION" ]]
            lipo "$bundle/Contents/MacOS/$exe" -verify_arch "$ARCH"
            codesign --verify --strict "$bundle"
            if [[ "$name" == *.saver ]]; then
                for image in thumbnail.png thumbnail@2x.png thumbnail.tiff; do [[ -s "$bundle/Contents/Resources/$image" ]]; done
                otool -hv "$bundle/Contents/MacOS/$exe" | grep -q BUNDLE
            fi
            if [[ "$name" == 'City Drift.saver' ]]; then
                for resource in streets.json ODbL-1.0.txt README.md; do [[ -s "$bundle/Contents/Resources/StarterMaps/$resource" ]]; done
            fi
            if [[ "$name" == 'Commonplace.saver' ]]; then [[ -s "$bundle/Contents/Resources/Commonplace/catalog.json" ]]; fi
        done
        [[ "$(printf '%s\n' "${ids[@]}" | sort -u | wc -l | tr -d ' ')" == "${#names[@]}" ]]
        if [[ "$pack" == standard ]]; then
            [[ ! -e "$location/Commonplace.saver" && ! -e "$location/Optional" && ! -e "$location/Screensavers AI Helper.app" ]]
        else
            [[ -s "$location/AI_HELPER.md" && ! -e "$location/Years in Bloom.saver" ]]
        fi
    done
    hdiutil detach -quiet "$work/mount";mounted=0
    if [[ "$ARCH" == arm64 ]]; then
        installer=./install.sh;[[ "$pack" == standard ]] || installer=./install-ai.sh
        bash -c '
            source "$1"
            work=$2
            verify_archive "$3" dist/SHA256SUMS "${3##*/}"
            validate_bundles "$4" "$5"
        ' verify-installer "$installer" "$work" "dist/$base.zip" "$work/$pack" "$VERSION"
    fi
done
echo 'Verified both packs: checksums, DMG/ZIP, identities, versions, architecture, signatures and public installer validation.'
