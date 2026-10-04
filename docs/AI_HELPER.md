# Optional AI helper (0.8 developer foundation)

All nine screen savers work without this app, Codex, an account, or an AI connection.
No current saver launches the helper or displays a sign-in option. A normal helper
launch only explains that there is nothing to connect. It is shipped under
`Optional/` in the release; the saver installer does not install it.

## Supported integration

The separate native app uses the official local **Codex app-server** over private
stdio. “Continue with ChatGPT” sends `account/login/start` with `type: chatgpt` and
opens its HTTPS authorization URL in the user's browser. Codex owns the callback,
token refresh and credential storage; the helper never reads or copies tokens.
This is Codex-backed ChatGPT authentication, not a general third-party OAuth client
or direct use of ChatGPT tokens with the OpenAI API. Account eligibility, workspace
restrictions and Codex usage limits still apply.

Install the [Codex CLI](https://learn.chatgpt.com/docs/cli) separately. The helper
checks Homebrew's usual locations and absolute PATH entries. It neither downloads
nor bundles Codex. Its protocol was checked with `codex-cli 0.160.0`; an incompatible
version produces an error without affecting any saver. See the
[official app-server documentation](https://learn.chatgpt.com/docs/app-server),
particularly initialization, authentication, threads and turns. Credential storage
and feature controls follow the official [authentication](https://learn.chatgpt.com/docs/auth)
and [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference). The app-server
command is still evolving; recheck compatibility before adding an AI saver.

## Test it

```sh
make ai-helper
Scripts/test-ai-helper.sh                  # fully offline mocks; no Codex needed
Scripts/test-ai-helper.sh --protocol-smoke # real CLI, isolated signed-out account
open 'build/products/Screensavers AI Helper.app' --args --developer-test
```

The explicit developer mode is the only sign-in entry in 0.8. Click **Continue with
ChatGPT**, complete browser sign-in, then **Generate Test Content**. The latter sends
one fixed request for a short original calming sentence, using the account's limits.
It keeps the result in memory and does not install, change or feed any current saver.
No requests run automatically, on a timer, or from the screen saver host.

Manual acceptance checklist (requires an eligible account and browser interaction):

- Complete sign-in; generate a sentence and see “Test complete”.
- Cancel sign-in and retry; close the helper during login/generation.
- Relaunch developer mode to verify saved sign-in and refresh behavior.
- Sign out, then relaunch to verify the account is disconnected.
- Check missing Codex, offline service, account restrictions and exhausted limits.
- Open the helper normally and each current saver: no sign-in control appears.

Offline tests exercise these state/error paths with mock messages. Protocol smoke
checks the installed CLI's initialization, account/read and thread configuration against a temporary
isolated home. Neither proves a successful browser OAuth flow or an authenticated
model response; record those separately when performed. CI never requires credentials.

## Isolation and privacy

The helper starts a child only after an allowed activation. It has no login item,
daemon, URL scheme, listening server, automatic startup or shared saver dependency.
Quit/cancel terminates its child and fails pending work. RPC, login and generation
have deadlines; stale login IDs and unrelated thread messages are ignored. Only
HTTPS auth URLs on `auth.openai.com` or `chatgpt.com` are opened.

Codex uses a separate `CODEX_HOME` under
`~/Library/Application Support/Screensavers for Mac/AI Helper/`, with owner-only
directory permissions and a dedicated empty workspace. Keyring credential storage
is required; failure does not silently fall back to plaintext auth files. The child
does not inherit API keys or the developer's Codex configuration/home. The helper
does not log protocol messages, auth URLs or subprocess stderr. Analytics and
feedback are disabled for its Codex child.

Test threads are ephemeral, read-only, have shell/apps/code-mode/web-search disabled,
and reject every server tool/permission request. Generated text is bounded and
shown as plain text. The helper does not expose general agent execution or execute
model output. OpenAI processes the test prompt and response under the user's account
terms. To remove the helper's credentials, use **Sign Out** before deleting the app;
deleting its data directory alone does not remove Keychain credentials.

## Contract for a future AI saver

`AIHelper/HelperSession.swift` contains an intentionally empty `AIActivation` allowlist.
A future release can register a specific AI saver identifier and open this helper
from that saver's explicit setup/activation using `--ai-saver <identifier>`. Keep the
check ahead of process creation and never put it in `SceneSaverView`, the common
settings controller, or a non-AI saver. A saver name or arbitrary command-line flag
must not be sufficient to activate authentication.

Before shipping that integration, add a typed bounded content format, per-saver
atomic content cache and freshness policy, and an offline rendering fallback. Fetch
content only through the helper during explicit setup; savers consume validated
content without tokens or model execution inside the macOS screen saver host. Add
integration tests for missing helper/Codex, revoked auth, malformed output, quota,
network failure, cancellation and offline rendering. The 0.8 helper establishes
and tests sign-in plus a sample generation path; a background content service or
production AI saver is not part of this release.
