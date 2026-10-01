#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(git remote get-url origin)" == 'https://github.com/someone-in-texas/screensavers-for-mac.git' || "$(git remote get-url origin)" == 'git@github.com:someone-in-texas/screensavers-for-mac.git' ]]
git diff --check
[[ -s LICENSE && -s README.md ]]
[[ "$(cat VERSION)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
if git grep -n -E '/Users/[^/]+/|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{30}' -- ':!Scripts/release-check.sh'; then
    echo 'Unexpected private path or credential-like text in tracked files.' >&2; exit 1
fi
Scripts/build.sh
Scripts/test.sh
SKIP_BUILD=1 Scripts/package.sh
Scripts/verify-package.sh
