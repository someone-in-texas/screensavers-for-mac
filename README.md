# Screensavers for Mac

Two quiet, native screen savers for people who like clocks, cities and the geometry
of everyday things. Written in Swift, AppKit, Core Graphics and Core Animation.
No browser runtime. No dependencies.

**[Download v0.2.0](https://github.com/someone-in-texas/screensavers-for-mac/releases/latest)** ·
Apple Silicon · macOS 14.6 or later

## World Clock Room

An isometric installation of ivory clocks on a charcoal floor. Twenty cities keep
real local time, with smooth hands, subtle shadows and a slowly drifting camera.
Change the floor and clock colors with native color pickers, or adjust density,
motion, second hands and labels.

![World Clock Room: isometric clock floor](docs/images/world-clock-room.png)

## City Drift

City Drift defaults to **solid road lines**, drawn as crisp vectors with no tile
loading and no network requests. Paris, Boston and Tokyo are included in the bundle.
In Options, enable **Street labels**, **Water**, **Parks**, and **Points of interest**
independently. These are simplified major-road maps, not navigation maps; coastal
water coverage and points of interest follow the bundled extracts.

Choose **Traditional map · Worldwide** for the original detailed map and its
64-city catalog. This mode uses OpenStreetMap imagery, so its street labels and
other features are part of the image and cannot be switched off independently.
It starts with a bundled map, reuses complete eligible cached cities when available,
and keeps the outgoing scene visible while preparing the next one.

Both styles offer Original, Ink, Blueprint, Night, Paper and Terminal palettes.
Paper is the default. Vignette is optional; grain and tint intensity apply to the
traditional map. The camera curves through horizontal, vertical and diagonal
movement, changing city about every four minutes. Zero speed pauses the camera,
while city changes continue. Existing color/speed preferences survive the update;
Reset to Defaults selects the minimal line map.

![City Drift: Paris in the Paper palette, © OpenStreetMap contributors](docs/images/city-drift.png)

[See Blueprint](docs/images/city-drift-blueprint.png) · [Optional map details](docs/images/city-drift-details.png). Map data and imagery
© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

## Install

1. Download the **DMG** from [Releases](https://github.com/someone-in-texas/screensavers-for-mac/releases).
2. Open it and double-click each `.saver`. Choose installation for the current user.
3. Open **System Settings → Wallpaper → Screen Saver** (or **Screen Saver** on older
   macOS). Under **Other → Show All**, select a saver, and open **Options / Screen Saver Options** to configure it.

The ZIP contains the same two bundles. For checksums, download the DMG, ZIP and
`SHA256SUMS` into one directory and run `shasum -a 256 -c SHA256SUMS` there.

**v0.2.0 is ad-hoc signed, not Apple-notarized.** If macOS blocks opening a downloaded
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
make build       # both .saver bundles and PreviewHost.app in build/products
make test        # deterministic, offline tests + bundle and renderer smoke checks
make preview     # switch savers, resize, configure, go full screen, save a frame
make install     # build and install into ~/Library/Screen Savers
make package     # DMG, ZIP and SHA256SUMS in dist
```

Quit PreviewHost before rebuilding. During development, quit and reopen System
Settings after replacing an installed bundle; macOS may retain an older loaded
module. If it persists, log out and back in. The scripts do not kill system processes.

## Privacy and power

World Clock Room and City Drift’s default line-map style are entirely offline.
City Drift’s optional traditional style requests HTTPS street tiles from
OpenStreetMap for the **displayed public city**, never your location. OSM receives the
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

Animation is capped at 30 FPS. Static clock faces and graded map tiles are cached;
Core Animation moves layers and clock hands. Line maps stay vector-based at any
display resolution. Traditional maps use the display’s backing pixels
for sharper detail, capped at 3840 × 2560 pixels (rotated for portrait displays).
A 4K display renders at native resolution; 5K and larger displays scale from this
bounded detail level. Tile tasks stop with the saver.

## Contribute

[Contributing](CONTRIBUTING.md) · [Architecture](docs/ARCHITECTURE.md) ·
[Add a third saver](docs/ADDING_A_SCREENSAVER.md) · [Releasing](docs/RELEASING.md) ·
[Validation notes](docs/VALIDATION.md)

Report map issues at [OpenStreetMap](https://www.openstreetmap.org/fixthemap), and
project bugs through [GitHub Issues](https://github.com/someone-in-texas/screensavers-for-mac/issues).

Code: [MIT](LICENSE). Map data and imagery have separate terms in
[Third-party notices](THIRD_PARTY_NOTICES.md).
