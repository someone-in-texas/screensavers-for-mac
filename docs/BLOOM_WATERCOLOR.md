# Botanical Watercolor rendering review

Years in Bloom now defaults to **Botanical Watercolor**. Options contains one
Rendering choice: Classic, Organic, or Botanical Watercolor. Existing plant,
composition, pace, weather, palette, texture, seed, and season preferences survive.
No dependencies, downloaded textures, network services, shaders, or runtimes were
added. The original renderer remains available as Classic.

## Architecture and implementation

The original scene uses persistent `BloomStructure` branches and organs, with
Core Animation stroke reveals, transforms, opacity, and seasonal color changes.
Uniform filled paths, continuous outlines, straight repeated veins, and five
identical pale ellipses inside each leaf made its material read as vector art.
The paper was a stretched, viewport-capped raster. No existing shader/filter
pipeline needed replacing.

- `Savers/YearsInBloom/BloomIllustration.swift`: original Core Graphics painting
  code. Continuous, seeded contour displacement pins petioles; narrow foliage
  receives less displacement than broad leaves. Six translucent glazes, selective
  edge pooling, very small wet edges, fiber deposits/reserves, pressure-varying
  broken contours, curved clipped veins, and opaque pollen accents build each organ.
  Lavender/sage corollas and grass seed heads have separate tapered construction.
- `YearsInBloomScene.swift`: retains growth topology, seasonal phenology, sway,
  shedding, weather, and renewal. Summer/autumn (or evergreen winter) paintings
  share the same geometry and pigment pattern. Seasonal layer opacity changes
  continuously. Branches keep their seeded attachment curves, with subdued broken
  pencil/bark accents. Paper tiles repeat at 256 logical points, independent of
  backing density; paper fibers also influence painted regions locally.
- Stable paintings are made once, in birth order, with a **3 ms preparation budget**
  between organs. One organ can exceed that budget; it is not a hard frame deadline.
  A visibility catch-up path finishes any unprepared organ before it becomes
  legible, including under sparse/accelerated host callbacks. This can exceed the
  budget in low-frame-rate playback; it avoids late texture appearance. An added
  readiness regression first exposed 136 incomplete-frame checks in accelerated
  evergreen playback; the catch-up fix passes without relaxing that assertion.
  No workers or asynchronous completion handlers run after stopping. Pausing
  suspends preparation as well as the animation clock. Perennials retain their
  layers at annual renewals; resizing retains old artwork until replacement is ready.
- A per-scene **24 MiB LRU** and a separate conservative **24 MiB active raster
  budget** prevent high-resolution scenes from allocating unbounded textures.
  Cached and displayed images usually share storage; the two figures must not be
  added as if every byte were necessarily distinct. Settings/backing/viewport
  changes invalidate the cache. Old resize images can temporarily coexist with
  replacements. Raster density is capped at 192 pixels per normalized organ unit.
- `BloomSettings.swift`: backward-compatible optional `illustration` settings,
  independent defaults for partially specified art controls, finite clamping.
  `BloomConfiguration.swift`: one preset picker in the existing native sheet.
- `PreviewHost/main.swift`, `Scripts/render-bloom-review.sh`, and
  `Scripts/bloom-contact-sheet.swift`: repeatable offline comparisons and profiling.
  `Tests/NewSaverTests.swift`: deterministic paths and pixel data, attachment
  preservation, preference round trips, LRU accounting/eviction, invalidation,
  perennial reuse, artwork readiness before visible growth, retained images through
  resizing, bounded preparation, and byte-identical pause/resume output.

Core Graphics organ images fit this layer-based application better than a new
full-screen Metal/Core Image postprocess. They travel with the anatomy, preserve
paper reserves through seasonal changes, and avoid per-frame simulations or
texture uploads. Native branch paths still permit continuous growth reveals.

## Controls

| Artistic intensity | Initial | Recommended final | Mapping |
| --- | ---: | ---: | --- |
| Edge irregularity | 35% | 35% | Correlated displacement: normalized amplitude `value × 0.043` broadleaf, `× 0.018` narrow, `× 0.027` petal; petiole pinned |
| Pigment variation | 65% | 65% | Glaze alpha, local darker concentration, and selected edge deposition |
| Paper grain | 30% | 30% | Fiber deposition and reserved-paper opacity; much lower opacity in negative space |
| Wet-edge bleeding | 25% | 25% | Selective perimeter width `0.012 + value × 0.025`, alpha `value × 0.16`; no full-frame blur |

The review changed the mappings and material construction, rather than increasing
the intensity values. Organic retains geometry, glazes, and anatomy but omits wet
edges, pigment granulation, and edge pooling. Classic preserves the old treatment.
The existing Paper texture choice controls the negative-space fiber intensity.

Tune without editing rendering algorithms:

```sh
build/products/PreviewHost.app/Contents/MacOS/PreviewHost \
  --bloom-gallery --filter oak --years 3.35 \
  --rendering botanicalWatercolor --edge 35 --pigment 65 --grain 30 --bleed 25 \
  --output build/bloom-tuning
```

For persistent customization through the existing settings model, the optional
`bloom.illustration` object in `settings.v2` contains `rendering`,
`edgeIrregularity`, `pigmentVariation`, `paperGrain`, and `wetEdges`. Stored
intensities use 0–1 values; the preview arguments use 0–100. Missing/invalid art
members receive individual defaults. This work did not modify real preferences.

## Visual review and iterations

Actual renderer PNGs were inspected at normal viewing size and in a 3× close-up.
The A/B/C sheet includes mature oak, lavender, a juvenile oak, winter branches,
fading maple, and a five-plant meadow. Additional captures include all eighteen
species, seven palettes, spring/autumn/renewal sequences, portrait, small preview,
ultrawide, and a 2× backing-scale image. The Classic mature-oak PNG is byte-for-byte
identical to the pre-change baseline executable's capture at the same seed/age.
Generated captures stay in ignored `build/bloom-art/`; no generated products are
committed. Reproduce with:

```sh
make build
Scripts/render-bloom-review.sh
swift Scripts/bloom-contact-sheet.swift build/bloom-art/final
```

Open the [A/B/C comparison](../build/bloom-art/final/comparison.png),
[review gallery](../build/bloom-art/index.html), and the full-resolution PNGs beside them.
For all species, use `--bloom-gallery --years 0.2,0.38,3.35,3.66,3.86` without
`--filter`. Palette selection is `--palette moonlit` (or another saved palette).
Use `--width`, `--height`, `--backing-scale 2`, and `--zoom 3` for scale/detail checks.
`--years` is a comma-separated list of logical ages, not seconds.

Three principal weaknesses drove the revisions:

1. **Pale, homogeneous crowns:** increased base pigment coverage from 0.74 to
   0.82, made glazes more localized, increased selected concentration contrast,
   and reduced uniform paper dilution. The final leaves retain light reserves
   while separating more clearly at normal viewing distance.
2. **Mechanical trunks:** reduced, offset, and interrupted bark highlights.
   Removed whole-branch transparency after the close-up revealed dark circular
   overlap joints. Branch attachment/growth geometry stayed intact.
3. **Flat flower centers and bead-like florets:** replaced smooth lavender/sage
   beads with asymmetric tapered corollas and individual washes; added restrained
   gouache-like pollen and radial petal linework; removed inappropriate circular
   centers from spike-shaped inflorescences.

A separate performance revision replaced 0.55–0.65 second synchronous painting
bursts with incremental preparation. Subsequent close-ups and scale captures were
reviewed after these changes. C is recommended over B: its softer reserves and
localized deposits are visible in the close-up without making the meadow noisy.
The distinction is intentionally small at thumbnail scale.

Scores are a self-review from actual images, not a claim of external art approval.

| Criterion | A | B | C | Observation on final C |
| --- | ---: | ---: | ---: | --- |
| Authenticity | 2 | 3 | 3 | More like a colored botanical study; repeated procedural crowns and smooth main stems still reveal its construction |
| Line quality | 2 | 4 | 4 | Broken, tapered contour marks and clipped curved veins; branch silhouettes remain cleaner than a painted trunk |
| Pigment behavior | 1 | 3 | 4 | Local washes, reserves and darker edge deposits replace repeated flat ellipses; no fluid simulation |
| Botanical plausibility | 4 | 4 | 4 | Species silhouettes, attachments and proportions survive; spike flowers now have more credible individual forms |
| Composition | 3 | 3 | 3 | Cohesive palette and restrained paper, but the inherited meadow still separates into evenly spaced specimen groups |
| Restraint | 4 | 5 | 5 | No conspicuous grain overlay, halos, heavy bleeding or overall blur |
| Scale | 4 | 4 | 4 | Clear mature silhouettes and delicate detail; a deliberately small seedling remains very small in a full-page composition |
| Temporal stability | 5 | 5 | 5 | Fixed organ patterns in sampled growth/fall/renewal frames; byte-identical pause/resume tests; not an hours-long physical-display soak |

The rendering is warmer and more material, but it does not fully disguise the
procedural construction. The most valuable future art work is continuous tapered
woody silhouettes and less regular crown/meadow grouping, rather than stronger
noise or blur. Those would require a more substantial geometry/composition change.

## Reference evaluation (2026-10-13)

No third-party code or image assets were copied or adapted.

| Reference | License and maintenance verified | Compatibility / decision |
| --- | --- | --- |
| [Rough.js](https://github.com/rough-stuff/rough) | MIT; not archived; latest default-branch commit 2023-11-20 | TypeScript/Canvas/SVG; useful seeded, imperfect multi-stroke reference, but not a native runtime dependency |
| [Watercolor Stylization, Grace Gilbert](https://github.com/gracelgilbert/watercolor-stylization) | No declared repository license; not archived; latest commit 2019-04-30 | WebGL/GLSL multipass 3D demonstration; consulted the documented separation of pigment, substrate and edge controls; no code reuse without a license |
| [PaperShaders](https://github.com/rafael-b-g/PaperShaders) | MIT; not archived; latest commit 2026-07-01 | SwiftUI/Metal, macOS 14+, current manifest requires Swift tools 6.3. OS-compatible but would add a package/shader pipeline to this CLT/AppKit project; used only as a reference for correlated substrate effects |

License/commit information came from the repositories and GitHub API. The supplied
name “Watercolor Stylization” was interpreted as Gilbert's exactly named project.
PaperShaders' `Paper.metal`, Rough.js' `renderer.ts`, and Gilbert's pipeline README
were inspected. Their general techniques informed the design; the implementation
here was written independently.

## Validation and measured costs

Validation completed on Apple M5, macOS 27.0.1, targeting arm64/macOS 14.6+:

- `make build`: passed for all eleven saver bundles, PreviewHost, and the helper.
- `Scripts/test.sh`: **2,575,600 checks, zero failures**, all eleven actual bundles
  loaded and rendered at five aspect ratios, 66 native Options open/Done/reopen
  cycles plus 66 fallback-timer cycles, 440 helper checks, and standalone scaffold
  build/smoke. Its 20 installer integration tests and installation-documentation
  checks passed too. No savers were installed and no real preferences were reset.
- Focused development run: 26,312 checks, zero failures after fixing readiness.
  Large Retina cache accounting, image retention during resize, incomplete-job
  stopping, and pause/resume pixels are covered explicitly.
- Final gallery regeneration and contact-sheet compilation passed. The retained
  Classic oak PNG still matches the original baseline byte for byte.
- `git diff --check` and shell syntax validation passed. The unrelated staged
  `install-ai` file was left untouched.

A sequential native benchmark used the same seed-42 mature oak, specimen layout,
1200 × 742 logical viewport at 2× backing density, and 25 seconds of playback from
age 3.35 through autumn. Compilation and the test suite had finished first.

| Native measurement | Classic | Botanical Watercolor |
| --- | ---: | ---: |
| Preview callbacks measured | 783 | 784 |
| CPU update p50 | 8.16 ms | 7.70 ms |
| CPU update p95 | 9.40 ms | 8.52 ms |
| CPU update maximum | 9.97 ms | 8.98 ms |
| `ps` CPU spot samples | 29.2–33.7% | 24.9–27.6% |
| Resident memory spot samples | about 704 MiB | about 575 MiB |

Resident memory includes AppKit/Core Animation and the accelerated warm-up used to
reach age 3.35; it is not the painting-cache size or a normal-start memory baseline.
The callback timings do not measure GPU work, display scanout, or energy. These
are short samples on one machine, not a cross-hardware performance guarantee.

The final accelerated eighteen-species gallery measured CPU-update p95 from
0.14–6.43 ms, with maxima up to 22.60 ms. The 3440 × 1440 woodland measured p95
8.85 ms and maximum 34.15 ms, including preparation; occasional construction can
therefore slightly exceed a 30 FPS frame interval. The sampled 2× oak retained
15.98 MiB of paintings and the ultrawide woodland 14.83 MiB, below the active
budget. The cache remained within its separate 24 MiB limit. Pending jobs at a
new cohort represent future, still-invisible organs and stop progressing when the
scene stops.

Reproduce the native benchmark separately for each style:

```sh
build/products/PreviewHost.app/Contents/MacOS/PreviewHost \
  --bloom-review --offline --filter oak --layout specimen \
  --rendering botanicalWatercolor --seed 42 --review-age 217.75 \
  --profile --capture-after 25 --capture-and-quit \
  --capture-dir build/bloom-art/benchmark/botanicalWatercolor
```

Use `--rendering classic` and another capture directory for A. Logs are preserved
under `build/bloom-art/benchmark-*.log`, `validation-build.log`, and
`validation-tests.log`.

The visual review used genuine renderer PNGs, including native-preview captures.
Direct computer-use inspection returned `cgWindowNotFound`; the cached Options
image showed layout but did not reliably draw popup titles. Automated native
Options lifecycle tests passed, but manual selection of all three presets in
System Settings remains unverified. GPU power, a physical multi-hour soak, the
minimum supported OS, and non-M5 hardware were not measured. No release packaging,
installation, signing-identity change, or publication was performed.

The subsequent taper, grouping, sketchwork and page-weather iterations are documented
in [Bloom refinement](BLOOM_REFINEMENT.md), including the preview shortcuts.
