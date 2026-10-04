#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${ARCH:-arm64}"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || exit 1
mkdir -p build/generated
version_source=$(printf 'enum BuildVersion { static let value = "%s" }' "$(cat VERSION)")
if [[ ! -f build/generated/HelperBuildVersion.swift || "$(cat build/generated/HelperBuildVersion.swift)" != "$version_source" ]]; then
    printf '%s\n' "$version_source" > build/generated/HelperBuildVersion.swift
fi
app='build/products/Screensavers AI Helper.app'
mkdir -p "$app/Contents/MacOS"
xcrun swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$ARCH-apple-macos14.6" -swift-version 5 -O -framework AppKit AIHelper/*.swift build/generated/HelperBuildVersion.swift -o "$app/Contents/MacOS/ScreensaversAIHelper"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Screensavers AI Helper</string>
<key>CFBundleIdentifier</key><string>com.someoneintexas.screensavers.aihelper</string>
<key>CFBundleExecutable</key><string>ScreensaversAIHelper</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$(cat VERSION)</string>
<key>CFBundleVersion</key><string>$(cat VERSION)</string>
<key>LSMinimumSystemVersion</key><string>14.6</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "Built optional AI helper ($ARCH)."
