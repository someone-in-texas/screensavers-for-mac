# Troubleshooting

## Picker thumbnails and reopening Options

The bundles include real preview artwork in legacy PNG and TIFF formats. Recent
System Settings versions may still show the blue swirl: Apple confirms there is
[no supported API to replace this thumbnail](https://developer.apple.com/forums/thread/806641).
This does not affect the actual saver. We do not modify System Settings’ private caches.

Options now retains one configuration window per saver instance, explicitly detaches
and hides it on Done, and refreshes controls when reopened. If macOS is still running
a previously loaded bundle after an update, quit System Settings with ⌘Q and reopen
it. Logging out and back in reloads the legacy saver host too.
