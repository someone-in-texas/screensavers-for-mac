# Working in this repository

Native Swift/AppKit screen savers for macOS 14.6+, built with Command Line Tools.
There is no Xcode project, Swift package or dependency install step. Start with
`git status --short`, then read the narrow files relevant to the change.

## Navigate quickly

- `Shared/Settings/Settings.swift`: saver identities, typed defaults, persistence.
- `Shared/SaverCore/SceneSaverView.swift`: macOS lifecycle, viewport and configuration.
- `Savers/<Name>/`: scene and unique Objective-C `ScreenSaverView` entry point.
- `PreviewHost/main.swift`: same scenes, offline snapshots, real bundle-load smoke.
- `Scripts/build.sh`: canonical target list, arm64 bundles, generated Info.plists.
- `install.sh`: public curl installer for published releases; `Scripts/install.sh`
  remains the local source-build installer.
- `Tests/main.swift` and focused `Tests/*Tests.swift`: offline test harness.
- `AIHelper/`: optional separate app; never compiled into a saver. See
  [AI helper contract](docs/AI_HELPER.md) before changing auth or activation.

## Workflow and boundaries

`make build` builds nine savers, PreviewHost and the optional helper. `Scripts/test.sh`
runs logic/render/bundle/lifecycle tests after a build. `make release-check` also
packages and verifies DMG/ZIP, signatures, architectures and versions. These commands
do not install savers or publish releases. Use `make install` only when installation
is part of the request; it replaces the user's matching collection bundles.

Maintain the recommended curl route with every installer or release change.
Run `python3 Tests/ReleaseInstallerTests.py` and `python3 Scripts/check-installation.py`;
both are included in `Scripts/test.sh` and `make release-check`. Keep the README's
top installation block synchronized with `Scripts/release_installation.py` and use
`Scripts/release-notes.py` for release-page instructions. Release commands pin both
the script ref and installed version; the README uses the maintained main script.
Keep the public installer outside the DMG/ZIP, preserve the `/dev/stdin` entry point,
and update its saver allowlist when collection identities change. No developer-tool
dependency or Gatekeeper/quarantine mutation belongs in the public installer.
After authorized publication, run `python3 Scripts/check-installation.py --published-tag v<VERSION>`
to verify the live README, release page, raw script and curl download in verify-only
mode. The release workflow runs this check after publication too. Do not install on
the maintainer's account as part of automated checks.

Use the smallest relevant validation while iterating, then run the checks for the
scope you changed. See [validation](docs/VALIDATION.md). Keep tests offline and use
mock transports and temporary preference suites. Never reset real user preferences,
read auth tokens, or refresh maps as part of a build/test. `build/`, `dist/`, and
`planning/` are ignored; do not commit generated products or private planning.

Preserve existing identifiers, Objective-C class names, defaults and migration
behavior unless the requested change requires otherwise. The host loads multiple
bundles in one process. Scenes must stop work on `stop()`, reject late asynchronous
callbacks, use active monotonic time for animation and fit the supplied viewport.
Do not add network/auth dependencies to shared lifecycle or existing savers.

For City Drift, keep attribution visible, HTTP cache semantics and bounded request
concurrency intact. Cached startup must await full viewport geometry before revealing
it; only bundled source maps receive the `*` label. Never prefetch future cities from
the network. Starter-map data has an ODbL license separate from the code.

For a new personal saver, use [the creation skill](.agents/skills/create-screensaver/SKILL.md)
and `Scripts/new-saver.py`; the standalone route does not change collection targets.
For contribution work, use [adding a saver](docs/ADDING_A_SCREENSAVER.md).
No new collection saver is planned for 0.8. Release preparation does not imply
permission to publish, push tags, or overwrite an existing public release.

Before releasing, also run `make security-check` (online; requires uv) and wait for
CI's CodeQL/security jobs. See [security maintenance](docs/SECURITY_MAINTENANCE.md).
New dependency ecosystems need locked dependencies and a matching release audit.
Do not bypass failed scans or add broad vulnerability exclusions.
