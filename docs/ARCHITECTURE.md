# Architecture

## Native modules and shared scenes

Each `.saver` is a real Mach-O `MH_BUNDLE`, with a unique Objective-C principal class
and bundle identifier. The tiny WorldClockRoomView / CityDriftView / VoxelCosmosView entry points
compose a `SaverScene` through `SceneSaverView`. Shared Swift types are compiled
into each module with distinct Swift module names; no separately installed framework
or dynamic package is required. No private entitlements, web content or runtime shell commands.

`ScreenSaverView` requests 60 Hz animation for City Drift and 30 Hz for the other savers. `startAnimation` applies settings
and starts the scene; `stopAnimation` cancels work. The development app uses the same
wrapper, with a standalone timer fallback on macOS releases that only supply
animation callbacks inside the actual saver host. Scenes present a cached Core Animation layer tree, updating
transforms at 30 Hz; reference Core Graphics rendering also supports offline snapshots.
The map viewport follows the window backing scale, preserves aspect ratio and caps
at 3840 × 2560 pixels in either orientation. Individual 256-pixel tile layers retain
native detail up to 4K; larger displays scale within the cap. Clock floor textures
use a separate 1792 × 1120 working viewport, rendered at twice that resolution
once per layout/settings change, with vector hand layers. This bounds rendering and
bandwidth without continuously repainting the surface. There is no fixed screen aspect ratio.

`SaverScene` defines start, stop, apply settings, reference drawing and optional layer presentation. The wrapper has
one level of subclassing, with scene behavior implemented through composition.
`PreviewHost` links these sources directly, and smoke mode additionally loads all three
built bundles to validate their metadata and Objective-C entry points.

## Time and World Clock Room

A monotonic clock integrates camera speed without jumps; a separate wall-clock Date
feeds cached Gregorian Calendars with IANA time zones. Thus DST, fractional-hour
zones and manual wall-time changes affect hands without teleporting the camera.
City assignment is deterministic for every positive or negative floor cell.

The projection maps a square floor through two isometric basis vectors. Face textures,
ticks and typography are cached for each city and composed into a static floor texture.
Only vector hand transforms and the gently moving camera change per frame. Floor seams, staggered shading and offset contact shadows establish depth.

## Settings

`ScreenSaverDefaults` uses stable module names:

- `com.someoneintexas.screensavers.worldclockroom`
- `com.someoneintexas.screensavers.citydrift`
- `com.someoneintexas.screensavers.voxelcosmos`

The v2 settings record expands camera speed from 0–2 to 0–16, defaulting to 6.
Legacy speeds are multiplied by six once, preserving zero and other appearance
preferences. Reset clears both versions. A versioned Codable record validates values and falls back to defaults when corrupt.
AppKit color wells, sliders, checkboxes and a palette popup save immediately and
update the open preview. Reset removes only appearance settings, preserving recent
cities. Each saver instance owns its scene and settings UI. Cross-process changes
are picked up at the next animation start; they are not broadcast during a session.

## City Drift

The editable 64-city source catalog contains names, regions, coordinates and zoom.
The previous eight cities are excluded from the next random choice. Each instance
selects another city after roughly two minutes of active elapsed time. A retained
outgoing layer tree covers the new scene until it is complete, then crossfades over
1.5 seconds. A fixed PreviewHost city stays fixed. The camera
follows a rotated 160 × 120 pixel ellipse whose speed never falls to zero, with
a different route bearing per city. Camera speed zero pauses travel but not city
changes. A separate uncapped monotonic timer keeps the city deadline accurate even
when frames are delayed; camera deltas remain capped to avoid jumps.
A view requests only the tiles
intersecting its current capped viewport, with no extra prefetch margin.

A background serial queue owns tile scheduling and cache access. Up to two requests
run per scene; each city visit has a hard limit of 256 network requests.
Failures are attempted once per visit, while 429/503 responses halt the pending
queue and impose a cooldown that survives city transitions. No next-city tiles
are requested until that city is displayed. Stopping cancels requests, invalidates the session, and
rejects late callbacks by a scene generation number. Multiple instances have independent
motion and request state; atomic cache records are safe to share across processes.

`TileProvider` separates the HTTPS URL template, attribution and cache namespace.
It defaults to OSM standard. New providers must supply their own attribution/cache
namespace and comply with their own usage terms; no arbitrary user URLs are executed.
HTTP User-Agent identifies the project and links to its public repository.

`TileCache` stores one atomic JSON record per tile: validated PNG bytes, expiry,
ETag and Last-Modified. It honors Cache-Control, Date, Age, Expires, no-store and
no-cache; uninterpretable freshness falls back to seven days. Expired tiles send
conditional requests. A 304 refreshes metadata using the cached image. Stale tiles
can show during a network outage except when revalidation is mandatory. Corrupt
records are ignored. Files live below the user's caches directory at
`com.someoneintexas.screensavers/osm-standard` (the host may provide a container path).
Pruning targets 192 MiB but preserves unexpired records and a minimum seven-day
retention window, so it is a soft disk limit. There is no offline download feature.

Available tiles are graded only when imagery/settings change. Light styles use
Core Image; dark styles use a pointwise sRGB tint that preserves filled glyphs and
antialiasing without a neighborhood-dependent edge filter. Opaque tile layers disable
edge antialiasing so fractional camera positions do not expose the background as
a persistent grid. Animation moves cached tile layers; vignette and typography live in a
separate overlay rasterized at the display detail level. Offscreen decoded tiles
and layers are discarded; revisits reload from the HTTP-aware disk cache. New tile
viewports fade in together over 1.2 seconds; a partial initial tile set is never revealed. Downloads are cancelled if their response exceeds
512 KB; decoding accepts only single-frame 256 × 256 images. Static optional grain
does not shimmer. Opaque overlay backgrounds
preserve contrast for city names and permanent attribution across all six palettes.
A fullscreen resize keeps a complete outgoing view while the larger viewport loads.
Startup camera motion waits for cache selection so cached time-zero tile sets do
not become incomplete during the asynchronous read.
`CityVisitCache` searches the existing disk cache for complete viewports at startup,
and reads the planned next city's cache records 20 seconds before its transition.
It never creates a network transport. Expired records requiring revalidation and
corrupt/incomplete cities are rejected. Generation and viewport checks discard stale
asynchronous results after stopping, restarting or resizing. At most one future
city's decoded tiles and one outgoing scene are retained.

`StarterMaps` loads three bundled ODbL vector extracts from the saver resource
bundle. The optional `.lines` style renders these for the entire session and selects
only their three cities. It constructs no tile loader or cache-selection request.
Five opaque road-path layers use one ink color; optional water/park paths use at
most three additional layers. Ring winding preserves holes without one layer per
polygon. Street names and named places have deterministic collision avoidance and
a shared 350-label budget. Geometry and labels rebuild on city/style/detail/scale
changes, not on every frame or speed adjustment. Native vectors remain crisp above
the raster viewport cap. The `.traditional` mode retains the 64-city tile renderer.

The following startup cache behavior applies to traditional maps (online vectors use the equivalent disk-only vector visit reader): Startup cache searches prefer cities outside the recent history, then older recent cities.
A recent cached city remains eligible in offline previews. Online sessions skip
recent cached cities so short runs do not repeatedly choose the same small cache. Online
cold starts choose a fresh destination from the full catalog, independently of the
bundled map that covers loading; the caption identifies the actually displayed map.
When there is no complete cached city, vector street outlines provide an immediate,
resolution-independent map while currently selected tiles load. Starter paths are
cached and translated with the camera; incoming raster tiles remain hidden until
the whole visible viewport is available. A destination that stays incomplete for
20 seconds switches to a bundled city so the outgoing cover cannot freeze forever.
The data refresh script is a maintainer-only Overpass operation, not a runtime or
CI dependency. Map data retains ODbL licensing separately from the MIT code.

## Build and distribution

The scripts invoke Apple's Swift compiler and SDK directly. This deliberately works
with Command Line Tools as well as full Xcode, without a generated Xcode project or
third-party project generator. `VERSION` generates bundle versions and User-Agent.
The `ARCH` build variable defaults to arm64; an x86_64 build can be added to a future
universal release using the same source and bundle metadata.

The build makes optimized binaries, then ad-hoc signs them. Packaging stages copies,
optionally re-signs with Developer ID, creates a DMG, optionally notarizes/staples it,
creates a ZIP and hashes the deliverables. Verification mounts the DMG, expands the
ZIP and checks all three bundles. Release Actions build the exact version tag and publish
only after tests and package verification pass. Ordinary CI needs no signing secrets.

## Configuration lifecycle

`SceneSaverView.configureSheet` retains a single controller/window. Repeated host
property queries, including while a sheet is open, return the same window. Controls
refresh from persistence only when hidden and detached. Done deactivates color wells,
ends the parent sheet (or standalone modal session), and orders the window out.
New optional settings decode with defaults so older records keep color/speed choices.
PreviewHost’s launch smoke test performs 18 real open/Done/reopen cycles across all three
savers and asserts window identity and dismissal. Actual System Settings behavior
still requires a manual check on each supported macOS version.

Legacy picker artwork is generated in 90×58 / 180×116 PNGs plus multi-resolution
TIFF. These are best-effort resources: current System Settings has no supported
custom thumbnail API, as documented in the README.

## Online vector maps (default)

`.online` renders OSM Shortbread v1 MVTs from `vector.openstreetmap.org/shortbread_v1`.
`VectorTile` is a bounded native protobuf/geometry reader: up to 2 MB per response,
100 layers, 20,000 features per layer and 100,000 retained geometry points per tile.
It validates field lengths, UTF-8, varints, tag indices, geometry commands, extents,
coordinate bounds and supported versions. Unused layers are discarded; no scripts,
styles, glyph downloads or web runtime are executed. Empty valid map layers are allowed.
The implementation follows the public [MVT specification](https://github.com/mapbox/vector-tile-spec)
and [Shortbread schema](https://shortbread-tiles.org/schema/1.0/).

`TileResourceLoader<Content>` shares the raster loader’s request scheduling, two-request
concurrency, 256-request visit budget, cancellation, response validation, validators,
backoff and HTTP freshness rules. Vector disk records use the separate `osm-shortbread-v1`
namespace. The vector response cap also applies after URLSession decompresses HTTP gzip.
Oversized transfers fail quietly instead of being mistaken for cancelled viewport work.

`VectorMapSource` composes complete visible tile sets into the existing native map
geometry, including residential roads, street-name geometry, water/ocean polygons,
waterways, green areas and named POIs. Road lines and polygon rings remain vectors.
The scene retains its previous complete geometry while a new visible tile arrives.
Composition, road/detail paths, label collision layout and detached presentation
layers are prepared on a serial background queue. At most one
composition runs per source, with new work coalesced and version/generation checks
rejecting obsolete results. The previous complete geometry remains visible. Native
layer rasterization caches online tessellation at the display scale while motion translates
the tree at fractional positions. Camera recovery caps delayed deltas at 1/15 second. The geographic viewport uses logical points capped at 1920×1280 in either
orientation (at most 54 z14 tiles), independent of Retina backing scale. Labels retain
the existing collision checks and 350-label cap.

Startup and future-city preparation scan existing vector cache records on a utility
queue, rejecting incomplete, corrupt and mandatory-revalidation stale data. No future
city is downloaded. Bundled data remains the cold-start and network-failure fallback;
normal online touring uses all 64 cities. The initial online viewport stays fixed until
complete so the next launch can reuse it. A separate motion clock keeps the bundled
fallback moving during that wait, followed by a complete-scene crossfade. Switching mode or stopping cancels cache
selection and network tasks. The prior v0.2 line default migrates to online once via
`mapSourceVersion`; subsequent explicit offline choices persist unchanged.

Live review can use PreviewHost `--online-vector --map --city London --capture-dir PATH
--capture-after 15 --capture-and-quit` (add `--details`). This launches a visible window,
downloads only its displayed viewport, saves its actual native layer tree, then stops.
`--online-vector` uses temporary preferences and does not overwrite user settings.

## Voxel Cosmos

`CosmosSettings` is a separate typed settings value nested in the shared persisted
record; absent cosmos settings decode to defaults without altering older appearance
preferences. Numeric inputs are clamped, including nonfinite values. The new module
has its own permanent settings domain and Objective-C principal class.

A deterministic voxel sphere painter generates shaded cube faces, banded/rocky/icy
surfaces and depth-sorted ring particles in an orthographic projection. Sprites are
cached per camera angle and discarded when a shot changes. A cached dithered sky,
soft radial light, orbit guides and those sprites compose into a reusable bitmap
capped at 800 × 600 pixels. Nearest-neighbor magnification preserves pixel edges;
captions render separately at display resolution. There are no downloaded assets.

A monotonic motion clock drives gentle drift and miniature orbits; a separate active
time clock changes subjects and camera angles even at zero motion speed. Stopping
pauses both clocks. A 2.4-second dissolve retains one outgoing image, then releases
it. The grand tour visits all eight planets and five wide/deep-space compositions;
fixed subjects can use changing angles or hold a selected angle. Portrait, ultrawide
and small previews fit the same composition without stretching the scene.
