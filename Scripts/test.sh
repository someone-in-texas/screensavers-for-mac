#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f build/generated/BuildVersion.swift ]] || Scripts/build.sh
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find Shared Savers -name '*.swift' ! -name '*View.swift' | sort)
xcrun swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macos14.6" -swift-version 5 -O -framework AppKit -framework ScreenSaver -framework CoreImage "${SOURCES[@]}" build/generated/BuildVersion.swift Tests/VectorTests.swift Tests/CosmosTests.swift Tests/PaperSkyTests.swift Tests/DappleTests.swift Tests/FlourishTests.swift Tests/LatticeTests.swift Tests/ContemplativeTests.swift Tests/main.swift -o build/tests
build/tests
build/products/PreviewHost.app/Contents/MacOS/PreviewHost --smoke
build/products/PreviewHost.app/Contents/MacOS/PreviewHost --launch-smoke
build/products/PreviewHost.app/Contents/MacOS/PreviewHost --launch-smoke --force-preview-timer
