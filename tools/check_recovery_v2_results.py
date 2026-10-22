"""Check exact DRP/2 local named cases without claiming provider qualification.

Read-only: no test/resource execution or provider access. RC10/RC11 cannot be
qualified by an ordinary pytest or emulator report. This incremental guard does
not attest test arrangement/oracles, source identity, independent review or trust.
"""

import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

PROVIDER_CASES = {"RC10", "RC11"}
REQUIRED_IDS = {
    *(f"PG{index:02}" for index in range(1, 23)),
    *(f"SQ{index:02}" for index in range(1, 11)),
    *(f"RC{index:02}" for index in range(1, 13)),
}


def expected_cases(specification: Path) -> dict[str, str]:
    try:
        rows = re.findall(
            r"^\| ((?:PG|SQ|RC)\d{2}) `([^`]+)` \|",
            specification.read_text(encoding="utf-8"),
            re.MULTILINE,
        )
    except (OSError, UnicodeError):
        raise ValueError("Recovery specification is missing or unreadable") from None
    cases = dict(rows)
    if len(rows) != 44 or set(cases) != REQUIRED_IDS or len(set(cases.values())) != 44:
        raise ValueError("Recovery specification must contain exactly the 44 unique named cases")
    return cases


def python_cases(report: Path) -> set[tuple[str, str]]:
    try:
        document = ET.parse(report).getroot()
    except (OSError, ET.ParseError):
        raise ValueError("Python report is missing or malformed") from None
    cases = list(document.iter("testcase"))
    if not cases or any(list(document.iter(tag)) for tag in ("skipped", "failure", "error")):
        raise ValueError("Python report requires nonempty, zero-skip, zero-failure completion")
    suites = list(document.iter("testsuite"))
    try:
        if (
            not suites
            or sum(int(suite.attrib["tests"]) for suite in suites) != len(cases)
            or any(
                int(suite.attrib[key]) != 0
                for suite in suites
                for key in ("errors", "failures", "skipped")
            )
        ):
            raise ValueError()
    except (KeyError, ValueError):
        raise ValueError("Python completion totals are missing or inconsistent") from None
    identities = [(case.get("classname", ""), case.get("name", "")) for case in cases]
    if len(set(identities)) != len(identities) or any(not all(item) for item in identities):
        raise ValueError("Python case identities are missing or duplicated")
    return {(module, name.split("[", 1)[0]) for module, name in identities}


def flutter_cases(report: Path) -> set[str]:
    try:
        events = []
        for line in report.read_text("utf-8-sig").splitlines():
            if not line.strip():
                continue
            event = json.loads(line)
            # Flutter emits this daemon envelope alongside package:test events.
            # It contains no test result. Other arrays/non-events stay invalid;
            # do not silently discard malformed or failed test records.
            if (
                isinstance(event, list)
                and event
                and all(
                    isinstance(item, dict)
                    and set(item) == {"event", "params"}
                    and item["event"] == "test.startedProcess"
                    and isinstance(item["params"], dict)
                    and set(item["params"]) == {"vmServiceUri"}
                    and (
                        item["params"]["vmServiceUri"] is None
                        or isinstance(item["params"]["vmServiceUri"], str)
                    )
                    for item in event
                )
            ):
                continue
            if not isinstance(event, dict):
                raise ValueError()
            events.append(event)
        if not events:
            raise ValueError()
    except (OSError, UnicodeError, ValueError):
        raise ValueError("Flutter machine report is missing or malformed") from None
    if (
        events[-1].get("type") != "done"
        or events[-1].get("success") is not True
        or sum(event.get("type") == "done" for event in events) != 1
        or any(event.get("type") == "error" for event in events)
    ):
        raise ValueError("Flutter machine report lacks successful final completion")
    suites: dict[int, str] = {}
    started: dict[int, tuple[str, int]] = {}
    completed: set[int] = set()
    visible: set[str] = set()
    try:
        for event in events:
            if event.get("type") == "suite":
                suite = event["suite"]
                if type(suite["id"]) is not int or suite["id"] in suites:
                    raise ValueError()
                suites[suite["id"]] = suite["path"].replace("\\", "/")
            elif event.get("type") == "testStart":
                test = event["test"]
                if type(test["id"]) is not int or test["id"] in started:
                    raise ValueError()
                started[test["id"]] = (test["name"], test["suiteID"])
            elif event.get("type") == "testDone":
                identity = event["testID"]
                if (
                    identity not in started
                    or identity in completed
                    or event["skipped"] is not False
                    or event["result"] != "success"
                    or type(event["hidden"]) is not bool
                ):
                    raise ValueError()
                completed.add(identity)
                name, suite_id = started[identity]
                path = suites[suite_id]
                if not event["hidden"] and path.endswith(
                    "/apps/mobile/test/recovery_protocol_v2_test.dart"
                ):
                    if name in visible:
                        raise ValueError()
                    visible.add(name)
        if not visible or completed != set(started):
            raise ValueError()
    except (KeyError, TypeError, AttributeError, ValueError):
        raise ValueError("Flutter cases are omitted, incomplete, skipped or inconsistent") from None
    return visible


def assess(specification: Path, junit: Path, flutter: Path) -> dict[str, object]:
    expected = expected_cases(specification)
    passed_python, passed_flutter = python_cases(junit), flutter_cases(flutter)
    passed: list[str] = []
    missing: list[str] = []
    for identity, name in sorted(expected.items()):
        module = (
            "tests.test_recovery_protocol_v2"
            if identity.startswith("PG")
            else "tests.test_recovery_protocol_v2_lab"
        )
        present = (
            name in passed_flutter if identity.startswith("SQ") else (module, name) in passed_python
        )
        if identity in PROVIDER_CASES:
            if present:
                raise ValueError("RC10/RC11 cannot be qualified by ordinary local test reports")
        elif present:
            passed.append(identity)
        else:
            missing.append(identity)
    return {
        "scope": "named local cases only; report validation is not oracle review",
        "local_named_cases_passed": not missing,
        "passed": passed,
        "missing": missing,
        "RC10": "NOT EXECUTED",
        "RC11": "NOT EXECUTED",
        "complete_protocol_qualification": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--junit", type=Path, required=True)
    parser.add_argument("--flutter", type=Path, required=True)
    options = parser.parse_args()
    try:
        assessment = assess(options.spec, options.junit, options.flutter)
    except ValueError as error:
        print(json.dumps({"local_named_cases_passed": False, "error": str(error)}))
        return 1
    print(json.dumps(assessment, indent=2))
    return 0 if assessment["local_named_cases_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
