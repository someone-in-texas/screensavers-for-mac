# Validation

## v0.7.2.1 preparation

- `Scripts/release-check.sh` passed end to end. Both 54-cycle native Options
  passes succeeded (native callbacks and fallback timer). The local arm64 DMG
  and ZIP passed checksums, metadata, thumbnails, architecture and signatures.
  Packages are ad-hoc signed and not notarized.
- Final offline tests passed: 2,549,250 checks, zero failures. All nine rebuilt
  bundles loaded and rendered. Fruit-border checks cover 75 cached subjects
  across five seeds and every composition; they caught and verified the fix for
  clipping of wider procedural fruit.
- The first GitHub build exposed a Swift 6.1 type-checking limit in the fruit
  image closure. Splitting its drawing stages into helpers preserved all 112
  local gallery PNGs byte for byte before restarting the unpublished release.

- Sequential `art_critic` rounds covered botanical silhouettes, connected growth,
  centering, vector chair edges, light/dark palettes, portrait framing and renewal.
  After user feedback exposed completed-root plateaus, the follow-up review used
  contiguous five-second frames across Research 60–115 seconds and Strawberry
  45–100 and 120–175 seconds. The critic approved ongoing growth and changing
  topology, including sparse handoffs. This was frame-sequence review, not live
  MP4 playback. Reproducible three-minute, 15 FPS exports are produced by
  `Scripts/render-print-motion.sh` without pre-roll or time compression.
- Reproduced the upper-right displacement in macOS System Settings. Temporary
  native-host tracing showed a 3420×2214 saver view clipped by a 1710×1107 parent.
  Fitting a local scene layer to the visible viewport corrected the preview; the
  vector chair appeared centered and sharp. Temporary tracing was then removed.
  The actual-bundle smoke test now reproduces oversized views under both ordinary
  and offset portrait parent bounds. Native development PreviewHost also covers
  windowed/full-screen transitions; the native System Settings check used its
  live preview, not a separately observed locked-screen session.
- Regression coverage includes preview-to-full-screen resizing, positive and
  negative host bounds origins, live rebuilds under an existing transform,
  reparenting, backing resolution, seeded silhouettes, visible eight-second
  growth on all three initially bare fruits, generation-specific geometry, paused
  scenes and bounded one-hour layers. Every five-second window through an hour
  must include growing ink: at least six Strawberry paths, and at least one
  Research path plus a second growing or fading path during deliberate handoffs.
  Research framing stays fixed while its geometry renews.
- The gallery covers seeds 42 and 91, 280×180 previews, 800×1400 portrait,
  3440×1440 ultrawide, light/dark palettes and states at 0, 8, 25, 55, 60, 300
  and 900 seconds. README/picker artwork is actual renderer output.
- Gallery CPU layer-update p95 was below 0.08 ms for both prints after
  initialization, including vector chair updates. These are local
  CPU measurements, not GPU, energy or display burn-in measurements.
- Wider slow foreground drift and renewed routes reduce stationary high-contrast
  content without changing palettes. These are not measured burn-in tests and do
  not guarantee protection; normal display sleep remains appropriate for long absences.
- These preparation checks were completed locally before tagging or publishing.


## v0.7.2 change validation

- `make release-check` passed: 1,320,324 offline checks, zero failures; all nine
  actual bundles loaded; 54 Options lifecycle cycles with native callbacks and
  another 54 with the fallback timer. The mounted DMG and expanded ZIP passed
  checksums, architecture, metadata, thumbnails, identifiers and signatures.
  Local packages are ad-hoc signed, not notarized.

- Five sequential `art_critic` review/implementation rounds were completed for
  **each** saver. Round one established the two print concepts. Round two removed
  overlapping maze boxes, repeated fruit contours and stair-step circuits. Round
  three varied architectural chambers and connected the root systems. Round four
  refined pigment, small-preview visibility, portrait scale and dark ink. Round
  five accepted the final light/dark prints, alternate seeds and sampled motion.
- The research chair was rebuilt against the supplied blue folding-chair reference:
  rounded tubular frame, inset bowed steel back, folded seat rim, splayed supports,
  hinges and braces. Original procedural geometry keeps its reduced matte treatment.
  The drawing consists of unequal open chambers and faint construction lines, with
  foot routes connecting the object to the plan. No room, text or camera tour.
- Strawberry uses exactly three unequal crimson pigment bodies, a shared root
  anatomy, staggered organic-to-angular transitions, occasional contacts and faint
  traveling signals. Pigment and paper are cached; curves and longer trace segments
  share one drawing rather than meeting at a horizontal boundary.
- Both original renderers remain intact behind a modifier-revealed checkbox.
  Live UI verification covered discovery, switching into the compact alternate
  panel, returning to the print, and re-hiding the checkbox on reopening Options.
  The main README and its gallery contain no mention or promotion of the alternate
  mode. Fine-art options, screenshots and picker thumbnails lead the release.
- Preference migration retains original palette, environment, text and seed keys.
  New fine-art preferences are namespaced. Missing mode keys select the new print,
  including on upgrade; existing custom legacy settings remain available if the
  alternate mode is enabled. Invalid individual legacy values fall back safely.
- Offline tests cover deterministic paths, all composition/blend/drawing bounds,
  exactly three forms, palette validity, day-long chair continuity, settings
  migration/persistence/reset, hidden-panel discovery and simplification, live
  renderer replacement, pause/resume and bounded one-hour layer trees. Existing
  cave/field tests continue to exercise the preserved renderers directly.
- Rendered galleries cover seeds 42, 91 and 807; ivory, charcoal, blueprint, sage and
  museum-night palettes; 280×180 previews, 800×1400 portrait and 3440×1440 ultrawide;
  and states at 0, 60, 300 and 900 seconds. Quarter-second samples from 57–62 seconds
  show quiet incremental motion without visible jumps. The six refreshed README
  images are actual renderer output; no synthetic marketing mockups are used.
- Final gallery CPU layer-update p95 was below 0.004 ms for Research and 0.012 ms
  for Strawberry after initialization; rare chair raster updates reached about
  0.56 ms. Native development previews measured Research p50/p95 0.077/0.141 ms
  over 2,512 frames and Strawberry 0.184/0.267 ms over 1,924 frames (the latter
  included live mode changes). Both retain the existing 30 FPS target.
- These are local CPU update measurements, not GPU/energy/scanout benchmarks.
  Geometry is deliberately bounded and curated, with slowly changing stroke
  reveals rather than unbounded maze growth. A physical hour-long soak, every
  supported Mac/macOS, and the actual System Settings saver host remain manual
  validation targets.


## v0.7.1 change validation

- `make release-check` passed: 192,830 offline checks, zero failures, all nine
  actual bundles loaded, 54 Options open/Done/reopen cycles with native callbacks
  and another 54 with the fallback timer. Expanded ZIP and mounted DMG passed
  checksum, architecture, metadata, thumbnail, unique-identifier and signature
  verification. Local packages are ad-hoc signed, not notarized.
- Five sequential art-critic review/response rounds and five lore-review rounds
  were completed for **each** new saver before release. Strawberry revisions
  refined field depth, organic leaf and fruit shapes, grounded foliage, restrained
  cable routes, instrument scale, and solid baskets beneath a warm pendant. Research
  revisions refined connected floors, chamber reveals, chair upholstery and contact
  shadows, archive depth, board mounting, and solitary-chair framing.
- Lore reviews kept references subordinate to the art: one seed-selected fruit
  triad, no deliberate triad or chair shrine in Pure Art, neutral experiment
  metadata, sparse original notices, and rare deep messages during visible panel
  visits. The longest field fragment exposed a four-pixel clipping issue; a
  measured font adjustment and exhaustive phrase-width checks cover it.
- Final renderer galleries cover seeds 42, 91 and 807, field and basement, all
  three research compositions, Pure Art and deep lore, alternative palettes,
  280×180 previews, 800×1400 portrait and 3440×1440 ultrawide frames. Thirty-second
  samples cover the eased transitions; deep-message samples extend to 2,590 seconds.
  README images are actual renderer output, not mockups.
- Procedural tests cover seeded worlds, connected cable and chamber graphs,
  perfect-maze generation and actual backtracking traversal, two-hour camera
  continuity at every pace, four-hour Pure Art filtering, text rarity/fit,
  contradictory notices, wind/weather bounds, paused time, settings migration,
  and bounded long-session layer trees.
- Both native Options sheets were visually inspected. Strawberry ran for 5,974
  native preview frames: CPU update p50 0.213 ms, p95 0.301 ms, maximum 3.720 ms.
  Research ran for 5,752 frames, including travel from the chair alcove toward the
  archive: p50 0.032 ms, p95 0.179 ms, maximum 0.326 ms. These are local CPU
  simulation/layer-publication measurements, not GPU, energy or physical scanout
  benchmarks. Hour-long physical playback and every supported Mac remain untested.
- The worlds intentionally use cached 2.5D illustration and continuous pan/zoom,
  with seeded variation inside authored compositions. They are not unbounded 3D
  environments. Source grounding and fiction boundaries are documented in
  [Art and lore](ART_AND_LORE.md).


## v0.7.0 change validation

- `make release-check` passed: 30,609 offline checks, zero failures, all seven
  actual bundles loaded, 42 Options open/Done/reopen cycles with native callbacks
  and another 42 with the fallback timer. Expanded ZIP and mounted DMG passed
  checksum, architecture, metadata, thumbnail, identifier, and signature checks.
  Local packages are ad-hoc signed, not notarized.

- Five sequential art-critic review/response rounds were completed for **each** new
  saver before release. Flourish revisions refined pacing, stem hierarchy, coherent
  leaf families, separated blossoms, fern and bell silhouettes, tightening tendrils,
  and ornament spacing. Lattice revisions refined glyph rarity, age/light hierarchy,
  distinct Drift headings and sustained vitality, and edge-to-edge integer scaling.
- Final galleries cover seeds 42, 91, and 807, mature and renewal states through
  340 seconds, small previews, portrait layouts, dense/sparse drawing styles, and
  matched zero/default/high glow. The four README images are actual native renderer
  output from seed 91: Midnight/Spiral and Porcelain/Ornamental for Flourish;
  Bioluminescent/Reef and Amber/Signal for Lattice.

- Flourish tests cover seeded growth, tapered geometry and polygon closure, bounded
  dense portrait growth in all styles, 30/60 Hz equivalence, spatial occupancy,
  palette roles, settings migration/round trips, and suspended-time exclusion.
- Lattice tests cover four deterministic long-running rules, cell/resource bounds,
  local recovery, event expiry, wrapped boundaries, prolonged Drift vitality,
  settings migration, and integer nearest-neighbor single-image presentation.
- Native Options for both new savers were visually inspected. Flourish ran for
  8,149 native preview frames; the first 6,000 CPU samples measured p50 0.311 ms,
  p95 0.595 ms, maximum 0.894 ms on the development Mac. These measurements cover
  simulation and layer publication, not GPU cost, power use, or physical scanout.
  Lattice's 5,789-frame native run measured p50 0.040 ms, p95 7.966 ms, maximum
  11.056 ms, including its independently timed cellular bitmap updates.


## v0.6.0 change validation

- `make release-check` passed: 18,366 offline checks, zero failures, all five actual
  bundles loaded, 30 Options open/Done/reopen cycles with native callbacks and
  another 30 with the fallback timer. The mounted DMG and expanded ZIP passed
  checksum, architecture, metadata, thumbnail, unique-identifier, and signature
  verification. Builds are ad-hoc signed, not notarized.

- Dapple deterministic coverage includes seeded generation and pixels, palette roles,
  settings migration/bounds/round-trip, daily restart behavior, 30/60 Hz equivalence,
  ten-minute dense portrait runs in every motion mode, unequal-mass contact separation
  and energy, terrain continuity/derivatives, material differences, cached textures,
  bounded layers, toggles, and suspended-time exclusion.
- Five sequential art-critic rounds refined long queues into temporary neighborhoods,
  separated rotating grain from stationary light/shadows, fixed texture scale,
  decoupled colors from lanes, and softened ceramic edges. Final evidence covers
  two- and five-minute poses across seeds 17, 42, 91, and 807, small (280×180), portrait,
  sparse/full populations, and four materials at an identical pose. Hero screenshots
  come from the actual renderer, with Meadow/Paper/Hills and Night Garden/Ink/Zen.
- A 200-second native Retina preview produced 5,983 frames: CPU update p50 0.244 ms,
  p95 0.465 ms, maximum 0.692 ms. The native Dapple options sheet was visually checked.
  Final paired-renderer measurements at 1920×1080, 2560×1440, and 5120×2880 stayed
  below 0.083 ms CPU p95 per pair after initialization; portrait was below 0.046 ms.
  These timings measure CPU simulation/layer publication, not GPU cost, energy,
  physical scanout, or performance on every supported Mac/macOS release.
- City Drift’s featured image is a native capture of online San Francisco vector
  data, with water, parks, street labels, points of interest, and OSM attribution.
  No downloaded tile archive is included in the repository or release.


## v0.5.0 change validation

- `Scripts/release-check.sh` passed locally: 15,449 checks, zero failures, both
  native preview lifecycle runs, and verified arm64 DMG/ZIP packages with all four
  savers. Packages are ad-hoc signed, not notarized.

- Offline regressions cover v0.4 preference migration, all five Cosmos placement
  anchors, stable fixed-subject pixels over successive frames, and immutability
  of retained images while an orbiting moon advances.
- Paper Sky checks seeded reproducibility, launch variation, three distinct camera
  projections, continuous camera blending, paused flight, stop/restart behavior,
  arriving/departing companions, a bounded layer tree, live switches and resizing.
  The polish pass also samples 1,500 animation ticks across camera changes to check
  fixed cloud silhouettes and continuous visible positions, plus slow solar motion
  and its pause behavior. Three art-critic iterations covered full-size, portrait,
  small previews and sampled transition poses.
- Smoke images cover all four savers at five aspect ratios, every Paper Sky
  camera/palette combination, both Paper Sky camera transition midpoints, every
  Cosmos composition, and existing map/planet
  variants. All four actual bundles load and expose native options sheets.
- The options lifecycle exercises 24 open/Done/reopen cycles, both with native
  callbacks and with the forced standalone preview timer. Paper Sky's native
  options sheet and Retina live preview were also visually inspected.
- A 53-second local polished Paper Sky run crossed all three camera styles: 3,338
  frames, CPU render p50 0.93 ms, p95 1.94 ms, maximum 2.27 ms. Its live Retina
  preview was also visually inspected. A 22-second Cosmos run
  crossed a system view and off-center Earth closeup: 694 frames, p50 1.33 ms,
  p95 2.25 ms, maximum 14.40 ms. These are local CPU observations, not GPU,
  energy or physical display scanout measurements. Actual ScreenSaver-host
  behavior and older macOS versions remain release-test targets.
- README images and picker thumbnails come from the native procedural renderer.
  The release gate rebuilds, runs offline and native-preview checks, and verifies the
  four bundles, signatures, metadata and checksums in expanded ZIP and mounted DMG.

## v0.4.0 change validation

- 15,418 deterministic offline checks cover the existing renderers plus Cosmos
  settings/migration, all-planet tour coverage, bounded aspect-preserving buffers,
  stopped/paused/restarted motion, fixed subjects, captions and transition cleanup.
- Vector regressions check background publication of complete paths/details/labels,
  backing-scale correctness, speed-only changes, rejection of stopped/replaced work,
  preserved complete geometry during incomplete downloads, and fresh city selection
  even when a recently viewed city is the only complete cached destination.
- Offline smoke frames cover all three savers at five aspect ratios, every Cosmos
  subject, all four camera/background options and pixel/glow extremes. Native bundles
  load independently. Eighteen real options open/Done/reopen cycles pass, including
  a bounded wait for animation frames. Both native callbacks and a forced
  standalone preview timer are exercised to cover older macOS preview hosts.
- Visually inspected full system, individual planets, portrait backgrounds, camera
  angles and small previews. The native Cosmos options sheet was also inspected.
  Small previews reserve space for captions; high-angle system views fit their
  wider vertical footprint. README images are actual renderer output.
- A 22-second native Cosmos review traversed a system view, dissolve and Earth
  closeup: 692 frames, render p50 1.89 ms / p95 2.21 ms / maximum 16.13 ms. A cached
  London review with all map details enabled produced 745 frames in approximately
  12 seconds: p50 0.021 ms / p95 0.027 ms, with an 86 ms startup/update maximum.
  These are short local M5 CPU-side observations, not GPU/energy benchmarks or a
  guarantee of every display's frame pacing. No live map downloads were needed.
- All three arm64 saver bundles are included in the DMG and ZIP, with verified
  checksums, metadata, thumbnails and ad-hoc signatures. System Settings' actual
  saver host and older macOS versions still require manual release testing.


## v0.3.0 change validation

- 15,387 deterministic offline checks pass. New MVT coverage includes feature
  categories, extent scaling, signed buffered coordinates, closed rings, malformed
  commands, overflowing/truncated protobufs, unsupported versions and byte limits.
- All 16 combinations of online detail switches are checked using synthetic MVTs.
  Mocked HTTP verifies MVT URLs/User-Agent, fresh-cache zero-request reopening, ETag
  revalidation/304 reuse, cancellation and late-response rejection. The shared loader
  retains the existing concurrency, failure, backoff and request-budget tests.
- Vector cache selection accepts complete cities, rejects corrupt/mandatory-stale
  records and discards cancelled scans. Defaults migrate to online while preserving
  appearance; explicitly selecting offline remains persistent.
- Scene tests verify the bundled first frame, bounded Retina viewport, native-resolution
  overlays, stable initial network coverage, continued fallback motion during loading,
  city changes and switching back to offline without further requests.
- A visible live London preview loaded and rendered OSM Shortbread vectors. Only its
  displayed viewport was requested. A follow-up details review used the same location;
  water, parks, street labels and POIs were visually inspected in the native layer capture.
- The resulting London map also reopened successfully in a visible preview with
  networking disabled, using its on-disk vector cache.
- The live review caught incomplete reusable startup coverage caused by early camera
  movement. Initial online coverage now stays fixed until complete while the fallback
  keeps moving; the complete online view then crossfades into place.
- With all detail switches enabled, the local M5 preview sampled approximately **0.4%
  CPU and 222 MiB RSS** at 1200×742 logical points after loading. This is a short spot
  sample, not a multi-hour energy benchmark. CI/smoke tests never contact public tiles.

## v0.2.0 change validation

- 15,247 offline checks pass, including older-settings decoding and all 16 combinations
  of street-label/water/park/point-of-interest toggles for each bundled city.
- Empty-cache default startup is checked after pre-start layout, at small preview,
  Retina fullscreen and portrait sizes, plus same-instance stop/restart. Every first
  frame has five solid vector road layers; mocked transport confirms zero requests
  across startup and multiple city transitions.
- A deliberately slow mocked transport proves individual initial tiles stay hidden
  until the viewport is complete. Expanding the preview to 2560×1440 logical points
  at 2× retains a whole outgoing cover while the larger map is incomplete.
- Native PreviewHost completes 12 open/Done/reopen configuration cycles across both
  savers, asserting stable window identity during repeated property reads and full
  sheet detachment/hiding on Done. This exercises the real AppKit modal lifecycle.
- Actual offline layer PNGs for all three cities, minimal Paper/Blueprint maps and
  optional details were inspected. README map screenshots were updated from those
  renders. Detail geometry is batched into three layers; labels are bounded at 350.
- Native UI automation could not connect to System Settings on this machine.
  These checks do not prove the intermittent host-specific Options failure is gone.
- Legacy PNG/TIFF thumbnails are generated and verified in both release bundles.
  Apple confirms current System Settings has no supported custom-thumbnail API;
  the blue swirl may remain despite valid resources (README links Apple’s response).

## v0.1.2 change validation

- Uniform map fixtures exposed a persistent grid in the actual layer renderer.
  Opaque, non-antialiased tile edges pass pixel-uniformity checks in all six palettes
  at 1×, 1.5× and 2× display scales during fractional-pixel camera movement.
- Filled-glyph tests cover Blueprint, Night and Terminal. A gradient with an
  antialiased diagonal is pixel-identical when tinted whole or as four separate tiles.
- Startup cache selection rejects missing, corrupt and must-revalidate stale data;
  complete cached cities appear without network requests. Crossfade tests verify
  outgoing-scene retention/release and fallback when a destination stays unavailable.
- All three bundled street datasets decode and render offline in PreviewHost;
  packaging verifies that the editable data, attribution and ODbL license are present.
- Real cached Dhaka tiles were used for local before/after palette review without
  requesting additional raster tiles. Automated tests use synthetic tiles only.

## v0.1.1 change validation

- Offline regression coverage includes one-time preference migration, zero-speed
  preservation, continuous movement through turns, all travel directions, twelve
  simulated minutes of city changes, delayed animation callbacks, and fixed-city previews.
- The actual layer renderer is exercised at 2× backing scale with a 2560 × 1440
  logical viewport, verifying native 256-pixel tiles, a 3840-pixel overlay, bounded
  layer counts, completed tile fades and backing-scale changes.
- Mocked networking checks that city changes cancel old tasks, reject late responses,
  renew the request budget, retain server backoff and retrieve revisited tiles from cache.
- Manual native PreviewHost review confirms crisp map details and attribution in a
  full-screen Retina preview. This is separate from macOS's own screen saver host;
  the System Settings activation limitation below remains applicable.

## Local release candidate

Validated on an Apple M5 Mac running macOS 27.0, using Apple's Swift 6.4 Command
Line Tools and macOS SDK. The deployment target is macOS 14.6. Full Xcode is not
installed locally; GitHub Actions passed the full build, tests and package checks
with Xcode 16.4 on its macOS 15 Apple Silicon runner. A deployment target is not a claim of hands-on testing on
every intervening OS release.

- Both optimized arm64 executables are Mach-O bundles with valid, distinct Info.plist
  metadata and ad-hoc signatures. The preview is a native macOS executable.
- Deterministic tests cover settings persistence/isolation/corruption; clock IANA zones,
  spring and autumn DST, fractional hand angles; projection; monotonic motion; Mercator
  wrapping and viewport bounds; recent-city avoidance; HTTP freshness/validators,
  corrupt cache records, offline fallback, two-request concurrency, cancellation,
  rate limiting, and the 256-request city-visit cap. No test requests reach OSM.
- Smoke rendering covers 16:10, 16:9, ultrawide and small 280 × 180 preview sizes,
  both reference drawing and live layer rendering, plus all six map palettes.
- The actual saver principal classes load dynamically and provide configuration sheets.
  PreviewHost launches, switches scenes, opens a configuration sheet and terminates.
- Manual PreviewHost review includes the clock floor, live Paris tiles, Paper and
  Blueprint, permanent attribution, native color panel changes and Reset to Defaults.
  README screenshots were saved from the live preview, not fabricated mockups.
- Install, uninstall and reinstall scripts were exercised for the current user.
  Both bundles install for the current user and appear under System Settings → Wallpaper
  → Screen Saver → Other → Show All. System Settings selection/full-screen activation
  on this OS preview could not be confirmed through automation; the standalone preview
  and actual-bundle loading checks pass. No system security setting was relaxed.
- A clean local git checkout also passed the complete build/test/package verification.
- Package verification checks SHA-256 hashes, mounts the DMG read-only, extracts the ZIP,
  and validates both bundles' metadata, architecture, Mach-O type and code signatures.

## Performance observations

The v0.1.2 offline Boston starter-map preview showed about **0.3% CPU** and
**174 MiB RSS** at 1200 × 742 logical points on the local M5. This is a spot sample.
The native UI inspection connection was unavailable for this update; palette and
starter-map visual review used the actual offline layer-rendered PNGs.


The v0.1.0 1200 × 742 live preview on the local M5 showed approximately **0.3% CPU for City
Drift** after loading and **1.6% for World Clock Room**, using `ps` samples. These are
spot observations, not a standardized benchmark or a guarantee for all monitors.
The initial CPU-redrawn map used around 28%; both released renderers move cached layers.
Resident memory in these preview samples was roughly 150–200 MiB. Tile image payloads,
in-memory tiles, viewport dimensions, concurrent requests and per-city requests are
bounded. Disk cache pruning preserves fresh/seven-day records, so its 192 MiB target
is intentionally soft. GPU energy and multi-hour thermal behavior are not benchmarked.

## Release limitations

- Apple Silicon only in the distributed artifacts; Intel/universal builds are not validated.
- Ad-hoc signed, not notarized. No valid Developer ID identity or repository signing
  secrets were available. The optional credentialed workflow is prepared but cannot
  be end-to-end notarization-tested without those credentials.
- Traditional map mode uses OpenStreetMap, a best-effort public service. Empty tile
  caches need connectivity for detailed imagery; the default three-city vector mode is offline;
  failures remain quiet and retry on a later city visit rather than repeatedly nagging
  or polling. Each saver instance chooses its own city on multi-display systems.
- The minimum supported OS has not been manually exercised on local hardware.
  CI and downloadable artifacts should be reviewed alongside these notes.
