# Releasing

`VERSION` is the canonical collection version. All five savers use it; generated files
live only under `build`. Releases target Apple Silicon and macOS 14.6+.

```sh
# Update VERSION and CHANGELOG.md; review screenshots/docs.
make release-check
git status
git diff --check
git add <changed-files>
git commit -m 'release: prepare v0.x.y'
git push origin main
git tag v0.x.y
git push origin v0.x.y
```

Verify origin is `someone-in-texas/screensavers-for-mac`. Watch `gh run list` /
`gh run watch <run-id> --exit-status`; inspect logs for failures. The tag must match
VERSION. The workflow uses the tag checkout, arm64 macOS runner and GitHub's token
with contents:write. It builds/tests, packages, mounts/extracts/verifies, creates a
draft release, uploads DMG/ZIP/SHA256SUMS, then publishes it. Rerunning updates the
same release/assets. Do not move a tag after a release is public; fix with a patch release.

Expected files in `dist`:

- `ScreensaversForMac-v<VERSION>-arm64.dmg`
- `ScreensaversForMac-v<VERSION>-arm64.zip`
- `SHA256SUMS`
- local `SIGNING.txt`, incorporated into release notes

Download the published files to a fresh directory, run `shasum -a 256 -c SHA256SUMS`,
mount the DMG and check all five savers. Confirm the release notes state the actual signing
level. For final validation, also build from a clean checkout, launch PreviewHost,
install the bundles and check System Settings preview/configuration.

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
