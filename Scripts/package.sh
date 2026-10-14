#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
ARCH="${ARCH:-arm64}"
[[ "${SKIP_BUILD:-0}" == 1 ]] || Scripts/build.sh
mkdir -p dist
stage=$(mktemp -d "${TMPDIR:-/tmp}/screensavers-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
for name in 'World Clock Room' 'City Drift' 'Voxel Cosmos' 'Paper Sky' 'Dapple' 'Flourish' 'Lattice' 'Strawberry Fields Forever' 'Good Research Takes Time' 'Years in Bloom'; do
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

These ten screen savers work without AI. Commonplace and Screensavers AI Helper
are distributed in the separate AI pack. No account is needed for this pack.

Source, troubleshooting, signing status and license:
https://github.com/someone-in-texas/screensavers-for-mac

City Drift displays © OpenStreetMap contributors. Map data: ODbL.
https://www.openstreetmap.org/copyright
NOTE
package_stage() {
    local stage=$1 base=$2 volume=$3
rm -f "dist/$base.dmg" "dist/$base.zip"
hdiutil create -quiet -volname "$volume" -srcfolder "$stage" -format UDZO "dist/$base.dmg"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "dist/$base.dmg"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "dist/$base.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    elif [[ -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" && -n "${NOTARY_KEY_P8:-}" ]]; then
        (umask 077; printf '%s' "$NOTARY_KEY_P8" > "$stage/notary.p8")
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
# The public curl installers remain outside the downloaded archives.
    (cd "$stage" && /usr/bin/zip -q -r "$OLDPWD/dist/$base.zip" .)
}
cp LICENSE THIRD_PARTY_NOTICES.md "$stage/"
package_stage "$stage" "ScreensaversForMac-v$VERSION-$ARCH" 'Screensavers for Mac'
# Reuse the private stage only after the standard archives are complete.
find "$stage" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
for item in 'Commonplace.saver' 'Screensavers AI Helper.app'; do
    ditto "build/products/$item" "$stage/$item"
    if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
        codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$stage/$item"
    else
        codesign --force --sign - "$stage/$item"
    fi
    codesign --verify --strict "$stage/$item"
done
cp docs/AI_HELPER.md "$stage/AI_HELPER.md"
cp LICENSE THIRD_PARTY_NOTICES.md "$stage/"
cp Assets/Commonplace/README.md "$stage/ARCHIVAL_SOURCES.md"
cat > "$stage/Install.txt" <<'NOTE'
Screensavers for Mac — AI Pack
Apple Silicon · macOS 14.6 or later

Install Commonplace.saver for this user and copy Screensavers AI Helper.app to
~/Applications. The recommended separate curl installer handles both locations.
Open Commonplace Options > Set Up ChatGPT to connect the optional local helper.
Commonplace plays its starter notebook and saved content offline without login.
Generation uses local Codex and your ChatGPT account limits. See AI_HELPER.md.
No helper is launched and no account is connected by the installer.

Source, current installation instructions, signatures and licenses:
https://github.com/someone-in-texas/screensavers-for-mac

If an ad-hoc build is blocked, approve the specific downloaded item through
System Settings > Privacy & Security after verifying its source and checksum.
The installer does not change Gatekeeper or quarantine settings.
NOTE
package_stage "$stage" "ScreensaversForMac-AI-v$VERSION-$ARCH" 'Screensavers for Mac AI'
(cd dist && shasum -a 256 "ScreensaversForMac-v$VERSION-$ARCH.dmg" "ScreensaversForMac-v$VERSION-$ARCH.zip" "ScreensaversForMac-AI-v$VERSION-$ARCH.dmg" "ScreensaversForMac-AI-v$VERSION-$ARCH.zip" > SHA256SUMS)
echo "Packaged standard and AI packs for v$VERSION ($ARCH), with dist/SHA256SUMS"
