#!/usr/bin/env python3
"""Check installation documentation offline, optionally verify a published release online."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
from urllib.request import Request, urlopen
from release_installation import REPOSITORY, command, installer_url, validate_instructions

ROOT = Path(__file__).resolve().parents[1]


def fetch(url):
    headers = {"User-Agent": "screensavers-installation-check"}
    if url.startswith("https://api.github.com/") and os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    with urlopen(Request(url, headers=headers), timeout=60) as response:
        return response.read().decode()


def check_local():
    readme = (ROOT / "README.md").read_text()
    validate_instructions(readme)
    if readme.index(command()) > readme.index("## City Drift"):
        raise ValueError("Recommended command must remain above the README gallery")
    spec = importlib.util.spec_from_file_location("release_notes", ROOT / "Scripts/release-notes.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    version = (ROOT / "VERSION").read_text().strip()
    notes = module.render(version, (ROOT / "CHANGELOG.md").read_text(), "Ad-hoc signed; not notarized.")
    validate_instructions(notes, f"v{version}", f"v{version}")
    for path in ("AGENTS.md", "docs/RELEASING.md", "docs/VALIDATION.md",
                 ".agents/skills/validate-screensaver/SKILL.md"):
        text = (ROOT / path).read_text()
        for requirement in ("Tests/ReleaseInstallerTests.py", "Scripts/check-installation.py"):
            if requirement not in text:
                raise ValueError(f"{path} must document {requirement}")
    subprocess.run(["bash", "-n", str(ROOT / "install.sh")], check=True)
    print("README command, generated release instructions, and maintenance guidance agree.", flush=True)


def check_published(tag, ref):
    release = json.loads(fetch(f"https://api.github.com/repos/{REPOSITORY}/releases/tags/{tag}"))
    if release["draft"] or release["prerelease"]:
        raise ValueError("Expected a published stable release")
    validate_instructions(release["body"], tag, ref)
    validate_instructions(fetch(f"https://raw.githubusercontent.com/{REPOSITORY}/main/README.md"))
    if fetch(installer_url(ref)) != (ROOT / "install.sh").read_text():
        raise ValueError("Published installer differs from this checkout; check out its ref before verifying")
    # Execute exactly the generated public command, in download/verification-only mode.
    # pipefail catches a missing script even when bash receives empty input.
    subprocess.run(["/bin/bash", "-o", "pipefail", "-c",
                    command(tag, ref) + " --verify-only"], check=True)
    print(f"Published README, {tag} release page, and public curl command verified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--published-tag", help="Also run online checks, without installation")
    parser.add_argument("--installer-ref", help="Default: release tag; use main for the v0.8.1 bootstrap")
    args = parser.parse_args()
    check_local()
    if args.published_tag:
        check_published(args.published_tag, args.installer_ref or args.published_tag)
