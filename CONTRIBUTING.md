# Contributing

Use an Apple Silicon Mac with macOS 14.6+ and current Xcode or Command Line Tools.
No package manager or external library is needed.

```sh
make build
make test
make preview
```

Edit Swift files directly, then rebuild. The preview app uses the same scenes,
settings and ScreenSaverView wrapper as the installed modules. Its controls switch
scenes, open native configuration sheets and enter full screen. Quit the old preview
before rebuilding. `make install` installs only for your user; `make uninstall`
removes the nine bundles and preserves preferences/cache.

Keep PRs focused. Describe visible behavior and validation. Include screenshots for
visual changes, test boundary cases for time/map/cache changes, and keep automated
tests offline. Check small previews, portrait and wide screens. Preserve low motion,
readable OSM attribution, limited requests and cancellation when stopped. Do not
add tile prefetch or introduce dependencies without a clear need.

See [architecture](docs/ARCHITECTURE.md),
[adding a saver](docs/ADDING_A_SCREENSAVER.md) and [releasing](docs/RELEASING.md).

For agent-assisted contributions or a private standalone saver, see
[agent development](docs/AGENT_DEVELOPMENT.md) and [skills](SKILLS.md).
