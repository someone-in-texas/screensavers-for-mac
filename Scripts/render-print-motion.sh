#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/generated
printf 'enum BuildVersion { static let value = "%s" }\n' "$(cat VERSION)" > build/generated/BuildVersion.swift
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find Shared Savers -name '*.swift' ! -name '*View.swift' | sort)
xcrun swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macos14.6" -swift-version 5 -O -framework AppKit -framework ScreenSaver -framework CoreImage -framework AVFoundation "${SOURCES[@]}" build/generated/BuildVersion.swift Scripts/PrintMotionCapture/main.swift -o build/print-motion-capture
build/print-motion-capture "$@"
