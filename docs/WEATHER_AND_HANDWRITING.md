# Weather and handwriting refinement

This follow-up makes weather readable across Years in Bloom's whole page and
turns Commonplace into a slowly moving view of a desk. Flourish is unchanged.

## Rendering changes

- `BloomWeatherField.swift` makes two deterministic, low-resolution cloud masks.
  Unequal rotated density lobes move on independent paths, tinting the paper
  cool gray in rain, blue in winter, and warmer in sun. `BloomAtmosphere.swift`
  combines these broad washes with stronger localized atmosphere around plants.
  Mask overscan prevents exposed edges on wide and portrait displays.
- Rain stroke direction comes from the derivative of each drop's actual path
  in viewport coordinates. Its tilt and travel now agree, including gusts and
  different aspect ratios. Distant rain and snow have slightly stronger contrast.
- `BloomIllustration.swift` adds selective broken pencil contours, short offset
  strokes and interrupted pigment pulls. Pale midribs are quieter and broken,
  avoiding the regular white stripes seen in the first review. Marks remain
  seeded in organ coordinates and use the existing bounded painting cache.
- `CommonplaceDesk.swift` caches a tabletop with cropped paper scraps, a pencil,
  paperclip, faint jottings and a partial cup ring. A bounded active-time camera
  moves the whole desk slowly throughout reading. Incoming pages slide relative
  to that desk; the outgoing sheet stays opaque beneath them. Transparent page
  margins expose the persistent desk instead of carrying a moving background.
- `CommonplaceHandwriting.swift` uses process-local Core Text registration of
  bundled Kalam Regular. Tiny deterministic word spacing and line offsets add
  variation without changing letter shapes randomly. Notes, headings and quotes
  use handwriting; tables and source metadata retain readable aligned type.
  Quote fitting and shared note placement keep the writing within its support.

[Kalam's pinned source](https://github.com/google/fonts/tree/6e4b84c976cadb3c49a40fd9a1c203e4f7fcf2da/ofl/kalam)
is bundled unmodified under SIL OFL 1.1. Copyright, license and provenance are in
`Assets/Commonplace/Fonts/`. No system font installation or new runtime is needed.

## Art-direction iterations

All reviews used actual renderer PNGs, including close-ups and sampled motion.
An isolated executable was built for the reviews; PreviewHost.app's binary hash
was preserved until the reviews were finished.

| Round | Years in Bloom | Commonplace |
|---|---|---|
| 1 | Rain travel corrected and weather visible, but cloud bands and pale midribs were too regular. | Handwriting and desk motion worked; transparent outgoing paper produced ghosted desk lines. Desk objects needed definition. |
| 2 | Replaced repeated bands with unequal cloud lobes; strengthened broken contours and reduced midrib regularity. Critic accepted restraint and requested aspect/time checks. | Kept outgoing sheet opaque, revealed pencil/clip, added scrap jottings and handwritten quotations. Critic requested dense/portrait/wide checks. |
| 3 | Extended weather-time, portrait and ultrawide samples checked coverage and continuity. | Fixed object proportions and quote fitting. Portrait review exposed card backing estimated from average column height rather than actual ink placement. |
| 4 | Re-rendered rain and snow with the accepted treatment. | Card backing now follows the actual text flow, including callbacks, without a second height estimate. Rechecked dense pages, portrait handoff, Atomic and Observatory. |

The critic accepted both savers after four sequential post-change rounds each.
Third-round Commonplace was held for the card correction; the fourth-round
images verified the fix before the application was rebuilt.

| Final criterion | Bloom (1–5) | Commonplace (1–5) | Observed basis |
|---|---:|---:|---|
| Weather / desk atmosphere | 4 | 4 | Broad weather fields remain restrained; cropped objects give the journal a persistent desk context. |
| Brush / handwriting | 4 | 4 | Broken pigment and pencil marks; relaxed, legible handwritten passages. |
| Anatomy | 3 | — | Plant structure remains recognizable, but woody joints retain angular construction. |
| Composition / legibility | 4 | 4 | Portrait and ultrawide remain balanced; tiny previews lose text detail. |
| Page transitions | — | 4 | Opaque sheets move independently over an intact desk. |
| Support layout | — | 5 | In the reviewed corrected cases, all notes/table lines fit their card with bottom padding. |
| Restraint | 5 | 5 | Neither the weather field nor desktop clutter overpowers the primary subject. |
| Sampled temporal consistency | 4 | 4 | Weather changes and desk pan remain coherent between sampled frames. |

## Settings and reproduction

Botanical Watercolor's starting and recommended values remain **35% edge
irregularity, 65% pigment variation, 30% paper grain, 25% wet edges**. The new
weather treatment follows the existing weather and seasonal controls. Existing
Commonplace pace, theme, density and content preferences remain available; no
additional configuration controls were added.

```sh
# Art reviews without rebuilding PreviewHost.app:
Scripts/build-art-review.sh
Scripts/render-motion-review.sh build/art-motion-review/final --extended

# Build and launch the preview after review:
Scripts/build-preview.sh
Scripts/run-preview.sh --bloom-review
Scripts/run-preview.sh --commonplace-review
```

The local before/after gallery is `build/art-motion-review/comparison.html`.
Original captures are in `before/commonplace/` and
`build/bloom-art/refinement/final/`; sequential captures are under `round1/`
through `round4/`. Generated images remain in ignored `build/`, not source control.
The third-round extended gallery covers 280×180, 800×1200 and 3440×1440 plus
1400×1000 compositions, dense writing and all six notebook themes.

## Validation

- `make build` passed for all eleven arm64 saver bundles, PreviewHost and the
  optional helper, targeting macOS 14.6+.
- `Scripts/test.sh` passed **2,579,646 checks, zero failures**. All eleven actual
  bundles loaded together and rendered at five aspect ratios. Both sets of
  66 Options open/Done/reopen cycles passed, including the fallback timer.
  The 440 helper checks, standalone scaffold smoke, 20 installer tests and
  installation-document consistency checks passed too.
- Focused checks cover rain path/tangent agreement at multiple aspect ratios
  and long uptimes, deterministic weather masks, bounded camera motion, stable
  desk-image reuse, transparent page margins, independent page transitions,
  bundled font registration and pixel-identical pause/resume. Existing species,
  seasonal, preference and lifecycle checks remain in the full suite.
- Rebuilt smoke PNGs for both savers were visually inspected. The native
  Commonplace window also showed the bundled handwriting and fitted paper cards.
  The final dark Moonlit palette/meadow weather sample was inspected separately.
- No savers were installed, preferences reset, release artifacts published, or
  authenticated AI content generated.

## Cost and limits

Weather masks total 768 KiB of RGBA pixels and are generated once per seed;
movement transforms cached layers. The desk raster is capped at 2200 pixels on
its longest side (at most about 18.5 MiB), regenerated only for viewport/theme
changes. Handwriting is rasterized during page construction, not each frame.
The existing two page rasters and Bloom painting-cache bounds remain in place.

The final extended offline gallery measured Bloom CPU update p95 **5.56–5.68 ms**
at 1400×1000 and **5.87 ms** at 3440×1440. Commonplace's cached updates were below
**0.001 ms** p95, with a **226 ms** maximum that includes page/desk construction.
Bloom initialization reached **123 ms**. These accelerated 4 Hz gallery samples
include CPU layer preparation, not GPU composition, display pacing or energy.

The rebuilt native host was then run separately for each saver at 1200×742
logical points with Retina backing. Commonplace ran for 80 seconds through a
page change; Bloom ran for 20 seconds. Final captures are in
`build/art-motion-review/native/`.

| Native CPU layer update | Frames | p50 | p95 | Maximum |
|---|---:|---:|---:|---:|
| Commonplace | 2,421 | 0.038 ms | 0.056 ms | 174.09 ms |
| Years in Bloom | 630 | 5.06 ms | 8.04 ms | 10.80 ms |

Commonplace's occasional page-construction spike remains a performance limit;
cached pan updates are inexpensive. These native CPU timings also exclude GPU
cost and do not establish long-run energy use or physical-display smoothness.

Remaining artistic limits: woody branch joints still look angular in close-up;
some leaf clusters repeat; snow is deliberately fine rather than conspicuous.
Kalam is a handwriting font, so repeated letterforms remain detectable. Desk
objects are procedural drawings, and the camera suggests a pan without full
three-dimensional parallax. Small previews cannot preserve full text legibility.
Sampled images and pause/resume tests do not establish hours-long physical-display
motion quality or minimum-supported-OS compatibility.
