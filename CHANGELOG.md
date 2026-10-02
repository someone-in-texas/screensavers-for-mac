# Changelog

## 0.2.0

- Default City Drift to solid, fully offline vector roads in Paris, Boston and Tokyo.
  Add independent street-label, water, park and point-of-interest controls. Keep the
  64-city traditional map as an explicit option; preserve older appearance preferences.
- Retain configuration-window identity across host queries and explicitly hide sheets
  on Done. Exercise 12 real open/close/reopen cycles across both savers.
- Hold startup motion until cached-city selection completes. Hide incomplete raster
  viewports and preserve the outgoing scene during preview-to-fullscreen resizing.
- Include correctly sized legacy preview PNGs and multi-resolution TIFF artwork.
  Document the current macOS limitation that may leave the default picker swirl.
- Add cold-start, resize, restart, slow-network, zero-network vector-mode, settings
  migration and all 16 detail-toggle combination tests for every bundled city.


## 0.1.2

- City Drift: fix persistent tile-grid seams during fractional-pixel movement, most visible in dark palettes.
- Blueprint, Night and Terminal now preserve filled, antialiased lettering with a pointwise color treatment instead of noisy edge detection.
- Start from any complete, eligible cached city; otherwise immediately show a bundled vector street map of Paris, Boston or Tokyo.
- Preload the next city's existing cache records off the animation thread. Keep the outgoing scene visible until its replacement is ready; use a moving bundled map if a destination remains unavailable.
- Include attributed ODbL starter data and its source/refresh instructions. No speculative network tile prefetching.
- Add pixel-level palette/seam checks, cache-readiness and crossfade tests, and bundled-map smoke renders.

## 0.1.1

- Both savers: camera speed now spans 0–16, with a default of 6. Existing speed preferences migrate to the faster range; paused cameras stay paused.
- City Drift: smoothly changing horizontal, vertical and diagonal travel without stationary turns, plus a new city every four minutes while running.
- Retina-aware map rendering uses individual native tiles and sharp overlays, capped at 3840 × 2560 pixels (orientation independent), instead of enlarging a 1792 × 1120 map image.
- Per-city tile budgets, cancellation, cache revisits and server backoff remain bounded across transitions. No city preloading.
- Added long-session, direction, migration, Retina and transition/network regression checks.

## 0.1.0

- World Clock Room: isometric clock floor, 20 IANA time zones, smooth hands, configurable colors and motion.
- City Drift: 64 curated cities, six palettes, bounded drift, HTTP-aware persistent tile cache and permanent OSM attribution.
- Native configuration sheets, shared renderer infrastructure and a standalone PreviewHost.
- Offline math/cache/lifecycle tests, aspect-ratio smoke renders and verified DMG/ZIP release automation.
- Apple Silicon, macOS 14.6+. Initial release is ad-hoc signed and not notarized.
