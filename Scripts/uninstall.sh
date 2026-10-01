#!/bin/bash
set -euo pipefail
for name in 'World Clock Room' 'City Drift'; do
    target="$HOME/Library/Screen Savers/$name.saver"
    [[ -d "$target" ]] || continue
    id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")
    case "$id" in
        com.someoneintexas.screensavers.worldclockroom|com.someoneintexas.screensavers.citydrift) rm -rf "$target" ;;
        *) echo "Refusing to remove unrelated bundle: $target" >&2; exit 1 ;;
    esac
done
echo 'Removed both savers. Preferences and the tile cache are retained.'
