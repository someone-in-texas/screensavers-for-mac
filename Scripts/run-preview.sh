#!/bin/bash
# Launch the existing build, forwarding PreviewHost flags. Build once if missing.
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/build/products/PreviewHost.app"
[[ -x "$app/Contents/MacOS/PreviewHost" ]] || Scripts/build-preview.sh
# A new instance ensures supplied review flags are honored by Launch Services.
exec open -n "$app" --args "$@"
