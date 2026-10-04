"""Exercise the actual gate process, especially failures that could publish unsafely."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

GATE = Path(__file__).resolve().parents[1] / "Scripts/security/check-sarif.py"
CLEAN = {"version": "2.1.0", "runs": [{
    "tool": {"driver": {"name": "CodeQL", "rules": [{"id": "swift/example"}]}},
    "invocations": [{"executionSuccessful": True}], "results": []
}]}


class SecurityGateTests(unittest.TestCase):
    def invoke(self, reports):
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for index, report in enumerate(reports):
                path = Path(directory) / f"{index}.sarif"
                if report is not None:
                    path.write_text(report if isinstance(report, str) else json.dumps(report))
                paths.append(str(path))
            return subprocess.run([sys.executable, str(GATE), *paths], capture_output=True).returncode

    def test_clean_reports(self):
        self.assertEqual(self.invoke([CLEAN, CLEAN]), 0)

    def test_query_pack_rules_in_extensions(self):
        report = copy.deepcopy(CLEAN)
        tool = report["runs"][0]["tool"]
        rules = tool["driver"].pop("rules")
        tool["extensions"] = [{"name": "codeql/swift-queries", "rules": rules}]
        self.assertEqual(self.invoke([report]), 0)
        report["runs"][0]["results"] = [{"ruleId": "swift/example"}]
        self.assertNotEqual(self.invoke([report]), 0)
        report["runs"][0]["results"] = []
        tool["extensions"][0]["rules"] = []
        self.assertNotEqual(self.invoke([report]), 0)

    def test_findings_at_every_level_and_suppression(self):
        for level in ("error", "warning", "note", "none"):
            report = copy.deepcopy(CLEAN)
            report["runs"][0]["results"] = [{"ruleId": "swift/example", "level": level,
                "suppressions": [{"kind": "external", "status": "accepted"}], "baselineState": "unchanged"}]
            self.assertNotEqual(self.invoke([CLEAN, report]), 0)

    def test_missing_malformed_or_empty_reports(self):
        for reports in ([], [None], ["{"], [{}], [{"version": "2.1.0", "runs": []}]):
            self.assertNotEqual(self.invoke(reports), 0)

    def test_incomplete_analysis(self):
        for field in ("results", "invocations", "tool"):
            report = copy.deepcopy(CLEAN)
            del report["runs"][0][field]
            self.assertNotEqual(self.invoke([report]), 0)
        report = copy.deepcopy(CLEAN)
        report["runs"][0]["invocations"][0]["executionSuccessful"] = False
        self.assertNotEqual(self.invoke([report]), 0)
        report["runs"][0]["invocations"][0] = {"executionSuccessful": True,
            "toolExecutionNotifications": [{"level": "error"}]}
        self.assertNotEqual(self.invoke([report]), 0)


if __name__ == "__main__":
    unittest.main()
