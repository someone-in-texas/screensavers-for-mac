#!/usr/bin/env python3
"""Generate release notes with version-pinned installation instructions."""
import argparse
from pathlib import Path
from release_installation import ROOT_URL, instructions, validate_instructions


def render(version, changelog, signing):
    section = changelog.split(f"## {version}\n", 1)[1].split("\n## ", 1)[0].strip()
    tag = f"v{version}"
    notes = f"Screensavers for Mac {version} · Apple Silicon · macOS 14.6+\n\n"
    notes += instructions(tag, tag) + "\n\n" + section + "\n\n"
    notes += ("Alternative: download the DMG or ZIP below. Both contain the screen savers "
              "and separate optional AI helper. Verify downloads with "
              "`shasum -a 256 -c SHA256SUMS`.\n\n")
    notes += signing.strip() + f"\n\nSee the [README]({ROOT_URL}#install) for installation and troubleshooting.\n"
    validate_instructions(notes, tag, tag)
    return notes


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist/release-notes.md"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    notes = render((root / "VERSION").read_text().strip(),
                   (root / "CHANGELOG.md").read_text(),
                   (root / "dist/SIGNING.txt").read_text())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(notes)
