import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from check_python_results import validate_report  # noqa: E402


class PythonResultsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "report.xml"

    def write(self, extra: str = "", *, recovery: str = "tests.test_recovery") -> None:
        self.path.write_text(
            '<testsuites><testsuite><testcase classname="tests.test_flutter_connected" '
            'name="test_flutter_http_with_real_postgres"/>'
            f'<testcase classname="{recovery}">{extra}</testcase></testsuite></testsuites>',
            encoding="utf-8",
        )

    def test_completed_acceptance_report(self) -> None:
        self.write()
        self.assertEqual(validate_report(self.path), 2)

    def test_skipped_recovery_is_rejected(self) -> None:
        self.write('<skipped message="requires opt in"/>')
        with self.assertRaisesRegex(ValueError, "zero skipped"):
            validate_report(self.path)

    def test_failed_case_is_rejected(self) -> None:
        self.write("<failure/>")
        with self.assertRaisesRegex(ValueError, "failed"):
            validate_report(self.path)

    def test_setup_error_is_rejected(self) -> None:
        self.write("<error/>")
        with self.assertRaisesRegex(ValueError, "errored"):
            validate_report(self.path)

    def test_only_target_guards_do_not_qualify_restore(self) -> None:
        self.write(recovery="tests.test_recovery_target")
        with self.assertRaisesRegex(ValueError, "omitted recovery"):
            validate_report(self.path)

    def test_missing_report_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing or malformed"):
            validate_report(self.path)

    def test_malformed_report_is_rejected(self) -> None:
        self.path.write_text("<truncated", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "missing or malformed"):
            validate_report(self.path)

    def test_empty_success_is_rejected(self) -> None:
        self.path.write_text('<testsuites tests="0"/>', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "no cases"):
            validate_report(self.path)

    def test_parser_unit_cases_cannot_substitute_for_live_http(self) -> None:
        self.write()
        self.path.write_text(
            self.path.read_text().replace("test_flutter_http_with_real_postgres", "test_report"),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "actual connected Flutter HTTP"):
            validate_report(self.path)


if __name__ == "__main__":
    unittest.main()
