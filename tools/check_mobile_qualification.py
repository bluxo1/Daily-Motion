"""Validate archived Session 3 receipts; this does not attest new device runs."""

import hashlib
import json
import math
from pathlib import Path
from typing import Any

EVIDENCE = Path(__file__).resolve().parents[1] / "docs/mobile-qualification"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))  # type: ignore[no-any-return]


def validate_evidence(folder: Path = EVIDENCE) -> None:
    index = load(folder / "evidence-2026-10-20.json")
    require(index["physical_device_sample_count"] == 0, "physical sample count changed")
    require(index["physical_p95_us"] is None, "physical latency remains unmeasured")
    require(index["hardware_gates_closed"] is False, "hardware gates must remain open")
    native = index["native"]
    android = native["android_emulator"]
    require(android["physical"] is False, "emulator must not be physical evidence")
    require(android["no_hardware_gate_satisfied"] is True, "emulator cannot close hardware gates")

    def receipt(metadata: dict[str, Any]) -> dict[str, Any]:
        path = folder / metadata["report"]
        require(
            path.resolve().parent == folder.resolve(), "report must stay inside evidence directory"
        )
        # Git text checkout can use CRLF; receipts were hashed as LF Git blobs.
        digest = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        require(digest == metadata["report_sha256"], f"report hash mismatch: {path.name}")
        data = load(path)
        require(
            metadata["driver_exit_code"] == 0, "successful receipt requires a successful driver"
        )
        require(data["synthetic_only"] is True, "receipt must contain synthetic data only")
        require(data["device"]["physical"] is False, "receipt must retain emulator classification")
        require(
            data["device"]["application_id"].endswith(".qualification"),
            "dedicated install required",
        )
        return data

    storage = [receipt(value) for value in android["reports"].values()]
    reboot = android["offline_reboot"]
    storage.extend(receipt(value) for value in reboot["reports"].values())
    for report in storage:
        require(report["stage"] in {"seed", "recover"}, "unknown storage stage")
        require(report["sqlite_integrity"] == "ok", "SQLite integrity receipt missing")
        require(report["sqlite_foreign_keys"] == "ok", "SQLite foreign-key receipt missing")
        require(report["outbox_count"] == 2, "pending outbox receipt changed")
        for flag in (
            "secure_probe_restored",
            "synthetic_session_restored",
            "synthetic_owner_grant_restored",
            "draft_restored",
        ):
            require(report[flag] is True, f"storage receipt missing: {flag}")
        require(0 <= report["timer_remaining_seconds"] <= 120, "timer outside declared bounds")
        require(type(report["timer_approximate"]) is bool, "timer uncertainty must be explicit")

    termination = android["external_termination"]
    require(termination["physical_hardware"] is False, "force-stop was on an emulator")
    require(
        bool(termination["live_pid_before"]) and termination["pid_after"] == "",
        "force-stop PID proof missing",
    )
    require(
        termination["seed_driver_kept_app_running"] is True,
        "seed installation must survive driver teardown",
    )
    operation = reboot["operation"]
    require(operation["physical"] is False, "reboot was on an emulator")
    require(
        operation["boot_count_after"] > operation["boot_count_before"],
        "reboot counter did not advance",
    )
    require(
        operation["database_exists_before"] is True
        and operation["database_exists_before_recovery_driver"] is True,
        "pre-driver database proof missing",
    )
    require(
        bool(operation["live_pid_before"]) and operation["pid_after_boot_before_driver"] == "",
        "reboot PID proof missing",
    )
    require(
        reboot["network_state"]["default_network"] == "Active default network: none",
        "offline network receipt missing",
    )
    require(
        reboot["recovery_driver_kept_installation"] is True,
        "intermediate driver must preserve installation",
    )

    collector = android["profile_collector"]
    benchmark = receipt(collector)
    require(benchmark["run_completed"] is True, "benchmark workload incomplete")
    require(
        benchmark["build_revision"] == index["source_commit"] == native["source_commit"],
        "benchmark source mismatch",
    )
    require(benchmark["build_mode"] == "profile", "archived run must remain profile evidence")
    samples = benchmark["samples_us"]
    require(len(samples) == benchmark["sample_count"] == 200, "measured sample count mismatch")
    require(
        all(type(value) is int and value >= 0 for value in samples), "invalid measured duration"
    )
    require(
        benchmark["warmup_count"] == len(benchmark["warmup_samples_us"]) == 32,
        "warmup count mismatch",
    )
    require(benchmark["history_roots"] >= 100, "history workload incomplete")
    require(
        benchmark["failure_count"] == 0 and benchmark["failed_measurements"] == [],
        "failed writes cannot qualify",
    )
    ordered = sorted(samples)
    for label, fraction in (("p50_us", 0.5), ("p95_us", 0.95), ("p99_us", 0.99), ("max_us", 1.0)):
        require(
            benchmark[label] == ordered[math.ceil(fraction * len(ordered)) - 1],
            f"{label} disagrees with raw samples",
        )
    for flag in ("physical_performance_evidence", "target_met"):
        require(
            benchmark[flag] is False and collector[flag] is False, f"emulator cannot set {flag}"
        )
    for field in (
        "sample_count",
        "warmup_count",
        "history_roots",
        "failure_count",
        "p95_us",
        "build_mode",
    ):
        require(benchmark[field] == collector[field], f"collector summary mismatch: {field}")

    failed = load(folder / android["invalid_reboot_attempt"]["report"])
    require(
        failed["run_completed"] is False and failed["report_unavailable"] is True,
        "failed attempt must remain incomplete",
    )
    release = native["android_release_compile"]
    require(
        release["exit_code"] == 0 and release["unsigned"] is True,
        "release is compile-only and unsigned",
    )
    require(
        release["runtime_executed"] is False and release["signed_install_qualified"] is False,
        "unsigned compilation cannot qualify installation",
    )


if __name__ == "__main__":
    validate_evidence()
    print(
        "Archived mobile receipts verified: 200 emulator samples; "
        "zero physical samples; hardware gates open"
    )
