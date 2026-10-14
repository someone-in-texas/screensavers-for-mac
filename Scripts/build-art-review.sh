#!/bin/bash
# Isolated renderer for art-direction iterations. Does not touch PreviewHost.app.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/art-motion-review
printf 'enum BuildVersion { static let value = "%s" }\n' "$(cat VERSION)" > build/art-motion-review/BuildVersion.swift
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find Shared Savers -name '*.swift' ! -name '*View.swift' | sort)
xcrun swiftc -O -whole-module-optimization -swift-version 5 -target "$(uname -m)-apple-macos14.6" -framework AppKit -framework ScreenSaver -framework CoreImage "${sources[@]}" Shared/SaverCore/SceneSaverView.swift build/art-motion-review/BuildVersion.swift PreviewHost/main.swift -o build/art-motion-review/Render
