#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# CodeQL can launch build commands through Rosetta, so uname may report x86_64
# on the arm64 runner. The explicit Swift target below selects the shipped code.
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
