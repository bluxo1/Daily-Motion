import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from check_recovery_v2_results import PROVIDER_CASES, REQUIRED_IDS, assess  # noqa: E402


class RecoveryResultsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.spec, self.junit, self.flutter = (
            root / name for name in ("spec.md", "junit.xml", "flutter.jsonl")
        )
        self.names = {
            identity: "test_case_" + identity.lower() for identity in sorted(REQUIRED_IDS)
        }
        self.spec.write_text(
            "\n".join(
                f"| {identity} `{name}` | setup | oracle |" for identity, name in self.names.items()
            ),
            encoding="utf-8",
        )
        self.document = ET.Element("testsuites")
        self.suite = ET.SubElement(
            self.document, "testsuite", tests="32", errors="0", failures="0", skipped="0"
        )
        self.events: list[dict] = [
            {
                "type": "suite",
                "suite": {
                    "id": 0,
                    "path": "/owned/apps/mobile/test/recovery_protocol_v2_test.dart",
                },
            }
        ]
        for index, (identity, name) in enumerate(self.names.items()):
            if identity in PROVIDER_CASES:
                continue
            if identity.startswith("SQ"):
                self.events.extend(
                    [
                        {"type": "testStart", "test": {"id": index, "name": name, "suiteID": 0}},
                        {
                            "type": "testDone",
                            "testID": index,
                            "hidden": False,
                            "skipped": False,
                            "result": "success",
                        },
                    ]
                )
            else:
                ET.SubElement(
                    self.suite,
                    "testcase",
                    classname="tests.test_recovery_protocol_v2"
                    + ("_lab" if identity.startswith("RC") else ""),
                    name=name,
                )
        self.events.append({"type": "done", "success": True})

    def check(self) -> dict[str, object]:
        ET.ElementTree(self.document).write(self.junit, encoding="utf-8")
        self.flutter.write_text(
            "\n".join(json.dumps(event) for event in self.events), encoding="utf-8"
        )
        return assess(self.spec, self.junit, self.flutter)

    def test_all_local_names_cannot_claim_provider_or_protocol_qualification(self) -> None:
        result = self.check()
        self.assertTrue(result["local_named_cases_passed"])
        self.assertEqual(result["missing"], [])
        self.assertEqual(len(result["passed"]), 42)
        self.assertFalse(result["complete_protocol_qualification"])
        self.assertEqual(result["RC10"], "NOT EXECUTED")
        self.assertEqual(result["RC11"], "NOT EXECUTED")

    def test_missing_or_wrong_python_case_is_not_coverage(self) -> None:
        self.suite[0].set("name", "different_case")
        self.assertEqual(self.check()["missing"], ["PG01"])
        self.suite[0].set("name", self.names["PG01"])
        self.suite[0].set("classname", "tests.a_different_module")
        self.assertEqual(self.check()["missing"], ["PG01"])
        self.suite.remove(self.suite[0])
        self.suite.set("tests", "31")
        self.assertEqual(self.check()["missing"], ["PG01"])

    def test_failed_skipped_or_incomplete_python_cannot_claim_completion(self) -> None:
        for tag in ("failure", "error", "skipped"):
            with self.subTest(tag=tag):
                record = ET.SubElement(self.suite[0], tag)
                with self.assertRaises(ValueError):
                    self.check()
                self.suite[0].remove(record)
        self.suite.set("tests", "33")
        with self.assertRaisesRegex(ValueError, "totals"):
            self.check()

    def test_flutter_omission_hidden_skip_duplicate_and_missing_done_fail(self) -> None:
        original = json.dumps(self.events)
        for fault in (
            "missing_done",
            "false_done",
            "skip",
            "hidden",
            "error",
            "wrong_name",
            "wrong_file",
            "duplicate",
        ):
            with self.subTest(fault=fault):
                self.events = json.loads(original)
                if fault == "missing_done":
                    self.events.pop()
                elif fault == "false_done":
                    self.events[-1]["success"] = False
                elif fault == "skip":
                    self.events[2]["skipped"] = True
                elif fault == "hidden":
                    self.events[2]["hidden"] = True
                elif fault == "error":
                    self.events[2]["result"] = "error"
                elif fault == "wrong_name":
                    self.events[1]["test"]["name"] = "unrelated"
                elif fault == "wrong_file":
                    self.events[0]["suite"]["path"] = "/owned/another_test.dart"
                else:
                    self.events.insert(3, self.events[2].copy())
                if fault in ("hidden", "wrong_name"):
                    self.assertEqual(self.check()["missing"], ["SQ01"])
                else:
                    with self.assertRaises(ValueError):
                        self.check()

    def test_provider_names_in_ordinary_pytest_cannot_qualify_rc10_or_rc11(self) -> None:
        for identity in PROVIDER_CASES:
            with self.subTest(identity=identity):
                case = ET.SubElement(
                    self.suite,
                    "testcase",
                    classname="tests.test_recovery_protocol_v2_lab",
                    name=self.names[identity],
                )
                self.suite.set("tests", "33")
                with self.assertRaisesRegex(ValueError, "RC10/RC11"):
                    self.check()
                self.suite.remove(case)

    def test_specification_missing_or_duplicate_cases_is_rejected(self) -> None:
        self.spec.write_text("| PG01 `test_case_pg01` | synthetic | synthetic |", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "44 unique"):
            self.check()

    def test_real_flutter_daemon_envelope_is_not_a_test_result(self) -> None:
        self.check()
        original = self.flutter.read_text("utf-8")
        envelope = [{"event": "test.startedProcess", "params": {"vmServiceUri": None}}]
        self.flutter.write_text("\n" + json.dumps(envelope) + "\n" + original, encoding="utf-8")
        self.assertTrue(assess(self.spec, self.junit, self.flutter)["local_named_cases_passed"])
        self.flutter.write_text(
            json.dumps([{"type": "testDone", "result": "error"}]) + "\n" + original,
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "malformed"):
            assess(self.spec, self.junit, self.flutter)


if __name__ == "__main__":
    unittest.main()
