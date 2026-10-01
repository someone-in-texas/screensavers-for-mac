# Architecture

## Native modules and shared scenes

Each `.saver` is a real Mach-O `MH_BUNDLE`, with a unique Objective-C principal class
and bundle identifier. The tiny WorldClockRoomView / CityDriftView entry points
compose a `SaverScene` through `SceneSaverView`. Shared Swift types are compiled
into each module with distinct Swift module names; no separately installed framework
or dynamic package is required. No private entitlements, web content or runtime shell commands.

`ScreenSaverView` owns the 30 Hz animation callback. `startAnimation` applies settings
and starts the scene; `stopAnimation` cancels work. The development app uses the same
wrapper and macOS timer. Scenes present a cached Core Animation layer tree, updating
transforms at 30 Hz; reference Core Graphics rendering also supports offline snapshots.
The map viewport preserves aspect ratio and caps at 1792 × 1120 pixels, then scales on
Retina / 5K screens. Clock floor textures are rendered at twice that working resolution
once per layout/settings change, with vector hand layers. This bounds rendering and
bandwidth without continuously repainting the surface. There is no fixed screen aspect ratio.

`SaverScene` defines start, stop, apply settings, reference drawing and optional layer presentation. The wrapper has
one level of subclassing, with scene behavior implemented through composition.
`PreviewHost` links these sources directly, and smoke mode additionally loads both
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

A versioned Codable record validates values and falls back to defaults when corrupt.
AppKit color wells, sliders, checkboxes and a palette popup save immediately and
update the open preview. Reset removes only appearance settings, preserving recent
cities. Each saver instance owns its scene and settings UI. Cross-process changes
are picked up at the next animation start; they are not broadcast during a session.

## City Drift

The editable 64-city source catalog contains names, regions, coordinates and zoom.
The previous eight cities are excluded from the next random choice. Each instance
stays in one city, at one zoom. The camera follows a smooth bounded path within
±80 / ±55 map pixels, preventing endless tile churn. A view requests only the tiles
intersecting its current capped viewport, with no extra prefetch margin.

A background serial queue owns tile scheduling and cache access. Up to two requests
run per scene; each scene has a hard limit of 96 network requests per session.
Failures are attempted once per session, while 429/503 responses halt the pending
queue and impose a cooldown. Stopping cancels requests, invalidates the session, and
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

Available tiles are composed into a bounded atlas, then graded with Core Image only
when imagery/settings change, batched at most four times per second during loading.
Animation translates a cached image layer; vignette and typography live in a separate
cached overlay. Downloads are cancelled if their response exceeds 512 KB; decoding
accepts only single-frame 256 × 256 images. Atlas changes
cross-fade, and static optional grain does not shimmer. Opaque overlay backgrounds
preserve contrast for city names and permanent attribution across all six palettes.
Offline with no cached tiles shows the palette background and city/attribution.

## Build and distribution

The scripts invoke Apple's Swift compiler and SDK directly. This deliberately works
with Command Line Tools as well as full Xcode, without a generated Xcode project or
third-party project generator. `VERSION` generates bundle versions and User-Agent.
The `ARCH` build variable defaults to arm64; an x86_64 build can be added to a future
universal release using the same source and bundle metadata.

The build makes optimized binaries, then ad-hoc signs them. Packaging stages copies,
optionally re-signs with Developer ID, creates a DMG, optionally notarizes/staples it,
creates a ZIP and hashes the deliverables. Verification mounts the DMG, expands the
ZIP and checks both bundles. Release Actions build the exact version tag and publish
only after tests and package verification pass. Ordinary CI needs no signing secrets.
