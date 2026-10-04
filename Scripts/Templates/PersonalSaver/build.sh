#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ARCH="${ARCH:-$(uname -m)}"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || exit 1
FLAGS=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$ARCH-apple-macos14.6" -swift-version 5 -O -framework AppKit -framework ScreenSaver)
bundle='build/__TITLE__.saver'
app='build/Preview.app'
mkdir -p "$bundle/Contents/MacOS" "$app/Contents/MacOS"
xcrun swiftc "${FLAGS[@]}" -module-name __CLASS__ -whole-module-optimization -parse-as-library -emit-object Scene.swift View.swift -o build/saver.o
xcrun swiftc "${FLAGS[@]}" -Xlinker -bundle build/saver.o -o "$bundle/Contents/MacOS/__CLASS__"
cp Saver.plist "$bundle/Contents/Info.plist"
xcrun swiftc "${FLAGS[@]}" Scene.swift main.swift -o "$app/Contents/MacOS/Preview"
cp Preview.plist "$app/Contents/Info.plist"
codesign --force --sign - "$bundle"
codesign --force --sign - "$app"
echo 'Built build/__TITLE__.saver and build/Preview.app'
