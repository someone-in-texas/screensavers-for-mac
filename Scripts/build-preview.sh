#!/bin/bash
# Build only the native preview app; no saver bundles, helper, or installation.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${ARCH:-$(uname -m)}"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || { echo 'ARCH must be arm64 or x86_64' >&2; exit 1; }
app=build/products/PreviewHost.app
mkdir -p build/generated "$app/Contents/MacOS" "$app/Contents/Resources"
version=$(cat VERSION)
printf 'enum BuildVersion { static let value = "%s" }\n' "$version" > build/generated/BuildVersion.swift
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find Shared Savers -name '*.swift' ! -name '*View.swift' | sort)
xcrun swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$ARCH-apple-macos14.6" -O -whole-module-optimization -swift-version 5 -module-name PreviewHost -framework AppKit -framework ScreenSaver -framework CoreImage "${sources[@]}" Shared/SaverCore/SceneSaverView.swift build/generated/BuildVersion.swift PreviewHost/main.swift -o "$app/Contents/MacOS/PreviewHost"
ditto Assets/StarterMaps "$app/Contents/Resources/StarterMaps"
ditto Assets/Commonplace "$app/Contents/Resources/Commonplace"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>PreviewHost</string>
<key>CFBundleIdentifier</key><string>com.someoneintexas.screensavers.preview</string>
<key>CFBundleExecutable</key><string>PreviewHost</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>14.6</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app ($ARCH). Launch with Scripts/run-preview.sh."
