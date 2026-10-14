#!/bin/bash
# Offline, repeatable art-critic samples, including wider seasonal atmosphere.
set -euo pipefail
cd "$(dirname "$0")/.."
preview="${BLOOM_PREVIEW:-build/products/PreviewHost.app/Contents/MacOS/PreviewHost}"
out="${1:-build/bloom-art/refinement/final}"
mkdir -p "$out"
"$preview" --bloom-gallery --filter oak --years 0.2,3.35,3.6,3.86 --output "$out/oak" > "$out/oak.log"
"$preview" --bloom-gallery --filter oak --years 3.35 --zoom 3 --output "$out/detail" > "$out/detail.log"
"$preview" --bloom-gallery --filter oak --layout meadow --years 3.38,3.6,3.86 --output "$out/meadow" > "$out/meadow.log"
"$preview" --bloom-gallery --filter oak --layout woodland --years 3.35 --output "$out/woodland" > "$out/woodland.log"
"$preview" --bloom-gallery --filter lavender --years 3.35 --output "$out/lavender" > "$out/lavender.log"
"$preview" --bloom-gallery --filter oak --weather dramatic --years 3.6,3.86 --output "$out/weather" > "$out/weather.log"
echo "Art-critic captures: $out"
