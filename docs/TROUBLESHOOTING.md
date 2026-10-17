# Troubleshooting

## Downloaded saver blocked by Gatekeeper

Try the [recommended Terminal installer](../README.md#screensavers-for-mac), which
downloads and verifies the published ZIP and installs matching bundles for your
user. It needs no developer tools and preserves preferences and cached maps.
Append `--verify-only` to its command to check downloads without installing.
It does not disable Gatekeeper or remove quarantine attributes; the release's
documented signing/notarization status still applies. If it fails, retain the
Terminal error and macOS version when reporting the issue.

## Picker thumbnails and reopening Options

The bundles include real preview artwork in legacy PNG and TIFF formats. Recent
System Settings versions may still show the blue swirl: Apple confirms there is
[no supported API to replace this thumbnail](https://developer.apple.com/forums/thread/806641).
This does not affect the actual saver. We do not modify System Settings’ private caches.

Options now retains one configuration window per saver instance, explicitly detaches
and hides it on Done, and refreshes controls when reopened. If macOS is still running
a previously loaded bundle after an update, quit System Settings with ⌘Q and reopen
it. Logging out and back in reloads the legacy saver host too.

## Adjusting Options and reporting problems

Options apply and save changes as controls are committed. On smaller displays,
settings scroll while Done, Restore Defaults, and Revert Changes remain visible. **Revert Changes** restores the settings
from when that sheet was opened, including after **Restore Defaults**. **Done** keeps
your changes; reopening Options begins a new revert point. This changes only saver
preferences, not cached maps, notebook archives, or account setup.

Seeded savers let you enter an unsigned whole-number seed or choose a new one.
A fixed seed repeats the starting composition, not the current animation frame.
Invalid input shows a message and leaves the last saved seed intact; correct it or
revert before choosing Done. In Years in Bloom, enable **Repeat composition** to
reuse a fixed seed, or choose **New Composition** to generate and keep a new one.
Fresh compositions on each launch remain the default.

Each Options sheet shows the loaded version. **Copy Support Info** copies the saver
name, loaded version, macOS version, and the size and scale of the display hosting
Options. Include this text and a description of the problem in a bug report. It
contains no account information, interests, notebook content, or filesystem paths.
