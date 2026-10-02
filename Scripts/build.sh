#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${ARCH:-arm64}"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || { echo 'ARCH must be arm64 or x86_64' >&2; exit 1; }
VERSION=$(cat VERSION)
mkdir -p build/generated build/products
printf 'enum BuildVersion { static let value = "%s" }\n' "$VERSION" > build/generated/BuildVersion.swift
SDK=$(xcrun --sdk macosx --show-sdk-path)
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find Shared Savers -name '*.swift' ! -name '*View.swift' | sort)
SOURCES+=(Shared/SaverCore/SceneSaverView.swift build/generated/BuildVersion.swift)
FLAGS=(-sdk "$SDK" -target "$ARCH-apple-macos14.6" -swift-version 5 -O -whole-module-optimization -framework AppKit -framework ScreenSaver -framework CoreImage)
plist() {
    local path="$1" name="$2" identifier="$3" executable="$4" principal="$5" type="$6"
    cat > "$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundleDisplayName</key><string>$name</string>
<key>CFBundleIdentifier</key><string>$identifier</string>
<key>CFBundleExecutable</key><string>$executable</string>
<key>CFBundlePackageType</key><string>$type</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.6</string>
<key>NSPrincipalClass</key><string>$principal</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>MIT · Screensavers for Mac contributors</string>
</dict></plist>
PLIST
}
for kind in WorldClockRoom CityDrift; do
    if [[ "$kind" == WorldClockRoom ]]; then name='World Clock Room'; id=worldclockroom; else name='City Drift'; id=citydrift; fi
    bundle="build/products/$name.saver"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
    # Swift emits one relocatable object; the final link explicitly produces MH_BUNDLE.
    xcrun swiftc "${FLAGS[@]}" -module-name "$kind" -parse-as-library -emit-object "${SOURCES[@]}" "Savers/$kind/${kind}View.swift" -o "build/$kind.o"
    xcrun swiftc "${FLAGS[@]}" -Xlinker -bundle "build/$kind.o" -o "$bundle/Contents/MacOS/$kind"
    plist "$bundle/Contents/Info.plist" "$name" "com.someoneintexas.screensavers.$id" "$kind" "${kind}View" BNDL
    if [[ "$kind" == WorldClockRoom ]]; then image=world-clock-room; else image=city-drift; fi
    xcrun swift Scripts/make-thumbnails.swift "docs/images/$image.png" "$bundle/Contents/Resources"
    if [[ "$kind" == CityDrift ]]; then ditto Assets/StarterMaps "$bundle/Contents/Resources/StarterMaps"; fi
    codesign --force --sign - "$bundle"
done
app=build/products/PreviewHost.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
ditto Assets/StarterMaps "$app/Contents/Resources/StarterMaps"
xcrun swiftc "${FLAGS[@]}" -module-name PreviewHost "${SOURCES[@]}" PreviewHost/main.swift -o "$app/Contents/MacOS/PreviewHost"
plist "$app/Contents/Info.plist" PreviewHost com.someoneintexas.screensavers.preview PreviewHost NSApplication APPL
codesign --force --sign - "$app"
echo "Built both savers and PreviewHost ($ARCH, macOS 14.6+)."
