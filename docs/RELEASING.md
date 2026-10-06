# Releasing

`VERSION` is the canonical collection version. All nine savers use it; generated files
live only under `build`. The separately built AI helper is packaged in `Optional/`
and is never installed by the saver installer. It uses the same version/signing path. Releases target Apple Silicon and macOS 14.6+.

```sh
# Update VERSION and CHANGELOG.md; review screenshots/docs.
make release-check
make security-check
git status
git diff --check
git add <changed-files>
git commit -m 'release: prepare v0.x.y'
git push origin main
# Wait for all CI/security checks to pass before tagging.
git tag v0.x.y
git push origin v0.x.y
```

Verify origin is `someone-in-texas/screensavers-for-mac`. Watch `gh run list` /
`gh run watch <run-id> --exit-status`; inspect logs for failures. The tag must match
VERSION. The workflow first runs the required [security gate](SECURITY_MAINTENANCE.md)
against the tag checkout. Only after it passes does the arm64 macOS package job
build/test, package and mount/extract/verify. A separate publisher with
`contents: write` verifies the transferred assets, creates a draft, uploads
DMG/ZIP/SHA256SUMS, then publishes. Reruns can resume a draft but refuse to overwrite
a public release. Do not move a tag after a release is public; fix with a patch release.

Expected files in `dist`:

- `ScreensaversForMac-v<VERSION>-arm64.dmg`
- `ScreensaversForMac-v<VERSION>-arm64.zip`
- `SHA256SUMS`
- local `SIGNING.txt`, incorporated into release notes

Download the published files to a fresh directory, run `shasum -a 256 -c SHA256SUMS`,
mount the DMG and check all nine savers. Confirm the release notes state the actual signing
level. For final validation, also build from a clean checkout, launch PreviewHost,
install the bundles and check System Settings preview/configuration.

## Maintain the recommended curl installer

`install.sh` downloads published ZIPs; `Scripts/install.sh` builds local source.
Keep the public installer outside packaged DMG/ZIP contents. Its only runtime
dependencies are tools shipped with macOS, and updates preserve preferences/cache.

Before each release, run `python3 Scripts/check-installation.py` and
`python3 Tests/ReleaseInstallerTests.py`. Both are part of `Scripts/test.sh` and
`make release-check`. The former checks the top README block against the canonical
text in `Scripts/release_installation.py` and checks generated release notes. The
latter executes the documented curl pipeline with an offline transport and tests
verification, installation and rollback in temporary directories. Package checks
also pass the actual release ZIP through the public installer's validation functions.
Update the installer allowlist whenever saver identities change.

`python3 Scripts/release-notes.py` generates `dist/release-notes.md` from the
changelog, actual signing status and canonical installation instructions. The release
workflow uses this generator. README installs use the maintained `main/install.sh`
and the latest published stable assets. Release-page commands pin both script and
asset version to that release tag, so older instructions remain reproducible.

After publication, the macOS `verify-installation` job checks the live README,
release page and raw script, then runs the public curl command with `--verify-only`.
To repeat this from the matching checkout:

```sh
python3 Scripts/check-installation.py --published-tag v<VERSION>
```

The existing v0.8.1 release predates the installer; its installation text uses the
maintained main script with `--version 0.8.1`. Check that bootstrap with
`--published-tag v0.8.1 --installer-ref main`. Do not move its tag or replace its
assets. A failed post-publication check requires investigation and a correction;
do not silently remove the check. On a clean supported Mac, also exercise the
recommended command, reopen System Settings and confirm the installed savers run.

## Without Apple credentials

The default path is **ad-hoc signed, not notarized**. Ordinary CI always supports this.
No Apple login or secrets are required. Gatekeeper may require per-download approval
through Privacy & Security. Do not recommend disabling Gatekeeper globally.

## Optional Developer ID and notarization

Set these repository Actions secrets together:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERT_BASE64` | Base64-encoded .p12 containing Developer ID Application certificate and private key |
| `DEVELOPER_ID_CERT_PASSWORD` | Password protecting that .p12 |
| `SIGNING_IDENTITY` | Full `Developer ID Application: … (TEAMID)` identity name |
| `NOTARY_KEY_ID` | App Store Connect API key ID with notarization access |
| `NOTARY_ISSUER_ID` | Issuer UUID for that team API key |
| `NOTARY_KEY_P8` | Private .p8 key contents, including header and footer |

The workflow imports the identity into a temporary unlocked keychain, signs saver
bundles with hardened runtime and a secure timestamp (no entitlements), signs the DMG,
submits it with Apple's `notarytool --wait`, staples and validates the DMG, then assesses
it with `spctl`. Partial credentials fail explicitly. The temporary keychain is deleted
in an always-run cleanup step. Do not put certificates, passwords or keys in git.

Locally, provide `SIGNING_IDENTITY` plus `NOTARY_PROFILE` referencing an existing
`notarytool store-credentials` keychain profile, then run `make package`. Alternatively
use the three NOTARY_* API-key variables. The ZIP contains the same Developer ID-signed
bundles, but the stapled ticket is on the DMG; prefer the DMG for offline verification.
Screen saver bundle stapling is not assumed. The optional credentialed path requires
validation with a real identity before calling its output notarized; v0.1.0 has no such
credentials and uses the documented ad-hoc path.

References: [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow),
[ScreenSaverView](https://developer.apple.com/documentation/screensaver/screensaverview),
[GitHub macOS runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
