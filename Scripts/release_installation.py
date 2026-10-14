"""Shared installation text for README checks and GitHub release notes."""
import re
from urllib.parse import urlsplit

REPOSITORY = "someone-in-texas/screensavers-for-mac"
ROOT_URL = f"https://github.com/{REPOSITORY}"
START = "<!-- recommended-install:start -->"
END = "<!-- recommended-install:end -->"


def release_version(tag):
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:\.\d+)?", tag):
        raise ValueError(f"Invalid release tag: {tag}")
    return tag[1:]


def installer_url(ref="main", ai=False):
    if ref != "main":
        release_version(ref)
    script = "install-ai.sh" if ai else "install.sh"
    return f"https://raw.githubusercontent.com/{REPOSITORY}/{ref}/{script}"


def command(tag=None, ref="main", ai=False):
    suffix = f" --version {release_version(tag)}" if tag else ""
    return f"curl -fsSL {installer_url(ref, ai=ai)} | bash /dev/stdin{suffix}"


def instructions(tag=None, ref="main"):
    current_pack = tag is None or tuple(map(int, release_version(tag).split(".")[:2])) >= (0, 9)
    contents = """**Standard pack — ten screen savers:** Years in Bloom, World Clock Room,
City Drift, Voxel Cosmos, Paper Sky, Dapple, Flourish, Lattice,
Strawberry Fields Forever, and Good Research Takes Time.
Installs them in `~/Library/Screen Savers`. **Commonplace and Screensavers AI Helper
are not included**; use the separate AI installer below for those two items.

""" if current_pack else ""
    return f"""{START}
**Recommended: install from Terminal** · Apple Silicon · macOS 14.6+

Quit System Settings and stop any running screen saver, then run:

```sh
{command(tag, ref)}
```

{contents}Downloads and verifies the published release, then installs or updates its savers
for your user. Preferences and cached maps are retained. No Git, developer tools,
Homebrew, or `sudo` required. Reopen System Settings afterward.

Append `--verify-only` to check the download without installing. The optional AI
helper is not installed. [Inspect the installer]({installer_url(ref)}) before running.
{END}"""


def validate_instructions(text, tag=None, ref="main"):
    expected = instructions(tag, ref)
    if text.count(START) != 1 or text.count(END) != 1 or expected not in text:
        raise ValueError("Recommended installation block is missing or stale")
    for url in re.findall(r"https?://[^\s<>()`]+", text):
        if urlsplit(url).hostname in {"gist.githubusercontent.com", "gist.github.com"}:
            raise ValueError("Temporary gist URL must not appear in installation documentation")

AI_START = "<!-- ai-install:start -->"
AI_END = "<!-- ai-install:end -->"


def ai_instructions(tag=None, ref="main"):
    return f"""{AI_START}
**Separate AI pack: Commonplace + Screensavers AI Helper**

```sh
{command(tag, ref, ai=True)}
```

Installs only **Commonplace** in `~/Library/Screen Savers` and **Screensavers AI Helper**
in `~/Applications`, preserving notebook archives and preferences. The ten standard
savers use the main installer above; run both commands to install both packs.

The AI installer does not launch the helper or connect an account. In Commonplace Options, choose **Set Up ChatGPT** when ready. The starter
notebook and saved pages work offline. Generation requires local Codex and uses
your ChatGPT account limits; see [AI setup]({ROOT_URL}/blob/{ref}/docs/AI_HELPER.md).

Append `--verify-only` to validate without installing.
[Inspect the AI installer]({installer_url(ref, ai=True)}) before running.
{AI_END}"""


def validate_ai_instructions(text, tag=None, ref="main"):
    if text.count(AI_START) != 1 or text.count(AI_END) != 1 or ai_instructions(tag, ref) not in text:
        raise ValueError("AI pack installation block is missing or stale")
