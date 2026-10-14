#!/bin/bash
# Build with build-art-review.sh. Does not build or launch PreviewHost.app.
set -euo pipefail
cd "$(dirname "$0")/.."
render=build/art-motion-review/Render
out="${1:-build/art-motion-review/round1}"
mkdir -p "$out"
"$render" --bloom-gallery --filter oak --years 3.35,3.599,3.603,3.607,3.611,3.86 --output "$out/bloom" > "$out/bloom.log"
"$render" --bloom-gallery --filter oak --years 3.35 --zoom 3 --output "$out/bloom-detail" > "$out/bloom-detail.log"
"$render" --bloom-gallery --filter lavender --years 3.35 --output "$out/bloom-flowers" > "$out/bloom-flowers.log"
"$render" --commonplace-gallery --filter sepia --years 0.2,0.6,0.99,1.0,1.025,1.05,1.08,2.2 --output "$out/commonplace" > "$out/commonplace.log"
"$render" --commonplace-gallery --filter naturalist --years 0.2,1.2 --output "$out/naturalist" > "$out/naturalist.log"
"$render" --commonplace-gallery --filter observatory --years 0.2,1.2 --output "$out/observatory" > "$out/observatory.log"
# Wider time separation, density, and aspect-ratio checks for the final art round.
if [[ "${2:-}" == --extended ]]; then
    "$render" --bloom-gallery --filter oak --years 3.60,3.65,3.70,3.86 --output "$out/bloom-weather-drift" > "$out/bloom-weather-drift.log"
    "$render" --bloom-gallery --filter oak --years 3.6,3.86 --width 3440 --height 1440 --output "$out/bloom-wide" > "$out/bloom-wide.log"
    "$render" --bloom-gallery --filter lavender --years 3.35,3.86 --width 800 --height 1200 --output "$out/bloom-portrait" > "$out/bloom-portrait.log"
    "$render" --commonplace-gallery --dense --pages 5 --filter sepia --output "$out/commonplace-dense" > "$out/commonplace-dense.log"
    "$render" --commonplace-gallery --dense --filter sepia --years 0.2,1.08,2.2 --width 800 --height 1200 --output "$out/commonplace-portrait" > "$out/commonplace-portrait.log"
    "$render" --commonplace-gallery --filter workshop --years 0.2,1.08 --width 3440 --height 1440 --output "$out/commonplace-wide" > "$out/commonplace-wide.log"
    "$render" --commonplace-gallery --filter offWorld --years 0.2,1.08 --output "$out/offWorld" > "$out/offWorld.log"
    "$render" --commonplace-gallery --filter atomic --years 0.2,1.08 --output "$out/atomic" > "$out/atomic.log"
    "$render" --commonplace-gallery --filter sepia --years 0.2 --width 280 --height 180 --output "$out/commonplace-small" > "$out/commonplace-small.log"
fi
