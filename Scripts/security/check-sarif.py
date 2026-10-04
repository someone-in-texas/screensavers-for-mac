#!/usr/bin/env python3
"""Fail closed on CodeQL findings, missing analysis, or unsuccessful invocations."""
import json
import sys
from pathlib import Path


def check(path):
    report = json.loads(Path(path).read_text())
    if report.get("version") != "2.1.0" or not report.get("runs"):
        raise ValueError("missing SARIF 2.1.0 runs")
    findings = 0
    for run in report["runs"]:
        driver = run["tool"]["driver"]
        if driver["name"] != "CodeQL" or not driver.get("rules"):
            raise ValueError("missing CodeQL rules")
        invocations = run.get("invocations", [])
        if not invocations or any(i.get("executionSuccessful") is not True for i in invocations):
            raise ValueError("missing or unsuccessful analysis invocation")
        for invocation in invocations:
            for key in ("toolExecutionNotifications", "toolConfigurationNotifications"):
                if any(n.get("level") == "error" for n in invocation.get(key, [])):
                    raise ValueError("analysis reported an error")
        results = run["results"]
        if not isinstance(results, list):
            raise ValueError("invalid results")
        # Include suppressed/baselined findings: release checks must not depend
        # on an alert's dismissal status in the GitHub dashboard.
        findings += len(results)
        for result in results:
            print(f"{path}: finding {result.get('ruleId', '(unknown rule)')}", file=sys.stderr)
    if findings:
        raise ValueError(f"{findings} CodeQL finding(s); review and fix before releasing")


if __name__ == "__main__":
    try:
        if len(sys.argv) < 2:
            raise ValueError("expected at least one SARIF report")
        for filename in sys.argv[1:]:
            check(filename)
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"Security gate failed: {error}")
    print("CodeQL gate passed: no findings in all requested reports.")
