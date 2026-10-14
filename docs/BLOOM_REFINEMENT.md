# Bloom drawing and atmosphere refinement

This follow-up builds on [Botanical Watercolor](BLOOM_WATERCOLOR.md). It changes
Years in Bloom only; Flourish was read as a reference and remains unchanged.

## Preview shortcuts

```sh
Scripts/build-preview.sh
Scripts/run-preview.sh --bloom-review --offline
```

The build shortcut compiles and ad-hoc signs only `build/products/PreviewHost.app`,
including its normal resource bundles, with the macOS 14.6 deployment target.
It defaults to the host architecture; `ARCH=arm64` or `ARCH=x86_64` overrides it.
The run shortcut launches a fresh instance and forwards arguments. It builds if
the executable is missing; rebuild explicitly after source changes. Both scripts
work from outside the checkout. Neither installs a saver. The existing `make
preview` continues to perform the full collection build.

For a mature rainy meadow, in isolated review preferences:

```sh
Scripts/run-preview.sh --bloom-review --offline --filter oak --layout meadow \
  --weather dramatic --review-age 234
```

## Rendering changes

- `BloomDrawing.swift` makes filled, pressure-modulated branch envelopes around
  the existing centerline. Trunks meet at shared widths and bisected join normals;
  a small overlap prevents antialias seams. Growing tips taper progressively.
  Two incomplete bark/pencil traces follow the envelope. This adapts the idea of
  filled stems and pressure variation from this repository's Flourish renderer.
- The same file supplies seeded, unequal plant spacing, height, scale and depth
  for grouping, meadow and woodland. Specimen placement and Classic remain as
  before. Perennial placement remains fixed across annual renewal.
- `BloomIllustration.swift` adds a few anatomy-directed brush pulls with variable
  width, curved paths and faded ends. Short bristle reserves and interrupted,
  curved veins avoid long parallel highlight ribbons. All marks remain baked
  into bounded, deterministic organ images.
- `BloomAtmosphere.swift` uses a very faint page wash, a stronger moving halo
  behind the plants, warm sunlight, short wind gestures, and two precipitation
  depths. Rain and snow use separate stable populations with continuous seasonal
  opacity. Small snow flecks and selected branch-top deposits replace uniformly
  white-traced branches. Colors blend continuously, including year-end renewal.
- `YearsInBloomScene.swift` integrates these layers while preserving its calendar,
  attachment geometry, growth timing, fall, sway, lifecycle and preference keys.
  Mature branch paths are reused whenever width/growth/drying are unchanged.
- `PreviewHost/main.swift` accepts `--weather` in the Bloom gallery and native
  review. No new configuration controls or third-party dependencies were added.

Keep the artistic controls at **35% edge / 65% pigment / 30% grain / 25% wet edge**.
Use **Natural** weather by default. Dramatic remains a useful review comparison;
the extra effects also respect Calm. Classic retains its original rendering.

## Art-critic iterations

An `art_critic` subagent inspected actual renderer images in successive rounds.

1. **Baseline:** uniform rods and cap joins, five evenly spaced bouquet roots,
   pale straight veins and cutout-like foliage. The critic recommended Flourish's
   filled-taper principle, clustered spacing and directional brush marks.
2. **First revision:** tapered branches and clustered meadow improved hierarchy.
   The critic found visible joint seams, wind arcs resembling ruled paper,
   insufficient snow contrast, and mechanically parallel pale brush ribbons.
3. **Second revision:** shared joins, shorter staggered wind gestures, a cooler
   winter halo, softer variable-length brush pulls and selective branch snow
   improved the result. The critic rated line, composition, brushwork and weather
   4/5, restraint 5/5, and recommended restraint rather than further intensity.
4. **Final polish:** overlap the tiny trunk hairlines, round the snow into sparse
   flecks, and smoothly retire the autumn tint at year-end. Final review and
   validation results are recorded below.

Remaining artistic limits: crowns still inherit procedural branching patterns,
and lavender's stems retain a regular fan at their base. Further improvement
should come from species-specific anatomy, not stronger noise or darker pigment.

## Reproduce the review

```sh
Scripts/build-preview.sh
Scripts/render-bloom-refinement.sh
swift Scripts/bloom-contact-sheet.swift build/bloom-art/refinement --refinement
```

The contact sheet expects `before/`, `round1/` and `final/` in the refinement
folder. These local captures are retained from the review; a fresh checkout can
regenerate the current `final/` using the first two commands. `BLOOM_PREVIEW`
selects a preserved older executable for matching baseline captures. Generated
PNG files and reports remain under ignored `build/bloom-art/refinement/`.

## Final visual review

The critic inspected the final 3× detail, meadow, woodland, winter weather,
Moonlit palette, 280-pixel preview, and ten sampled motion frames. No blocking
visual regression was found. The final trunk seams no longer draw attention;
short rounded snow flecks were preferred over diagonal ticks.

| Criterion | Score | Evidence from inspected images |
| --- | ---: | --- |
| Authenticity | 3/5 | More drawn and warmer; repeated leaves and herb fans still reveal procedural construction. |
| Line quality | 4/5 | Connected taper, fine twig tips, and controlled broken accents. |
| Pigment | 4/5 | Directional marks and translucent overlap are visible without dominating. |
| Botanical plausibility | 4/5 | Species silhouettes and branch hierarchy remain legible. |
| Composition | 4/5 | Unequal heights, depth and selective overlap, especially in woodland. |
| Restraint | 5/5 | Weather supports the plants and leaves quiet negative space. |
| Scale | 4/5 | Small previews retain hierarchy; close-ups reward inspection. |
| Temporal consistency | 4/5, provisional | Coherent marks and progressive litter fading in sampled frames; no apparent year-boundary discontinuity. |

Temporal scores describe sampled renderer output, not continuous physical-display
inspection. The final QA also bounds rain's gust displacement so its apparent
velocity cannot grow with the total playback duration.

## Performance design and validation

The refinement adds 13 small layer objects (including three gradient masks),
100 rain strokes, 64 snow flecks and four wind gestures. No per-frame bitmap,
blur, simulation, network request or additional image cache is introduced.
Branch envelopes use 24 samples and are reused when their growth, thickness and
drying state are unchanged. Brush pulls are painted once into existing organ
rasters. The separate active-painting and LRU limits remain 24 MiB each.

- Full `make build` passed for eleven savers, PreviewHost and the helper.
- Offline logic tests passed **2,575,622 checks with zero failures**. Added
  checks cover deterministic clustered placement, bounded scale/spacing, tapered
  growth fronts, subtle corner weather versus stronger central weather, fixed-time
  atmosphere identity and bounded rain gust motion after long simulated uptime.
  Existing tests continue to cover cache limits, pause/resume, annual/cohort
  renewal, visible-organ readiness and resized artwork retention.
- The preview build shortcut produced a signed, valid app; the launch shortcut
  opened and captured a native Bloom preview using isolated review preferences.
- Classic's mature seed-42 oak PNG still matches the preceding original capture
  byte for byte. Flourish has no source changes.
- Shell syntax and `git diff --check` passed. The twenty offline installer tests
  and README/release instruction consistency check passed.
- `Scripts/test.sh` completed successfully: all eleven actual bundles rendered at
  five aspect ratios, both sets of 66 native configuration open/Done/reopen cycles
  passed (normal and fallback timer), 440 helper checks passed, and the standalone
  scaffold build/smoke passed. Nothing was installed or published.

The final gallery retained 14.83 MiB of organ paintings for a 3440×1440 woodland
and 15.98 MiB for a 2× oak. Their CPU-update p95 values were 9.09 ms and 6.11 ms,
respectively; maxima were 32.18 ms and 19.88 ms including preparation. These
accelerated gallery runs overlapped validation work and are not isolated display
performance benchmarks.

A quiet, sequential native comparison then ran the preceding Watercolor build and
this refinement for 15 seconds each, from mature oak age 3.35, seed 42, the same
1200×742 logical viewport at 2× backing density, with compilation/tests finished:

| Native CPU layer-update timing | Before refinement | Final |
| --- | ---: | ---: |
| Preview callbacks | 468 | 467 |
| p50 | 4.43 ms | 5.75 ms |
| p95 | 5.52 ms | 6.59 ms |
| Maximum | 8.39 ms | 8.08 ms |

The added brush envelopes, washes and particle layers cost about 1.1 ms at p95 in
this sample, comfortably inside the 33.3 ms update interval. This measures CPU
layer updates on one Apple M5/macOS 27.0.1 machine, not GPU frame time, scanout,
energy, every supported OS/hardware combination or a physical multi-hour soak.
The initial 14.6 deployment target is retained but that OS was not exercised.
Native execution and sampled-frame review do not establish continuous visual
flicker quality on a physical display. The critic rechecked the four regenerated
rain frames after the bounded-drift correction and found no visual regression.

Logs and PNGs are under `build/bloom-art/refinement/`; `index.html` presents
matched before/after pairs and `comparison.png` includes the first revision.
