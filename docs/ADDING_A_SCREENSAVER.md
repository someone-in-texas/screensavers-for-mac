# Adding a screen saver

For a private standalone saver, start with [the personal scaffold](AGENT_DEVELOPMENT.md).
The steps below integrate a new saver into the distributed collection.

1. Create `Savers/YourSaver/YourScene.swift` implementing `SaverScene`: `start()`,
   `stop()`, `apply(_:)`, and `draw(in:size:time:date:)`. Use the monotonic time for
   motion and the Date only for real-world time. Cancel every task when stopped.
   Render within the supplied size; avoid frame-specific expensive allocations.
   Override `updateLayer` for efficient Core Animation presentation, or inherit the
   default bitmap fallback. Keep both paths visually consistent for smoke snapshots.
2. Add a `SaverKind` case, display name and permanent reverse-DNS identifier.
   Add a scene factory branch in `SceneSaverView` and the preview delegate.
   Keep saver-specific behavior in the scene, not the shared wrapper.
3. Add a thin `YourSaverView.swift` entry point, following an existing saver. Give it
   a **unique** `@objc` class name and an `@objc(initWithFrame:isPreview:)` initializer.
   Bundle principal classes must not collide in macOS's shared screen saver host.
4. Extend the typed settings and native configuration controller as needed. Persist
   through `SettingsStore` for the new module. Default invalid/missing values safely.
   For a different schema, create a small dedicated settings value/store using the
   same namespace pattern instead of adding unrelated fields forever.
5. Add the module to `Scripts/build.sh`'s target loop with its display name and bundle
   identifier. The script compiles shared sources, selects its entry point, emits a
   Mach-O bundle and writes Info.plist. Keep `CFBundleExecutable`, `NSPrincipalClass`,
   package type BNDL, macOS minimum and `VERSION` consistent. No Xcode project generation
   is needed; the script's module entry is the build target.
6. Add it to install/uninstall, packaging and verification lists. Update the whitelist
   in uninstall, the Make/preview behavior and the release notes. Do not ship unrelated
   bundles with the same name or change an existing saver identifier.
7. Add deterministic logic tests in `Tests/main.swift`. Add offline frames and actual
   bundle-loading checks in PreviewHost's smoke mode. Test settings extremes, small
   previews, portrait/wide windows, repeated start/stop, no network and resizing.
8. Run `make release-check`. Inspect the images in `build/smoke`, and use `make preview`
   for motion/performance review. Add a real screenshot to the README and document any
   new network/privacy behavior. Keep dependencies and entitlements minimal.
