"""Fail closed when CI omits or skips the real recovery/connected acceptance cases."""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REQUIRED_MODULES = {"tests.test_recovery", "tests.test_flutter_connected"}


def validate_report(path: Path) -> int:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as error:
        raise ValueError("Python acceptance report is missing or malformed") from error
    cases = list(root.iter("testcase"))
    if not cases:
        raise ValueError("Python acceptance report contains no cases")
    if any(list(root.iter(tag)) for tag in ("skipped", "failure", "error")):
        raise ValueError("Python acceptance requires zero skipped, failed or errored cases")
    modules = {case.get("classname") for case in cases}
    if not REQUIRED_MODULES <= modules:
        raise ValueError("Python acceptance omitted recovery or connected PostgreSQL cases")
    if not any(
        case.get("classname") == "tests.test_flutter_connected"
        and case.get("name") == "test_flutter_http_with_real_postgres"
        for case in cases
    ):
        raise ValueError("Python acceptance omitted the actual connected Flutter HTTP case")
    return len(cases)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check_python_results.py PYTEST_JUNIT_XML")
    try:
        count = validate_report(Path(sys.argv[1]))
    except ValueError as error:
        raise SystemExit(str(error)) from None
    print(f"Python acceptance: {count} passed, zero skipped; recovery and connected cases present")
