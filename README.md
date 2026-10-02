# Screensavers for Mac

Native macOS screen savers that turn idle displays into imaginative, ever-changing worlds. Written in Swift, AppKit, Core Graphics and Core Animation.
No browser runtime. No dependencies.

**[Download latest release](https://github.com/someone-in-texas/screensavers-for-mac/releases/latest)** ·
Apple Silicon · macOS 14.6 or later

Source version **0.5.0** adds Paper Sky, varied Cosmos compositions and stable voxel frames.

## Paper Sky

An endless paper-airplane flight above sculpted clouds and synthwave sunsets.
Ivory wings catch peach and violet light as other folded airplanes drift into
formation and peel away. A striped sun hangs above layers of gently moving clouds.

The journey eases between isometric, third-person perspective and side-on views.
Choose a fixed viewpoint or the changing-camera journey; select Afterglow, Coral,
Violet, Lagoon, or slowly evolving sunset colors. Adjust flight speed, cloud cover,
view duration (20–120 seconds) and glow; toggle companions, vapor trails and the sun.
Cloud silhouettes and formations are seeded anew for each launch. Clouds keep their
place in a shared 3D field as the camera turns, with mist-soft undersides and warm
crest light. The sun drifts along a slow arc; aircraft have individual wing shapes,
paper tints and banking rhythms, with light catching their folds. Vector geometry
stays crisp at every screen size. Entirely procedural and offline, with no image assets.
Zero speed holds flight and colors while timed camera changes continue.

![Paper Sky: folded airplanes above a synthwave cloudscape](docs/images/paper-sky.png)

## Voxel Cosmos

A pixel-lit solar system made of tiny shaded cubes. The grand tour moves between
isometric system views, all eight planet closeups, an asteroid belt and deep space,
with stable pixel framing and soft whole-frame crossfades. Saturn’s layered rings, icy moons, colorful
planet surfaces and a distant comet give each scene its own character.

Choose from 14 view modes, four camera modes and four backgrounds: Nebula, Aurora,
Stars or Black void. Compositions alternate between the center and all four quadrants,
or can be pinned to your preferred position. Adjust view duration (15–120 seconds), motion, pixel size,
subtle glow and star density; toggle orbit guides, asteroids and captions. Fixed
subjects can cycle through camera angles too. Zero motion stops drift while timed
view changes continue. Sizes, distances and surfaces are artistic, not a scientific
simulation. All artwork is generated locally; no assets or network downloads.

![Voxel Cosmos: an isometric pixel solar system](docs/images/voxel-cosmos.png)

[Saturn closeup](docs/images/voxel-cosmos-saturn.png)

## World Clock Room

An isometric installation of ivory clocks on a charcoal floor. Twenty cities keep
real local time, with smooth hands, subtle shadows and a slowly drifting camera.
Change the floor and clock colors with native color pickers, or adjust density,
motion, second hands and labels.

![World Clock Room: isometric clock floor](docs/images/world-clock-room.png)

## City Drift

City Drift defaults to **online vector maps across all 64 cities**: solid road
lines, drawn natively at your display’s resolution. No API key is required.
In Options, enable **Street labels**, **Water**, **Parks**, and **Points of interest**
independently. The online source includes local streets as well as major roads.

Bundled maps of Paris, Boston and Tokyo provide an immediate opening scene. Online
geometry replaces them only after the current viewport is complete; cached vector
cities can also open the next session. If a new destination cannot load, the saver
returns to a bundled city. Previously viewed tiles are reused according to their
HTTP cache policy. New online sessions choose from the full catalog instead of
repeatedly downloading the three bundled cities. Online cached openings skip the recent history so short sessions can discover new
cities too; offline previews can still reuse any complete cached city. The bundled map remains correctly labeled while the
selected destination loads. Future-city preparation reads the local cache only;
OSM’s public services prohibit speculative downloads of additional cities.

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

![City Drift: Paris in the Paper palette, © OpenStreetMap contributors](docs/images/city-drift.png)

[Online London with details](docs/images/city-drift-online.png) · [See Blueprint](docs/images/city-drift-blueprint.png) · [Optional map details](docs/images/city-drift-details.png). Map data and imagery
© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

## Install

1. Download the **DMG** from [Releases](https://github.com/someone-in-texas/screensavers-for-mac/releases).
2. Open it and double-click each `.saver`. Choose installation for the current user.
3. Open **System Settings → Wallpaper → Screen Saver** (or **Screen Saver** on older
   macOS). Under **Other → Show All**, select a saver, and open **Options / Screen Saver Options** to configure it.

The ZIP contains the same three bundles. For checksums, download the DMG, ZIP and
`SHA256SUMS` into one directory and run `shasum -a 256 -c SHA256SUMS` there.

**Local builds are ad-hoc signed, not Apple-notarized.** If macOS blocks opening a downloaded
saver, check the source/checksum, attempt to open that saver, then use **System Settings
→ Privacy & Security → Open Anyway** for that item if offered. Never disable Gatekeeper
globally. Managed Macs may prohibit third-party savers; a local source build is another
option. Future releases can use Developer ID signing and notarization without source changes.

To remove a saver, delete its bundle from `~/Library/Screen Savers/`, or run
`make uninstall` from this repository. Preferences and cached maps are retained.

### Picker thumbnails and reopening Options

The bundles include real preview artwork in legacy PNG and TIFF formats. Recent
System Settings versions may still show the blue swirl: Apple confirms there is
[no supported API to replace this thumbnail](https://developer.apple.com/forums/thread/806641).
This does not affect the actual saver. We do not modify System Settings’ private caches.

Options now retains one configuration window per saver instance, explicitly detaches
and hides it on Done, and refreshes controls when reopened. If macOS is still running
a previously loaded bundle after an update, quit System Settings with ⌘Q and reopen
it. Logging out and back in reloads the legacy saver host too.

## Build and preview

Use current Xcode or Apple's Command Line Tools on an Apple Silicon Mac. The scripts
compile directly with the installed Swift compiler and macOS SDK, so full Xcode and
project-generation tools are optional.

```sh
git clone https://github.com/someone-in-texas/screensavers-for-mac.git
cd screensavers-for-mac
make build       # all three .saver bundles and PreviewHost.app in build/products
make test        # deterministic, offline tests + bundle and renderer smoke checks
make preview     # switch savers, resize, configure, go full screen, save a frame
# Or launch directly into the new saver:
open build/products/PreviewHost.app --args --cosmos
open build/products/PreviewHost.app --args --paper
make install     # build and install into ~/Library/Screen Savers
make package     # DMG, ZIP and SHA256SUMS in dist
```

Quit PreviewHost before rebuilding. During development, quit and reopen System
Settings after replacing an installed bundle; macOS may retain an older loaded
module. If it persists, log out and back in. The scripts do not kill system processes.

## Privacy and power

Paper Sky, Voxel Cosmos, World Clock Room and City Drift’s optional offline mode make no network requests.
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

City Drift and Paper Sky target 60 FPS; World Clock Room and Voxel Cosmos target 30 FPS. Static clock faces and graded map tiles are cached;
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

## Contribute

[Contributing](CONTRIBUTING.md) · [Architecture](docs/ARCHITECTURE.md) ·
[Add a saver](docs/ADDING_A_SCREENSAVER.md) · [Releasing](docs/RELEASING.md) ·
[Validation notes](docs/VALIDATION.md)

Report map issues at [OpenStreetMap](https://www.openstreetmap.org/fixthemap), and
project bugs through [GitHub Issues](https://github.com/someone-in-texas/screensavers-for-mac/issues).

Code: [MIT](LICENSE). Map data and imagery have separate terms in
[Third-party notices](THIRD_PARTY_NOTICES.md).
