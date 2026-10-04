# Security policy

Security fixes target the latest published release. Please upgrade before testing
a suspected issue; older versions do not receive separate security backports.

## Report a vulnerability privately

Use [Report a vulnerability](https://github.com/someone-in-texas/screensavers-for-mac/security/advisories/new).
Include the affected version, macOS version, reproduction steps, expected impact,
and a minimal example when possible. Keep exploit details out of public issues
until a fix is available. Never include account tokens, cookies, private keys, or
personal map-cache contents. This is a volunteer project with no guaranteed
response time or bug bounty; maintainers will coordinate fixes and disclosure
through the private report.

## Scope and boundaries

Reports about screen savers, City Drift's network/data parsing, the optional AI
helper, build tools and release workflows are welcome. Current savers never need
ChatGPT or launch the helper. The helper uses a separately installed Codex CLI and
its managed account/keyring flow; this repository does not bundle or update Codex.
Keep macOS and Codex up to date. Issues in those products should also be reported
to their vendors; disclose integration issues here.

Download releases from this repository and verify `SHA256SUMS`. Release notes
state whether artifacts are ad-hoc signed or Developer ID signed and notarized.
Checksums establish download consistency, not independent publisher identity.
Never disable Gatekeeper globally.

## Release checks

Every tag release must pass dependency vulnerability auditing, Swift/Python
CodeQL analysis, secret scanning and workflow security checks before packaging
or publishing. Findings and scanner errors block the release. No Dependabot
automation is enabled. See [security maintenance](docs/SECURITY_MAINTENANCE.md)
for scope, limitations, local commands and handling a failed check.
