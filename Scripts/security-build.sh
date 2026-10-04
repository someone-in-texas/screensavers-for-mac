#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -m)" == arm64 ]] || { echo 'Security analysis requires Apple Silicon.' >&2; exit 1; }
mkdir -p build/security/native build/generated
printf 'enum BuildVersion { static let value = "%s" }\n' "$(cat VERSION)" > build/generated/BuildVersion.swift
SDK=$(xcrun --sdk macosx --show-sdk-path)
SOURCES=()
# Include every saver entry point, not just the scene files used by PreviewHost.
# The production build compiles this shared code separately for all nine bundles;
# CodeQL only needs one compilation of each source to analyze it.
while IFS= read -r file; do SOURCES+=("$file"); done < <(find Shared Savers -name '*.swift' | sort)
FLAGS=(-sdk "$SDK" -target arm64-apple-macos14.6 -swift-version 5 -O -whole-module-optimization -framework AppKit -framework ScreenSaver -framework CoreImage)
xcrun swiftc "${FLAGS[@]}" -module-name SecurityAnalysis "${SOURCES[@]}" \
    build/generated/BuildVersion.swift PreviewHost/main.swift -o build/security/native/PreviewHost
xcrun swiftc "${FLAGS[@]}" Scripts/make-thumbnails.swift -o build/security/native/MakeThumbnails
Scripts/build-ai-helper.sh
echo 'Compiled every saver entry point, shared scene, PreviewHost, thumbnail tool and AI helper for analysis.'
