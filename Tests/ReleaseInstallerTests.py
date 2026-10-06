"""Offline installer integration tests; never touch real installed screen savers.

Run: python3 Tests/ReleaseInstallerTests.py
Fixture compilation uses the maintainer's Command Line Tools, not installer dependencies.
"""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Scripts"))
from release_installation import command, instructions, validate_instructions


class ReleaseInstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = tempfile.TemporaryDirectory(prefix="screensaver-installer-tests-")
        cls.root = Path(cls.base.name)
        source = cls.root / "fixture.c"
        source.write_text("int fixture(void) { return 1; }\n")
        cls.bundle = cls.root / "Dapple.saver"
        executable = cls.bundle / "Contents/MacOS/Dapple"
        executable.parent.mkdir(parents=True)
        subprocess.run(["xcrun", "clang", "-arch", "arm64", "-bundle", str(source),
                        "-o", str(executable)], check=True, capture_output=True)
        with (cls.bundle / "Contents/Info.plist").open("wb") as file:
            plistlib.dump({"CFBundleIdentifier": "com.someoneintexas.screensavers.dapple",
                          "CFBundleExecutable": "Dapple", "CFBundlePackageType": "BNDL",
                          "CFBundleShortVersionString": "0.8.1"}, file)
        subprocess.run(["codesign", "--force", "--sign", "-", str(cls.bundle)],
                       check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.base.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=self.root)
        self.addCleanup(self.temp.cleanup)
        self.case = Path(self.temp.name)
        self.dest = self.case / "Screen Savers"
        self.dest.mkdir()
        self.asset = self.case / "ScreensaversForMac-v0.8.1-arm64.zip"
        subprocess.run(["/usr/bin/zip", "-qr", str(self.asset), "Dapple.saver"],
                       cwd=self.root, check=True)
        self.write_checksum()

    def write_checksum(self):
        digest = hashlib.sha256(self.asset.read_bytes()).hexdigest()
        (self.case / "SHA256SUMS").write_text(f"{digest}  {self.asset.name}\n")

    def run_installer(self, args=(), extra=""):
        # Only network, platform, and installation destination are substituted.
        script = r'''
source "$INSTALLER_UNDER_TEST"
check_platform() { :; }
fetch() {
    local output='' url=''
    while (( $# )); do
        case "$1" in
            --output) output=$2; shift 2 ;;
            --write-out) shift 2 ;;
            *) url=$1; shift ;;
        esac
    done
    if [[ "$url" == */releases/latest ]]; then
        printf '%s/releases/tag/v0.8.1' "$REPOSITORY"
    else
        cp "$FIXTURE_RELEASE/${url##*/}" "$output"
    fi
}
eval "$(declare -f install_bundles | sed '1s/install_bundles/install_to_path/')"
install_bundles() { install_to_path "$1" "$FIXTURE_DEST"; }
'''
        env = dict(os.environ, INSTALLER_UNDER_TEST=str(ROOT / "install.sh"),
                   FIXTURE_RELEASE=str(self.case), FIXTURE_DEST=str(self.dest),
                   TMPDIR=str(self.case), DEVELOPER_DIR="/nonexistent-installer-test-toolchain")
        return subprocess.run(["/bin/bash", "-c", script + extra + '\nmain "$@"',
                               "installer-test", *args], env=env,
                              text=True, capture_output=True)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_clean(self):
        self.assertFalse(list(self.dest.glob(".screensavers-install.*")))
        self.assertFalse(list(self.case.glob("screensavers-download.*")))

    def test_latest_verify_only(self):
        result = self.run_installer(["--verify-only"])
        self.assert_success(result)
        self.assertIn("Verified 1 savers from v0.8.1", result.stdout)
        self.assertEqual(list(self.dest.iterdir()), [])
        self.assert_clean()

    def test_documented_curl_pipeline(self):
        mockbin = self.case / "bin"
        mockbin.mkdir()
        curl = mockbin / "curl"
        curl.write_text(r'''#!/bin/bash
set -eu
output=''
url=''
while (( $# )); do
    case "$1" in
        --output) output=$2; shift 2 ;;
        --write-out|--retry|--connect-timeout|--max-time|--proto|--proto-redir) shift 2 ;;
        -*) shift ;;
        *) url=$1; shift ;;
    esac
done
case "$url" in
    https://raw.githubusercontent.com/someone-in-texas/screensavers-for-mac/*/install.sh)
        cat "$INSTALLER_UNDER_TEST" ;;
    https://github.com/someone-in-texas/screensavers-for-mac/releases/latest)
        printf '%s' 'https://github.com/someone-in-texas/screensavers-for-mac/releases/tag/v0.8.1' ;;
    https://github.com/someone-in-texas/screensavers-for-mac/releases/download/v0.8.1/*)
        cp "$FIXTURE_RELEASE/${url##*/}" "$output" ;;
    *) echo "Unexpected URL: $url" >&2; exit 1 ;;
esac
''')
        curl.chmod(0o755)
        env = dict(os.environ, PATH=f"{mockbin}:/usr/bin:/bin:/usr/sbin:/sbin",
                   INSTALLER_UNDER_TEST=str(ROOT / "install.sh"),
                   FIXTURE_RELEASE=str(self.case), TMPDIR=str(self.case),
                   DEVELOPER_DIR="/nonexistent-installer-test-toolchain")
        for public_command in (command(), command("v0.8.1", "v0.8.1")):
            with self.subTest(command=public_command):
                result = subprocess.run(["/bin/bash", "-o", "pipefail", "-c",
                                         public_command + " --verify-only"],
                                        env=env, text=True, capture_output=True)
                self.assert_success(result)
                self.assertIn("Verified 1 savers from v0.8.1", result.stdout)
                self.assertIn("Nothing installed", result.stdout)
                self.assert_clean()

    def test_stale_documentation_rejected(self):
        text = instructions()
        validate_instructions(text)
        with self.assertRaises(ValueError):
            validate_instructions(text.replace("bash /dev/stdin", "bash"))
        with self.assertRaises(ValueError):
            validate_instructions(instructions("v0.8.0", "v0.8.0"), "v0.8.1", "v0.8.1")

    def test_install_and_update(self):
        self.assert_success(self.run_installer(["--version", "v0.8.1"]))
        marker = self.dest / "Dapple.saver/old-file"
        marker.write_text("old version")
        unrelated = self.dest / "Unrelated.saver"
        unrelated.mkdir()
        self.assert_success(self.run_installer())
        self.assertFalse(marker.exists())
        self.assertTrue(unrelated.is_dir())
        self.assert_clean()

    def test_checksum_failure_keeps_old_install(self):
        shutil.copytree(self.bundle, self.dest / "Dapple.saver")
        (self.case / "SHA256SUMS").write_text(f"{'0' * 64}  {self.asset.name}\n")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertTrue((self.dest / "Dapple.saver").exists())
        self.assert_clean()

    def test_unrelated_identifier_rejected(self):
        target = self.dest / "Dapple.saver"
        shutil.copytree(self.bundle, target)
        plist = target / "Contents/Info.plist"
        with plist.open("wb") as file:
            plistlib.dump({"CFBundleIdentifier": "unrelated.saver"}, file)
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unrelated bundle", result.stderr)
        self.assertIn(b"unrelated.saver", plist.read_bytes())
        self.assert_clean()

    def test_failed_update_restores_old_bundle(self):
        shutil.copytree(self.bundle, self.dest / "Dapple.saver")
        marker = self.dest / "Dapple.saver/old-file"
        marker.write_text("keep me")
        result = self.run_installer(extra=r'''
mv() {
    if [[ "$1" == */new/Dapple.saver ]]; then
        echo 'Injected replacement failure' >&2
        return 1
    fi
    command mv "$@"
}
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(marker.read_text(), "keep me")
        self.assert_clean()

    def test_archive_traversal_rejected(self):
        with zipfile.ZipFile(self.asset, "a") as archive:
            archive.writestr("../escaped", "bad")
        self.write_checksum()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsafe path", result.stderr)
        self.assertEqual(list(self.dest.iterdir()), [])
        self.assert_clean()

    def test_second_replacement_failure_rolls_back_whole_install(self):
        second = self.case / "Flourish.saver"
        shutil.copytree(self.bundle, second)
        plist = second / "Contents/Info.plist"
        data = plistlib.loads(plist.read_bytes())
        data["CFBundleIdentifier"] = "com.someoneintexas.screensavers.flourish"
        plist.write_bytes(plistlib.dumps(data))
        subprocess.run(["codesign", "--force", "--sign", "-", str(second)],
                       check=True, capture_output=True)
        subprocess.run(["/usr/bin/zip", "-qr", str(self.asset), "Flourish.saver"],
                       cwd=self.case, check=True)
        self.write_checksum()
        for existing in (False, True):
            with self.subTest(existing=existing):
                if existing:
                    shutil.copytree(self.bundle, self.dest / "Dapple.saver")
                    (self.dest / "Dapple.saver/old-file").write_text("original")
                result = self.run_installer(extra=r'''
mv() {
    if [[ "$1" == */new/Flourish.saver ]]; then return 1; fi
    command mv "$@"
}
''')
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.dest / "Flourish.saver").exists())
                if existing:
                    self.assertEqual((self.dest / "Dapple.saver/old-file").read_text(), "original")
                else:
                    self.assertEqual(list(self.dest.iterdir()), [])
                self.assert_clean()

    def test_archive_symlink_rejected(self):
        link = zipfile.ZipInfo("link")
        link.create_system = 3
        link.external_attr = 0o120777 << 16
        with zipfile.ZipFile(self.asset, "a") as archive:
            archive.writestr(link, "../outside")
        self.write_checksum()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symbolic link", result.stderr)
        self.assert_clean()

    def test_invalid_version_rejected(self):
        result = self.run_installer(["--version", "../../main"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected a stable version", result.stderr)


if __name__ == "__main__":
    unittest.main()
