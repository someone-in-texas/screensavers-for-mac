# Maps, privacy, and performance

## City Drift

City Drift defaults to **online vector maps across all 64 cities**: solid road
lines with Water enabled, drawn natively at your display’s resolution. No API key is required.
In Options, toggle **Street labels**, **Water**, **Parks**, and **Points of interest**
independently. The online source includes local streets as well as major roads.

Startup checks the local cache before presenting a city. A complete cached viewport
opens directly, including recently visited cities; only the palette background is
shown while disk reads and vector composition finish. Less recent cached cities
are preferred, and subsequent tour destinations explore the full catalog.
On a cache miss, bundled maps of Paris, Boston and Tokyo cover online loading until
the selected viewport is complete. These maps include minor roads and water, and
only their city labels carry an asterisk (`PARIS*`, for example). An online/cached
map of the same city has no asterisk. Saved Water choices are preserved; fresh/reset
settings enable it. If a destination cannot load, the saver returns to a bundled
city. HTTP freshness rules still apply. Future-city preparation reads the local
cache only; there are no speculative network downloads of additional cities.

Choose **Line map · 3 cities · Offline** to use only the bundled maps with no network
requests. Choose **Traditional map · Worldwide** for raster OpenStreetMap imagery;
its labels and other details are part of the image and cannot be hidden independently.

All modes offer Original, Ink, Blueprint, Night, Paper and Terminal palettes. Paper
is the default. Vignette is optional; grain and tint intensity apply to traditional
maps. The camera curves through horizontal, vertical and diagonal movement, changing
city about every two minutes. City Drift targets 60 FPS and prepares vector geometry
off the animation thread to reduce tile-arrival hitches. Zero speed pauses the camera while city changes continue.
The upgrade changes the previous default line-map mode to online vectors, preserving
colors, speed and detail choices. You can select offline mode again; that selection
will persist. Reset to Defaults selects online vectors with only road lines.


## Privacy and power

Dapple, Paper Sky, Voxel Cosmos, World Clock Room and City Drift’s optional offline mode make no network requests.
The default online vector mode requests HTTPS Shortbread tiles from
`vector.openstreetmap.org`; traditional mode uses `tile.openstreetmap.org`.
Requests cover only the **selected public city**, never your location. OSM receives the
IP address and requested tile coordinates as with any tile client; its
[privacy policy](https://osmfoundation.org/wiki/Privacy_Policy) applies. There is no
analytics, telemetry, location permission, updater or configuration upload.

Tiles are cached using HTTP freshness headers and conditional requests, with a
seven-day fallback. Only the visible viewport is requested, at one zoom, with two
requests at a time and a bounded budget of 256 requests per city visit. No regions are downloaded in advance.
The next scene’s existing cache records are prepared in advance on a background
queue. New tile downloads begin only when that city becomes the selected scene;
the outgoing image stays visible until the replacement is ready. An unavailable
destination falls back to a bundled street map after 20 seconds. Cached tiles and
bundled maps also work without connectivity. No future city is downloaded in
advance from OSM’s public tile server; its service availability is best-effort.

City Drift and Paper Sky target 60 FPS; Dapple, World Clock Room and Voxel Cosmos target 30 FPS. Static clock faces and graded map tiles are cached;
Core Animation moves layers and clock hands. Online and offline vectors stay crisp at any
display resolution; their geographic viewport is capped at 1920 × 1280 (orientation-independent),
so Retina displays need no extra tile requests. Traditional maps use the display’s backing pixels
for sharper detail, capped at 3840 × 2560 pixels (rotated for portrait displays).
A 4K display renders at native resolution; 5K and larger displays scale from this
bounded detail level. Tile tasks stop with the saver. Vector responses are capped at 2 MB and decoded
off the render thread. Paper Sky uses a bounded tree of vector layers with atomic frame updates.
Cosmos reuses voxel sprites and a pixel buffer capped at 800 × 600;
nearest-neighbor enlargement keeps the pixel edges crisp. Only selected-view tiles are downloaded, following the
[vector tile policy](https://operations.osmfoundation.org/policies/vector/).
Vector and raster caches are separate; downloaded vectors are never packaged or redistributed.
