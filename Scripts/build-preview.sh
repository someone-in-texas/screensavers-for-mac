#!/bin/bash
# Fast local art iteration. The canonical build and release checks remain optimized.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/generated
printf 'enum BuildVersion { static let value = "%s" }\n' "$(cat VERSION)" > build/generated/BuildVersion.swift
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find Shared Savers -name '*.swift' ! -name '*View.swift' | sort)
xcrun swiftc -Onone -whole-module-optimization -swift-version 5 -framework AppKit -framework ScreenSaver -framework CoreImage "${sources[@]}" Shared/SaverCore/SceneSaverView.swift build/generated/BuildVersion.swift PreviewHost/main.swift -o build/preview-09
