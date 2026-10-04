---
name: validate-screensaver
description: Validate changes to this macOS screen saver collection or its standalone personal scaffold, including offline logic, rendering, native lifecycle and release artifacts. Use before delivering scene or release changes.
---

Read `AGENTS.md` and `docs/VALIDATION.md`. Determine whether this is a standalone
personal project, a collection scene change, or release preparation.

- Personal project: run its `./build.sh`, preview executable with `--smoke`, and inspect
  the preview at wide/portrait/small sizes. Do not run collection packaging.
- Collection: run `make build` and `Scripts/test.sh`. Inspect relevant PNGs under
  `build/smoke`; use PreviewHost for motion. Its `--offline` mode avoids map requests.
- Helper: run `Scripts/test-ai-helper.sh`. `--protocol-smoke` additionally requires a
  locally installed Codex CLI but never opens login or generates paid content.
  Browser sign-in and generation are separate manual tests; do not claim them from mocks.
- Release preparation: update `VERSION` and `CHANGELOG.md`, then `make release-check`.
  Inspect the actual resulting package; record actual signing/notarization status.

When a test fails, distinguish changed expectations from broken behavior. Preserve
assertions for full-viewport map readiness, asynchronous cancellation, preference
migration, start/stop, actual Mach-O bundle loading and repeated configuration sheets.
Do not replace them with source-text checks or tests that require live map services.

Report what was run, what passed, and any unperformed interactive/account-dependent
checks. Release preparation alone does not authorize installation, tagging or publishing.
