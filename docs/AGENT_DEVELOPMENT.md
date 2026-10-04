# Developing with agents

Start an agent in this checkout and let it read [AGENTS.md](../AGENTS.md).
[SKILLS.md](../SKILLS.md) lists portable repository-local workflows. They support
personal projects as well as contributions; no ChatGPT account is needed to build,
preview or run an ordinary saver.

## Make your own

```sh
python3 Scripts/new-saver.py --name 'Quiet Orbit' --identifier net.example.quietorbit --output ../quiet-orbit
cd ../quiet-orbit
./build.sh
build/Preview.app/Contents/MacOS/Preview --smoke
open build/Preview.app
```

Ask your agent to turn `Scene.swift` into your idea, e.g. “Make a quiet constellation
of moving shapes, fit portrait and wide screens, and keep it offline.” The generated
project is independent and contains its own agent instructions, native wrapper,
preview app and build script. It uses macOS frameworks only. Use your own permanent
identifier; the generator refuses to overwrite an output directory or use the
collection's namespace. Run `python3 Scripts/new-saver.py --help` for arguments.

Once you like it, double-click `build/Quiet Orbit.saver` and install for your user.
You can keep it private forever. Source/artwork stays yours under the repository's
MIT terms. Do not copy ODbL map assets without preserving their separate license.
Ad-hoc signing is suitable for local development; distribution/signing needs its
own review. The scaffold supplies a working starting point, not a polished design.

## Work on the collection

Use `rg --files Savers Shared Tests Scripts` to locate the area. Read
[architecture](ARCHITECTURE.md), then the relevant scene and tests. The shared
wrapper handles macOS lifecycle and preview geometry. Prefer local scene changes
over broad shared refactors for an isolated visual fix.

```sh
make build
Scripts/test.sh
python3 Scripts/test-scaffold.py   # compiles a disposable personal project
Scripts/test-ai-helper.sh         # offline protocol/state-machine mocks
make release-check                # includes artifacts and package validation
```

Build output lives in ignored `build/`; release artifacts live in `dist/`. The
scaffold test creates a temporary project and removes it without installing it.
The preview smoke harness loads real bundles and uses isolated preferences. Check
actual images/motion as well as assertions; compilation cannot validate artwork.

To contribute a personal experiment later, port its scene to `SaverScene` and follow
[all registration steps](ADDING_A_SCREENSAVER.md), including settings, factory,
preview, build, install/uninstall, packaging and verification. Do not change those
lists just to make a private saver. For future AI content, read the
[optional helper contract](AI_HELPER.md); existing savers have no AI dependency.
