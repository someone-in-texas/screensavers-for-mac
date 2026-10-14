# Commonplace and the optional AI pack

The standard pack contains ten savers, including Years in Bloom, and needs no AI
account or helper. The separate 0.9 AI pack contains **Commonplace.saver** and
**Screensavers AI Helper.app**. Installing either pack never starts authentication.
Commonplace plays its bundled fictional notebook and verified archival pictures
offline before setup, and keeps playing saved content when generation is unavailable.

## Set up Commonplace

Install the AI pack with the separate command in the [README](../README.md).
In Commonplace Options, choose **Set Up ChatGPT**, then **Continue with ChatGPT**
in the helper. Install the [Codex CLI](https://learn.chatgpt.com/docs/cli) separately;
the helper discovers it in standard Homebrew locations or absolute PATH entries.
It neither bundles nor downloads Codex. Generation uses your ChatGPT account's
Codex eligibility, workspace restrictions and usage limits.

The helper uses the official local [Codex app-server](https://learn.chatgpt.com/docs/app-server)
over private stdio. `account/login/start` with `type: chatgpt` opens the approved
HTTPS authorization URL in your browser. Codex owns the callback, refresh and
credential storage. The helper never reads, copies or exports tokens. This is the
managed local-app integration, not direct use of ChatGPT tokens with the OpenAI API.
The isolated protocol smoke passed against codex-cli 0.160.1 for this work; run the
isolated smoke below when upgrading because app-server evolves.

## Generation and the local notebook

The first successful connection creates five separate chronological days, ending
today. Subsequent requests create only today's missing day; there is no automatic
backfill of missed dates. Generation holds a per-user filesystem lease from request
through atomic commit, preventing competing helper processes from duplicating a day.
Malformed output, repeated recent writing, cancellation, sign-out and service errors
leave the existing notebook intact. No generation occurs inside a saver or preview.

After explicit Commonplace setup, **Add one day automatically** defaults on while
the helper runs. Turn it off to use manual generation. **Open at login** is a separate,
explicit macOS login-item opt-in; installing the AI pack does not enable it. Closing
the helper window can leave daily generation running; Quit ends it. Failed automatic
attempts wait until another day or a manual retry rather than looping requests.

The helper shows connection and generation status, a manual missing-day action,
archive access, metadata export and confirmed reset. Reset preserves old batches in
a saved lineage before creating a fresh five-day notebook. Options expose theme,
pace, density, writing, images, diagrams, verified quotations and interest weighting.
Changes to interests after setup update the helper's next request.

Content lives under `~/Library/Application Support/Screensavers for Mac/Commonplace`.
Immutable daily JSON remains on disk; playback reads a bounded recent/older sample.
Only entry/image/layout identifiers are saved as playback history. Reset never
removes authentication. **Sign Out** removes the helper account connection; deleting
a data directory alone does not remove Keychain credentials.

## Sources, attribution and fiction

The saver includes ten item-verified CC0 Cleveland Museum of Art images and three
verified public-domain extracts. Full attribution, source links and licenses are in
Options → **View Sources & Credits** and the helper's metadata export.
See [the asset catalog](../Assets/Commonplace/README.md).

After a successful generation, the helper may retrieve at most two images from
[Cleveland Open Access](https://openaccess-api.clevelandart.org/) and the
[Art Institute of Chicago API](https://api.artic.edu/docs/). It checks each item's
rights, fixed provider hosts, conservative subject filters, image dimensions and
bounded download sizes. It keeps provenance while limiting cached media to 120
files. Source failures never discard a notebook day. Conservative metadata filters
can omit usable objects and are not a complete image-content classifier.

Generated notes and original study diagrams are fictional. Model-suggested quote,
fact and image queries are discovery ideas, never verified claims. Only curated
source-backed extracts enter the quotation display. No invented patent or scientific
assertion is presented as historical evidence. No arbitrary model URL is downloaded.

## Isolation and privacy

Only the registered Commonplace identifier or explicit `--developer-test` activates
the helper. Ordinary launches connect only after the user previously enabled
Commonplace. The shared saver lifecycle and all standard savers have no auth or
model dependency. The helper has no listening server or URL scheme.

Codex runs with a separate owner-only `CODEX_HOME` under
`~/Library/Application Support/Screensavers for Mac/AI Helper/` and an empty workspace.
Keyring storage is required; there is no silent plaintext fallback. API keys and the
developer's Codex configuration are not inherited. Protocol messages, authorization
URLs and subprocess stderr are not logged. Analytics and feedback are disabled.

Threads are ephemeral, read-only, with shell/apps/code mode/web search disabled.
Every server tool or permission request is rejected. Prompts contain only dates,
Commonplace settings and its own bounded content ledger. Generation has size and
time limits; model output is decoded as data, never executed. Personal documents,
browser history, email and other apps are not read.

## Validation

```sh
make ai-helper
Scripts/test-ai-helper.sh                  # offline mocks, temporary archives
Scripts/test-ai-helper.sh --protocol-smoke # isolated signed-out CLI, no paid call
open 'build/products/Screensavers AI Helper.app' --args --developer-test
```

Offline checks cover bootstrap, dates, competing generation, large archives,
malformed content, sources, cancellation and account/error transitions. They do not
prove browser OAuth, an authenticated model response, account quota handling in the
live service or login-item behavior on every Mac. Before publishing 0.9, manually
complete sign-in, five-day generation, next-day generation, sign-out/reconnect,
missing/offline Codex and login-item checks on a clean supported Mac.
