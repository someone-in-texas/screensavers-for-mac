# Changelog

## 0.7.2

- Recast **Good Research Takes Time** as a sparse moving drawing: a matte blue
  folding chair, unfinished architectural routes, five quiet palettes, and patient
  changes of orientation.
- Recast **Strawberry Fields Forever** as three crimson pigment forms with fine
  roots that gradually acquire circuit geometry, subtle print textures, six
  palettes, and restrained growth, breathing and signals.
- Add focused fine-art options, seeded compositions, updated gallery images and
  picker thumbnails. Preserve the original scenes and saved preferences in an
  optional hidden Lore Mode; new and upgraded installations begin with fine art.
- Cache paper and pigment, keep animation geometry bounded, and expand offline
  coverage for migration, live mode changes, aspect ratios and long sessions.

## 0.7.1

- Add **Strawberry Fields Forever**, an offline moonlit field above a fictional
  laboratory, with organic roots becoming cables, soft wind and hype weather,
  slow continuous descents, seven palettes, and seeded procedural worlds.
- Add **Good Research Takes Time**, an offline research cave with connected
  chambers, lamplit desks, dignified chairs, original mazes and a deliberately
  patient, backtracking agent. Six palettes and repeatable seeds.
- Provide Pure Art and optional deeper lore modes for both, with rare local
  fictional messages and no live social-media or AI dependency.
- Integrate both into native Options, PreviewHost, install/uninstall, screenshots,
  and nine-bundle DMG/ZIP packaging. Preserve existing saver preferences.

## 0.7.0

- Add **Flourish**, progressive procedural botanical ink with tapered stems,
  space-aware branching, distinct leaf and blossom families, and gentle renewal.
  Five growth styles, eight palettes, three pen characters, paper backgrounds,
  wash, breeze, and fresh/daily/fixed seeds.
- Add **Lattice**, a luminous pixel ecosystem with four cellular rule families,
  resource and age dynamics, localized events and recovery, eight palettes,
  integer-scaled pixel cores, adjustable glow, trails, and deterministic seeds.
- Integrate both savers into native options, previews, installation, and verified
  seven-bundle DMG/ZIP releases. Existing preferences remain compatible.
- Arrange the README gallery from City Drift and World Clock Room through the
  newer additions, keeping new savers at the bottom.

## 0.6.0

- Add **Dapple**, an entirely offline piece of generative kinetic art: tactile circles,
  invisible rolling hills, soft contacts, occasional hops, and slow moments of stillness.
- Four motion modes (Hills, Float, Playground, Zen), eight palettes, and Paper, Ink,
  Ceramic, and Soft materials; native controls for population, size, speed, textures,
  shadows, events, and fresh/daily/fixed seeds.
- Integrate Dapple into PreviewHost, bundle loading, install/uninstall, DMG/ZIP packaging,
  and verification. Cache procedural textures; advance a separate seeded simulation
  at fixed timesteps and publish complete 30 FPS Core Animation updates.
- Replace City Drift’s featured offline Paris image with an actual online San Francisco
  capture. Streamline the README and move picker/Options details into troubleshooting.


## 0.5.0

- Add **Paper Sky**, an offline procedural paper-airplane flight through synthwave sunsets, with isometric, follow and side-on cameras, evolving palettes, layered clouds and arriving/departing companion planes.
- Polish Paper Sky with coherent cloud parallax during camera rotations, atmospheric cloud edges, a slowly drifting sun and soft halo, individually shaped and shaded aircraft, fine fold lines, and spatial companion arrivals/departures.
- Add native Paper Sky controls for viewpoint, palette, duration, speed, cloud cover, companions, trails, sun and glow. Include the fourth saver in builds, installation, packaging and bundle-load checks.
- Give Voxel Cosmos centered and four-quadrant compositions, with a varied tour or a fixed preferred position. Keep the full subject within the viewport in portrait and wide layouts.
- Remove the slow fractional zoom that made voxel edges update in sweeping waves. Snap sprite movement to pixels and publish complete frames in a single disabled-animation transaction; retain soft dissolves between shots.
- Preserve existing preferences while adding the new settings. Broaden the repository description to cover the growing collection.

## 0.4.0

- Add Voxel Cosmos: an entirely offline voxel solar system with all eight planet
  closeups, isometric system views, an asteroid belt and deep space. Choose a grand
  tour or fixed subject, changing camera angles, four backgrounds, pixel size, glow,
  star density, orbit guides, asteroids and captions. Include native options and artwork.
- Smooth City Drift with a 60 Hz cadence, cached vector layer rasterization, tighter
  recovery after delayed frames, and background vector composition/path preparation.
- Reduce city visits to two minutes. Start online sessions from the full city catalog
  behind a labeled bundled fallback; favor less-recent complete cached cities. Keep
  future-city preparation disk-only because public OSM services prohibit prefetching.
- Extend build, install, uninstall, preview, smoke tests and verified DMG/ZIP packaging
  to all three savers.

## 0.3.0

- Make online vector maps the default across all 64 cities, with no API key. Preserve
  independent street-label, water, park and POI controls, and add local road detail.
- Retain the three-city offline mode, bundled startup maps and cached-city fallback.
  Load only the displayed vector viewport; never prefetch future cities over the network.
- Add a bounded native MVT decoder and reuse HTTP cache, concurrency, cancellation,
  conditional requests and backoff logic across vector and raster formats.
- Keep vector geometry crisp at Retina resolution without multiplying tile requests.
- Migrate the previous default to online while preserving appearance; explicit new
  offline selections persist. Traditional raster mode remains available.

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
