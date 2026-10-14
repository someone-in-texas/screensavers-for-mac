#!/bin/bash
# Deterministic offline A/B/C captures. Run make build first. No user defaults.
set -euo pipefail
cd "$(dirname "$0")/.."
preview="${BLOOM_PREVIEW:-build/products/PreviewHost.app/Contents/MacOS/PreviewHost}"
out="${1:-build/bloom-art/final}"
mkdir -p "$out"
for style in classic organic botanicalWatercolor; do
    "$preview" --bloom-gallery --rendering "$style" --filter oak --years 0.2,3.35,3.6,3.86 --output "$out/$style/oak" > "$out/$style-oak.log"
    "$preview" --bloom-gallery --rendering "$style" --filter lavender --years 3.35 --output "$out/$style/lavender" > "$out/$style-lavender.log"
    "$preview" --bloom-gallery --rendering "$style" --filter sunflower --years 0.38 --output "$out/$style/sunflower" > "$out/$style-sunflower.log"
    "$preview" --bloom-gallery --rendering "$style" --filter maple --years 3.35,3.6,3.66 --output "$out/$style/maple" > "$out/$style-maple.log"
    "$preview" --bloom-gallery --rendering "$style" --filter oak --layout meadow --years 3.38 --output "$out/$style/meadow" > "$out/$style-meadow.log"
    "$preview" --bloom-gallery --rendering "$style" --filter oak --years 3.35 --zoom 3 --output "$out/$style/detail" > "$out/$style-detail.log"
done
# Temporal samples include spring growth, annual restart, autumn, and cohort handoff.
"$preview" --bloom-gallery --filter oak --layout grouping --years 0.08,0.09,0.1,0.11,0.12,0.99,1.0,1.01,1.02,1.03,3.59,3.60,3.61,4.96,5.0,5.02,5.04,5.08 --output "$out/motion" > "$out/motion.log"
"$preview" --bloom-gallery --filter oak --years 3.35 --backing-scale 2 --output "$out/retina" > "$out/retina.log"
"$preview" --bloom-gallery --filter lavender --years 3.35 --width 800 --height 1200 --output "$out/portrait" > "$out/portrait.log"
"$preview" --bloom-gallery --filter oak --layout woodland --years 3.35 --width 3440 --height 1440 --output "$out/ultrawide" > "$out/ultrawide.log"
"$preview" --bloom-gallery --filter oak --layout meadow --years 3.35 --width 280 --height 180 --output "$out/small" > "$out/small.log"
echo "Bloom art-review captures: $out"
