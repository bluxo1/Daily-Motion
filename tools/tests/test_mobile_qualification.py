"""Adversarial checks for the archived mobile evidence validator."""

import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "mobile_evidence", ROOT / "tools/check_mobile_qualification.py"
)
assert spec is not None and spec.loader is not None
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class MobileEvidenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name) / "receipts"
        shutil.copytree(ROOT / "docs/mobile-qualification", self.folder)
        self.index_path = self.folder / "evidence-2026-10-20.json"
        self.index = json.loads(self.index_path.read_text())

    def save_index(self) -> None:
        self.index_path.write_text(json.dumps(self.index), encoding="utf-8")

    def test_original_receipts_validate(self) -> None:
        validator.validate_evidence(self.folder)

    def test_changed_receipt_fails_hash_check(self) -> None:
        record = self.index["native"]["android_emulator"]["reports"]["recover"]
        path = self.folder / record["report"]
        data = json.loads(path.read_text())
        data["outbox_count"] = 0
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "report hash mismatch"):
            validator.validate_evidence(self.folder)

    def test_physical_promotion_is_rejected(self) -> None:
        self.index["physical_device_sample_count"] = 200
        self.index["hardware_gates_closed"] = True
        self.save_index()
        with self.assertRaisesRegex(ValueError, "physical sample count"):
            validator.validate_evidence(self.folder)

    def test_incorrect_percentile_with_updated_hash_is_rejected(self) -> None:
        collector = self.index["native"]["android_emulator"]["profile_collector"]
        path = self.folder / collector["report"]
        report = json.loads(path.read_text())
        report["p95_us"] += 1
        collector["p95_us"] = report["p95_us"]
        encoded = (json.dumps(report) + "\n").encode()
        path.write_bytes(encoded)
        collector["report_sha256"] = hashlib.sha256(encoded).hexdigest()
        self.save_index()
        with self.assertRaisesRegex(ValueError, "p95_us disagrees"):
            validator.validate_evidence(self.folder)


if __name__ == "__main__":
    unittest.main()
