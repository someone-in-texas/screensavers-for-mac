# Validation

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
- OpenStreetMap is a best-effort public service. Empty caches need connectivity;
  failures remain quiet and retry on a later city visit rather than repeatedly nagging
  or polling. Each saver instance chooses its own city on multi-display systems.
- The minimum supported OS has not been manually exercised on local hardware.
  CI and downloadable artifacts should be reviewed alongside these notes.
