#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v uv >/dev/null || { echo 'Install uv to run the online security checks.' >&2; exit 1; }
mkdir -p build/security build/security-tools
python3 Tests/SecurityGateTests.py
uv tool run --python 3.12 --from pip-audit==2.10.1 pip-audit \
    --require-hashes --strict -r Scripts/security/requirements.txt \
    --format json --output build/security/dependencies.json
uv tool run --from zizmor==1.16.3 zizmor --offline --min-severity low .github/workflows

# Pin both the scanner version and its archive digest, not a moving install script.
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) platform=darwin_arm64; digest=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
    Darwin-x86_64) platform=darwin_x64; digest=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709 ;;
    Linux-x86_64) platform=linux_x64; digest=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
    *) echo 'Unsupported security scanner platform' >&2; exit 1 ;;
esac
archive="build/security-tools/gitleaks_8.30.1_$platform.tar.gz"
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_$platform.tar.gz" -o "$archive"
printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c -
tar -xzf "$archive" -C build/security-tools gitleaks
build/security-tools/gitleaks git --log-opts=HEAD --redact=100 --no-banner \
    --report-format json --report-path build/security/secrets.json .
echo 'Dependency, workflow and committed-history secret checks passed.'
