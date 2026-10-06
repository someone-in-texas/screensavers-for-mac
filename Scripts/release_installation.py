"""Shared installation text for README checks and GitHub release notes."""
import re

REPOSITORY = "someone-in-texas/screensavers-for-mac"
ROOT_URL = f"https://github.com/{REPOSITORY}"
START = "<!-- recommended-install:start -->"
END = "<!-- recommended-install:end -->"


def release_version(tag):
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:\.\d+)?", tag):
        raise ValueError(f"Invalid release tag: {tag}")
    return tag[1:]


def installer_url(ref="main"):
    if ref != "main":
        release_version(ref)
    return f"https://raw.githubusercontent.com/{REPOSITORY}/{ref}/install.sh"


def command(tag=None, ref="main"):
    suffix = f" --version {release_version(tag)}" if tag else ""
    return f"curl -fsSL {installer_url(ref)} | bash /dev/stdin{suffix}"


def instructions(tag=None, ref="main"):
    return f"""{START}
**Recommended: install from Terminal** · Apple Silicon · macOS 14.6+

Quit System Settings and stop any running screen saver, then run:

```sh
{command(tag, ref)}
```

Downloads and verifies the published release, then installs or updates its savers
for your user. Preferences and cached maps are retained. No Git, developer tools,
Homebrew, or `sudo` required. Reopen System Settings afterward.

Append `--verify-only` to check the download without installing. The optional AI
helper is not installed. [Inspect the installer]({installer_url(ref)}) before running.
{END}"""


def validate_instructions(text, tag=None, ref="main"):
    expected = instructions(tag, ref)
    if text.count(START) != 1 or text.count(END) != 1 or expected not in text:
        raise ValueError("Recommended installation block is missing or stale")
    if "gist.githubusercontent.com" in text or "gist.github.com" in text:
        raise ValueError("Temporary gist URL must not appear in installation documentation")
