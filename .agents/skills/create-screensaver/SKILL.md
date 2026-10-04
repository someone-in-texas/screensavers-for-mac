---
name: create-screensaver
description: Create a native macOS screen saver using this repository's standalone personal scaffold, or integrate a requested new collection saver. Use for personal customization and new saver development; not ordinary fixes to existing scenes.
---

Read `AGENTS.md` at the repository root and respect the requested destination and
scope. A personal saver does not require an upstream contribution, AI login, or
changes to the collection's target lists.

For personal use, run from the repository root:

```sh
python3 Scripts/new-saver.py --name 'Quiet Orbit' --identifier net.example.quietorbit --output ../quiet-orbit
```

Choose an unused output directory, unique reverse-DNS identifier and title made of
ASCII letters/digits/spaces starting with a capital letter. The script rejects
existing directories and collection identifiers. Inspect its generated `AGENTS.md`.
Edit `Scene.swift` to implement the user's visual idea; the moving circle is only a
starting point. Keep `View.swift` as the thin native host and `main.swift` as a preview
of the same scene. Add persistent options only if useful to the requested design.
Do not insert this personal project into the collection.

Build with `./build.sh` in the generated directory. Run
`build/Preview.app/Contents/MacOS/Preview --smoke`, then open `build/Preview.app` to
inspect artwork, motion, resizing, portrait and small views. Tell the user where the
`.saver` is; install it only if requested. Personal source/build output stays local.

If the user explicitly wants a collection contribution, follow
`docs/ADDING_A_SCREENSAVER.md` for all registration sites and use the collection's
`SaverScene` lifecycle/settings conventions. Read a nearby scene with the same
rendering strategy rather than copying a large unrelated scene. Validate with
`docs/VALIDATION.md`. Preserve existing saver identities and behavior.
