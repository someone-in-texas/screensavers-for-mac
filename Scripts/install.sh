#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
Scripts/build.sh
location="$HOME/Library/Screen Savers"
mkdir -p "$location"
for name in 'World Clock Room' 'City Drift' 'Voxel Cosmos' 'Paper Sky' 'Dapple'; do
    target="$location/$name.saver"
    if [[ -e "$target" ]]; then
        old_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")
        new_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "build/products/$name.saver/Contents/Info.plist")
        [[ "$old_id" == "$new_id" ]] || { echo "Refusing to replace unrelated bundle: $target" >&2; exit 1; }
        rm -rf "$target"
    fi
    ditto "build/products/$name.saver" "$target"
done
echo 'Installed for this user. Open System Settings > Wallpaper > Screen Saver (or Screen Saver on older macOS).'
echo 'Select a saver, then Options / Screen Saver Options. Quit and reopen Settings after development updates.'
