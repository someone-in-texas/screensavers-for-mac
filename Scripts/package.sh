#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
ARCH="${ARCH:-arm64}"
[[ "${SKIP_BUILD:-0}" == 1 ]] || Scripts/build.sh
mkdir -p dist
stage=$(mktemp -d "${TMPDIR:-/tmp}/screensavers-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
for name in 'World Clock Room' 'City Drift' 'Voxel Cosmos' 'Paper Sky'; do
    ditto "build/products/$name.saver" "$stage/$name.saver"
    if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
        codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$stage/$name.saver"
    else
        codesign --force --sign - "$stage/$name.saver"
    fi
    codesign --verify --strict --verbose=2 "$stage/$name.saver"
done
cat > "$stage/Install.txt" <<'NOTE'
Screensavers for Mac
Apple Silicon · macOS 14.6 or later

Double-click each .saver and choose installation for this user.
Then open System Settings > Wallpaper > Screen Saver (or Screen Saver on older macOS).
Under Other > Show All, select a saver and use Options / Screen Saver Options to configure it.

If an ad-hoc build is blocked, use System Settings > Privacy & Security > Open Anyway
for the specific downloaded saver after checking its source and SHA-256 checksum.
Never disable Gatekeeper globally.

Source, troubleshooting, signing status and license:
https://github.com/someone-in-texas/screensavers-for-mac

City Drift displays © OpenStreetMap contributors. Map data: ODbL.
https://www.openstreetmap.org/copyright
NOTE
base="ScreensaversForMac-v$VERSION-$ARCH"
rm -f "dist/$base.dmg" "dist/$base.zip"
hdiutil create -quiet -volname 'Screensavers for Mac' -srcfolder "$stage" -format UDZO "dist/$base.dmg"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "dist/$base.dmg"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "dist/$base.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    elif [[ -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" && -n "${NOTARY_KEY_P8:-}" ]]; then
        printf '%s' "$NOTARY_KEY_P8" > "$stage/notary.p8"
        chmod 600 "$stage/notary.p8"
        xcrun notarytool submit "dist/$base.dmg" --key "$stage/notary.p8" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" --wait
        rm "$stage/notary.p8"
    else
        echo 'Developer ID selected but notarization credentials are incomplete.' >&2; exit 1
    fi
    xcrun stapler staple "dist/$base.dmg"
    xcrun stapler validate "dist/$base.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "dist/$base.dmg"
    echo 'Developer ID signed; DMG notarized and stapled.' > dist/SIGNING.txt
else
    echo 'Ad-hoc signed; not notarized. Gatekeeper approval may be required.' > dist/SIGNING.txt
fi
# Explicit paths keep ZIP contents at the root and omit staging-only files.
(cd "$stage" && /usr/bin/zip -q -r "$OLDPWD/dist/$base.zip" 'World Clock Room.saver' 'City Drift.saver' 'Voxel Cosmos.saver' 'Paper Sky.saver' Install.txt)
(cd dist && shasum -a 256 "$base.dmg" "$base.zip" > SHA256SUMS)
echo "Packaged dist/$base.{dmg,zip} and dist/SHA256SUMS"
