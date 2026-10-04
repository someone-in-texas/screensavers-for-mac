#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/generated
version_source=$(printf 'enum BuildVersion { static let value = "%s" }' "$(cat VERSION)")
if [[ ! -f build/generated/HelperBuildVersion.swift || "$(cat build/generated/HelperBuildVersion.swift)" != "$version_source" ]]; then
    printf '%s\n' "$version_source" > build/generated/HelperBuildVersion.swift
fi
xcrun swiftc -swift-version 5 AIHelper/CodexConnection.swift AIHelper/HelperSession.swift build/generated/HelperBuildVersion.swift Tests/AIHelper/main.swift -o build/ai-helper-tests
build/ai-helper-tests "$@"
