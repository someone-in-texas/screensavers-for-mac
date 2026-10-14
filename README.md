# Screensavers for Mac

Native macOS screen savers that turn idle displays into imaginative, ever-changing worlds.
Built with Swift, AppKit, Core Graphics, and Core Animation. No browser runtime. Standard savers need no dependencies; the optional AI pack uses a separate helper.

<!-- recommended-install:start -->
**Recommended: install from Terminal** · Apple Silicon · macOS 14.6+

Quit System Settings and stop any running screen saver, then run:

```sh
curl -fsSL https://raw.githubusercontent.com/someone-in-texas/screensavers-for-mac/main/install.sh | bash /dev/stdin
```

**Standard pack — ten screen savers:** Years in Bloom, World Clock Room,
City Drift, Voxel Cosmos, Paper Sky, Dapple, Flourish, Lattice,
Strawberry Fields Forever, and Good Research Takes Time.
Installs them in `~/Library/Screen Savers`. **Commonplace and Screensavers AI Helper
are not included**; use the separate AI installer below for those two items.

Downloads and verifies the published release, then installs or updates its savers
for your user. Preferences and cached maps are retained. No Git, developer tools,
Homebrew, or `sudo` required. Reopen System Settings afterward.

Append `--verify-only` to check the download without installing. The optional AI
helper is not installed. [Inspect the installer](https://raw.githubusercontent.com/someone-in-texas/screensavers-for-mac/main/install.sh) before running.
<!-- recommended-install:end -->

### Optional AI pack

<!-- ai-install:start -->
**Separate AI pack: Commonplace + Screensavers AI Helper**

```sh
curl -fsSL https://raw.githubusercontent.com/someone-in-texas/screensavers-for-mac/main/install-ai.sh | bash /dev/stdin
```

Installs only **Commonplace** in `~/Library/Screen Savers` and **Screensavers AI Helper**
in `~/Applications`, preserving notebook archives and preferences. The ten standard
savers use the main installer above; run both commands to install both packs.

The AI installer does not launch the helper or connect an account. In Commonplace Options, choose **Set Up ChatGPT** when ready. The starter
notebook and saved pages work offline. Generation requires local Codex and uses
your ChatGPT account limits; see [AI setup](https://github.com/someone-in-texas/screensavers-for-mac/blob/main/docs/AI_HELPER.md).

Append `--verify-only` to validate without installing.
[Inspect the AI installer](https://raw.githubusercontent.com/someone-in-texas/screensavers-for-mac/main/install-ai.sh) before running.
<!-- ai-install:end -->

[Installation details and DMG alternative](#install) · [Latest release](https://github.com/someone-in-texas/screensavers-for-mac/releases/latest)

## Years in Bloom — new in 0.9

A botanical journal unfolds through spring growth, summer flowers, falling leaves
and winter dormancy. Eighteen seeded plant archetypes grow persistent branches and
new seasonal foliage across five-year generations, surrounded by textured paper
and gently moving weather washes. Layered watercolor and broken pencil marks soften
the leaves, petals, and stems. Choose a specimen, grouping, meadow or woodland;
seven palettes, three speeds and seasonal emphasis shape the scene. Entirely offline.

![Years in Bloom: procedural botanical illustration](docs/images/years-in-bloom.png)

[Winter evergreen](docs/images/years-in-bloom-winter.png)

## Commonplace — separate AI pack, new in 0.9

A changing physical notebook combines short fictional observations, practical lists,
questions and callbacks with verified public-domain extracts and real CC0 archival
pictures. Six art-directed themes range from Sepia Archive to a quiet Off-World
notebook. Handwritten notes sit on gently panning desks with independently moving
pages. Saved pages and the starter book play offline; explicit ChatGPT setup in
the separate helper adds five opening days, then one new day at a time.

![Commonplace: an evolving archival notebook](docs/images/commonplace.png)

[Ultrawide notebook](docs/images/commonplace-wide.png) · [Midnight Observatory](docs/images/commonplace-observatory.png) · [Off-World](docs/images/commonplace-offworld.png)

[Architecture, art reviews and validation](docs/0.9_IMPLEMENTATION.md) · [Rendering and motion review](docs/WEATHER_AND_HANDWRITING.md) · [AI setup and privacy](docs/AI_HELPER.md)

## City Drift

Drift through the street patterns of 64 cities, drawn as crisp online vector maps.
Choose six palettes and independently show street labels, water, parks, and points
of interest. A new city arrives about every two minutes. No API key required.

Bundled Paris, Boston, and Tokyo maps provide an immediate opening and an offline
fallback. Traditional OpenStreetMap imagery is also available. Select **Line map ·
3 cities · Offline** for a completely offline experience.

![City Drift: online San Francisco with map details, © OpenStreetMap contributors](docs/images/city-drift.png)

[More map styles](docs/images/city-drift-online.png) · [Map sources and caching](docs/MAPS_AND_PERFORMANCE.md).
Map data and imagery © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

## World Clock Room

An isometric installation of ivory clocks on a charcoal floor. Twenty cities keep
real local time, with smooth hands, subtle shadows, and a slowly drifting camera.
Change the floor and clock colors, density, motion, second hands, and labels.

![World Clock Room: isometric clock floor](docs/images/world-clock-room.png)

## Voxel Cosmos

A pixel-lit solar system made of tiny shaded cubes. Tour all eight planets, Saturn’s
rings, an asteroid belt, and deep space with varied compositions and soft crossfades.

Choose from 14 views, four camera modes, and Nebula, Aurora, Stars, or Black void
backgrounds. Adjust motion, pixel size, glow, and star density. Entirely procedural
and offline; sizes and distances are artistic rather than scientific.

![Voxel Cosmos: an isometric pixel solar system](docs/images/voxel-cosmos.png)

[Saturn closeup](docs/images/voxel-cosmos-saturn.png)

## Paper Sky

An endless paper-airplane flight above sculpted clouds and synthwave sunsets.
Individually folded wings catch warm light as companions join and peel away.
The camera eases between isometric, third-person, and side-on views.

Choose a viewpoint or the changing-camera journey; select four sunset palettes or
evolving colors. Adjust flight speed, cloud cover, view duration, and glow; toggle
companions, vapor trails, and the striped sun. Procedural, crisp at every size, and entirely offline.

![Paper Sky: folded airplanes above a synthwave cloudscape](docs/images/paper-sky.png)

## Dapple

A little kinetic artwork: textured paper circles coast over invisible hills, nudge
each other, and occasionally make a playful hop. Warm pigment, fine fibers, and
soft shadows give each shape a tactile presence, with room for the eye to rest.

Choose Hills, Float, Playground, or Zen; eight curated palettes and four materials
change the mood from warm printed paper to an after-dark garden. Adjust size,
population, speed, texture, shadows, and occasional events. Start a fresh composition
each launch, repeat a daily scene, or keep a favorite seed. Entirely procedural and offline.

![Dapple: tactile circles rolling across invisible hills](docs/images/dapple.png)

[Night Garden](docs/images/dapple-night.png)

## Flourish

A botanical drawing that grows across the screen: tapered ink stems curl into
leaves, ferns, bells, and delicate blossoms, leaving generous open space. Each
composition develops over several minutes, rests, then gently gives way to another.

Choose five growth styles, eight palettes, three pen characters, paper or clean
backgrounds, a faint pigment wash, and optional breeze. Adjust growth, density,
leaves, and flowers; save a seed or let each day bring something new. Entirely offline.

![Flourish: fine botanical curls and blossoms in the Midnight palette](docs/images/flourish.png)

[Porcelain](docs/images/flourish-porcelain.png)

## Lattice

A small luminous ecosystem. Pixel colonies branch, drift, pulse, and fall dormant
while new life finds its way into the dark. Crisp cores sit above a restrained glow;
local events keep the world changing without an abrupt full-screen reset.

Four rule families—Bloom, Drift, Reef, and Signal—pair with eight palettes and
controls for activity, speed, pixel size, glow, trails, and events. Fresh, daily,
and fixed seeds make each world spontaneous or repeatable. Entirely offline.

![Lattice: bioluminescent cellular colonies in a dark pixel world](docs/images/lattice.png)

[Amber Terminal](docs/images/lattice-amber.png)

## Strawberry Fields Forever

Three procedurally shaped strawberries hang in a quiet field of paper, with
uneven leafy crowns and dark, scattered seeds. Fine roots grow downward into
angular circuit traces and tiny terminals. All three begin with bare roots.
Connected branches extend, fade and grow new paths in independent cycles while
the print gently drifts across the field, continuing through long sessions.

Choose six restrained palettes, five compositions, root-to-circuit balance,
paper/vellum/canvas surfaces, and gentle growth, breathing or signal motion.
Fresh, daily and fixed seeds make each print repeatable. Entirely offline.

![Strawberry Fields Forever: three botanical strawberries with growing roots on ivory](docs/images/strawberry-fields-forever.png)

[Museum Night](docs/images/strawberry-night.png) · [Root study](docs/images/strawberry-transition.png)

## Good Research Takes Time

A solitary blue metal folding chair anchors an unfinished architectural drawing.
Graphite routes open into chambers, turn back, and gradually find new edges across a warm
ivory field. Connected branches grow, fade and renew their architecture independently; the chair
changes orientation between quiet rests as the whole drawing gently drifts.

Five quiet palettes, five drawing styles, four line characters, and open or denser
compositions. Choose a still chair, occasional turns, or a very slow change of angle;
save a seed or let each day bring a new drawing. Entirely offline and silent.

![Good Research Takes Time: a blue chair and an unfinished architectural drawing on ivory](docs/images/good-research-takes-time.png)

[Charcoal study](docs/images/research-chair.png) · [Blueprint study](docs/images/research-archive.png)

## Install

Use the recommended Terminal command at the top of this page. Rerun it to update
to the latest published stable release. To choose a release, append
`--version 0.8.1` after `/dev/stdin`; append `--verify-only` to download and check
without installing. The installer verifies the release ZIP checksum, bundle
identifiers, versions, signatures and Apple Silicon architecture before replacing
matching bundles. Failed replacements roll back to the previous bundles.

The command downloads the repository's maintained `main/install.sh`; the savers
come from published release assets. It does not build or install unreleased scenes.
It does not change Gatekeeper settings or remove quarantine attributes. Terminal
`curl` downloads normally avoid browser-added quarantine, but this does not make
an ad-hoc release notarized or guarantee every Mac's security policy will allow it.

### Alternative: DMG or ZIP

1. Download the **DMG** from [Releases](https://github.com/someone-in-texas/screensavers-for-mac/releases).
2. Open it and double-click each `.saver`. Choose installation for the current user.
3. Open **System Settings → Wallpaper → Screen Saver** (or **Screen Saver** on older
   macOS). Under **Other → Show All**, select a saver and open **Options / Screen Saver Options**.

The standard ZIP contains ten savers. The separate AI ZIP contains Commonplace and its helper. To verify downloads, place the DMG, ZIP,
and `SHA256SUMS` in one directory and run `shasum -a 256 -c SHA256SUMS` there.

Releases without Apple signing credentials are **ad-hoc signed, not notarized**.
If macOS blocks a downloaded saver, verify its source and checksum, then use
**System Settings → Privacy & Security → Open Anyway** for that item if offered.
See [Troubleshooting](docs/TROUBLESHOOTING.md) for picker thumbnails and refreshing an installed saver.

To remove a saver, delete its bundle from `~/Library/Screen Savers/`, or run
`make uninstall`. Preferences and cached maps are retained.

## Build and preview

Use current Xcode or Apple’s Command Line Tools on an Apple Silicon Mac.

```sh
git clone https://github.com/someone-in-texas/screensavers-for-mac.git
cd screensavers-for-mac
make build       # eleven .saver bundles, PreviewHost.app and the helper in build/products
make test        # deterministic offline tests, bundle loading, and renderer checks
make preview     # switch savers, configure, resize, or save a frame
Scripts/build-preview.sh # build only PreviewHost.app
Scripts/run-preview.sh   # launch it; build first if missing
Scripts/run-preview.sh --bloom-review --offline # Years in Bloom
Scripts/run-preview.sh --commonplace-review --offline # Commonplace
open build/products/PreviewHost.app --args --dapple
make install     # rebuild and install for the current user
make package     # DMG, ZIP, and SHA256SUMS in dist
```

Quit PreviewHost before rebuilding. After reinstalling, quit and reopen System
Settings so it can load the updated bundles.

## Privacy and power

Strawberry Fields Forever, Good Research Takes Time, Flourish, Lattice, Dapple, Paper Sky,
Voxel Cosmos, and World Clock Room are entirely offline.
City Drift’s online modes request OpenStreetMap tiles for the selected public city,
never your location; offline mode makes no requests. No analytics, telemetry,
location permission, updater, or configuration upload.

Strawberry Fields Forever, Good Research Takes Time, Flourish, Lattice, Dapple, World Clock Room,
and Voxel Cosmos target 30 FPS; City Drift and Paper Sky
target 60 FPS. Geometry, textures, and map tiles are cached. See
[map policies and rendering details](docs/MAPS_AND_PERFORMANCE.md).

## Contribute

[Contributing](CONTRIBUTING.md) · [Architecture](docs/ARCHITECTURE.md) ·
[Add a saver](docs/ADDING_A_SCREENSAVER.md) · [Releasing](docs/RELEASING.md) ·
[Validation](docs/VALIDATION.md) · [Security](SECURITY.md)

Report map issues at [OpenStreetMap](https://www.openstreetmap.org/fixthemap), and
project bugs through [GitHub Issues](https://github.com/someone-in-texas/screensavers-for-mac/issues).

Code: [MIT](LICENSE). Map data, imagery and fonts: [Third-party notices](THIRD_PARTY_NOTICES.md).

## Agents and personal screen savers

Use [AGENTS.md](AGENTS.md), the [reusable skills](SKILLS.md), and the
[agent development guide](docs/AGENT_DEVELOPMENT.md) to contribute efficiently or
create your own standalone saver with `Scripts/new-saver.py`. Personal projects
need not be contributed back. The [optional AI helper](docs/AI_HELPER.md) provides
ChatGPT sign-in and daily content generation for Commonplace. The ten standard
savers do not use or require it.
