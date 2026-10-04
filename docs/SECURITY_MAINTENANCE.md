# Security maintenance

[SECURITY.md](../SECURITY.md) describes supported versions and private reporting.
The reusable [Security workflow](../.github/workflows/security.yml) runs in CI on
pushes/PRs, can be dispatched manually, and is a required dependency of tag
releases. It does not enable Dependabot, scheduled scans or automatic update PRs.

## What blocks publication

- **CodeQL security-extended** analyzes Swift (all saver entry points and shared
  scenes, PreviewHost, the thumbnail tool and separate AI helper) and Python
  maintenance scripts. Its dedicated build compiles the shared saver code once,
  rather than repeating it for every bundle; CI and packaging still perform the
  ordinary production builds and regression tests independently. Analysis
  uploads to GitHub code scanning and produces SARIF artifacts. The SARIF gate
  rejects every finding, including previously dismissed/baselined findings, and
  rejects missing/malformed reports or failed analysis. Uploading alerts alone
  would not stop a release. Regression tests exercise these failure paths.
- **pip-audit** checks the complete, pinned and hashed Python maintenance lockfile
  against current vulnerability data, at every severity, with strict collection
  failure handling. Shapely and NumPy are only for optional map maintenance; they
  are not bundled or required by normal builds or savers.
- **Gitleaks** scans the full history reachable from the checked-out commit, with
  redacted output. A release must not introduce credentials even in intermediate
  commits. Secret reports are not uploaded as public workflow artifacts.
- **zizmor** checks Actions workflows offline, blocking low-or-higher security
  findings. Actions use full commit hashes and checkout does not retain credentials.

Scanner download errors, unavailable advisory services, failed analysis and
findings all fail the job. There are no vulnerability exclusions or severity
bypasses. Fix and rerun; investigate false positives before changing policy. A
GitHub alert dismissal does not bypass the SARIF gate. Review dependency/scanner
updates, including upstream release notes and hash provenance.

The package job starts only after security succeeds. It builds and tests again,
signs/packages, and verifies both archives. Only the separate publisher job has
`contents: write`; it runs no checked-out project code, downloads artifacts from
that same workflow run, verifies checksums, uploads a draft, then publishes. It
refuses to overwrite an already-public release. Optional signing secrets are only
available to the signing steps, with temporary key files private from creation.

## Local checks and updates

Install [uv](https://docs.astral.sh/uv/getting-started/installation/), then:

```sh
make security-check       # online audit; committed history, not uncommitted secrets
make release-check        # offline native/gate tests and DMG/ZIP verification
```

CodeQL runs on GitHub's macOS runner; `make security-check` does not run CodeQL
locally. After pushing, wait for all CI/security jobs before tagging. The tag
workflow checks the tag's source again before publishing. Review uploaded reports
and the exact commit when diagnosing a failure.

To update the map-tool lockfile, edit `Scripts/security/requirements.in` as needed:

```sh
uv pip compile --python-version 3.12 --generate-hashes --no-emit-index-url \
  Scripts/security/requirements.in -o Scripts/security/requirements.txt
make security-check
uv run --python 3.12 --no-project --with-requirements Scripts/security/requirements.txt \
  python Tests/CoastalWaterTests.py
```

Use that locked environment for explicit map refreshes too. Neither release nor
security checks download new map data. When adding a new package ecosystem, add
its manifest/lockfile and a fail-closed audit to this workflow in the same change.
Current native products have no third-party runtime packages. Apple frameworks
and the separately installed Codex CLI are outside this lockfile's audit scope.
These checks cannot prove the absence of vulnerabilities or audit a user's system.

Tool references: [CodeQL manual builds](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/manage-your-configuration/codeql-for-compiled-languages),
[pip-audit](https://github.com/pypa/pip-audit),
[Gitleaks](https://github.com/gitleaks/gitleaks), [zizmor](https://docs.zizmor.sh/usage/).
