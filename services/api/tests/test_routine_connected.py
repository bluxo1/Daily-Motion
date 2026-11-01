"""Separate strict connected routine acceptance; existing nine-case parser is unchanged."""

import json
import subprocess
from pathlib import Path
from uuid import UUID

import pytest

from tests.test_flutter_connected import run_flutter_http, unique_json_object

ROUTINE_CONNECTED_CASES = {
    "routine offline reopen, cloud publication, second-device start and measured history",
    "routine concurrent edits retain both branches and independent workout delivery",
    "routine response loss and restart preserve frozen requests and newer server shadow",
    "routine bootstrap activation preserves an edit committed during download",
    "routine post-activation failure preserves installed state and both pending outboxes "
    "after restart",
    "routine owner isolation and unavailable capability preserve private local work",
    "routine TCP interruptions and acknowledgement rollback recover exact frozen publications",
    "routine HTTP failures and partial sends retain mixed frozen heads through restart",
    "routine valid workout erasure preserves planning roots on both installations",
    "routine local edit during a held HTTP acknowledgement preserves both publications",
    "routine expired JWT preserves offline edits and resumes the original publication chain",
    "routine in-flight account sign-out drains A before B and restores A with verified ownership",
    "routine authoritative retirement purges local planning and rejects stale JWT resurrection",
    "routine real HTTP restore renders History, measured charts and exact source workout routes",
    "routine hundreds-of-roots offline journal restores paged immutable history "
    "with stable variants",
}


def routine_connected_passed(output: str) -> bool:
    events = []
    for line in output.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line, object_pairs_hook=unique_json_object)
        except json.JSONDecodeError:
            # Flutter can print dependency progress before its machine stream.
            # Once events begin, malformed/trailing output cannot imply success.
            if events or line.lstrip().startswith(("{", "[")):
                return False
            continue
        except ValueError:
            # Reject duplicate keys at every depth without exposing their content.
            return False
        if events and events[-1].get("type") == "done":
            return False
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
            return False
        events.append(event)
    if (
        not events
        or events[0].get("type") != "start"
        # Flutter 3.47.7's pinned test_core reporter emits protocol 0.1.1.
        # A different protocol requires an explicit compatibility review.
        or events[0].get("protocolVersion") != "0.1.1"
        or sum(event.get("type") == "start" for event in events) != 1
        or events[-1].get("type") != "done"
        or events[-1].get("success") is not True
        or sum(event.get("type") == "done" for event in events) != 1
    ):
        return False
    suites: dict[int, str] = {}
    started: dict[int, str] = {}
    completed: set[int] = set()
    passed: set[str] = set()
    suite_count: int | None = None
    try:
        for event in events:
            kind = event["type"]
            if kind == "suite":
                suite = event["suite"]
                identity = suite["id"]
                if type(identity) is not int or identity in suites:
                    return False
                filename = suite["path"].replace("\\", "/")
                if not filename.endswith("/apps/mobile/test/routine_connected_http_test.dart"):
                    return False
                suites[identity] = filename
            elif kind == "testStart":
                test = event["test"]
                identity, suite_id, name = test["id"], test["suiteID"], test["name"]
                if (
                    type(identity) is not int
                    or identity in started
                    or type(suite_id) is not int
                    or suite_id not in suites
                    or not isinstance(name, str)
                    or not name
                ):
                    return False
                started[identity] = name
            elif kind == "testDone":
                identity = event["testID"]
                if (
                    type(identity) is not int
                    or identity not in started
                    or identity in completed
                    or event["skipped"] is not False
                    or event["result"] != "success"
                    or type(event["hidden"]) is not bool
                ):
                    return False
                completed.add(identity)
                if not event["hidden"]:
                    name = started[identity]
                    if name not in ROUTINE_CONNECTED_CASES or name in passed:
                        return False
                    passed.add(name)
            elif kind == "allSuites":
                # Scheduling may finish before tests do. Compare only at the end.
                if suite_count is not None or type(event["count"]) is not int:
                    return False
                suite_count = event["count"]
            elif kind not in {"start", "group", "print", "debug", "done"}:
                return False
    except (KeyError, TypeError, AttributeError):
        return False
    return (
        len(suites) == 1
        and suite_count == len(suites)
        and completed == set(started)
        and passed == ROUTINE_CONNECTED_CASES
    )


def assert_routine_connected_result(result: subprocess.CompletedProcess[str]) -> None:
    assert result.returncode == 0, "Routine connected Flutter HTTP/PostgreSQL process failed"
    assert routine_connected_passed(result.stdout), (
        "Routine connected cases were skipped, failed or incomplete"
    )


def test_routine_http_with_real_postgres(
    owner: UUID, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    run_flutter_http(
        owner,
        monkeypatch,
        tmp_path,
        test_file="routine_connected_http_test.dart",
        validate_result=assert_routine_connected_result,
        case_count=len(ROUTINE_CONNECTED_CASES),
        timeout=1200,
        with_retirement_control=True,
    )


def routine_events() -> list[dict]:
    events = [
        {"type": "start", "protocolVersion": "0.1.1"},
        {
            "type": "suite",
            "suite": {"id": 0, "path": "/owned/apps/mobile/test/routine_connected_http_test.dart"},
        },
    ]
    for identity, name in enumerate(sorted(ROUTINE_CONNECTED_CASES)):
        events.extend(
            [
                {"type": "testStart", "test": {"id": identity, "name": name, "suiteID": 0}},
                {
                    "type": "testDone",
                    "testID": identity,
                    "skipped": False,
                    "hidden": False,
                    "result": "success",
                },
            ]
        )
    events.extend([{"type": "allSuites", "count": 1}, {"type": "done", "success": True}])
    return events


@pytest.mark.parametrize(
    "fault",
    [
        None,
        "skip",
        "error",
        "hidden",
        "missing_done",
        "duplicate_done",
        "duplicate_completion",
        "duplicate_start",
        "unknown_case",
        "wrong_file",
        "unfinished_case",
        "missing_summary",
        "bool_identity",
        "duplicate_keys",
        "trailing_error",
        "malformed_json",
    ],
)
def test_routine_report_retains_strict_named_case_and_completion_controls(
    fault: str | None,
) -> None:
    events = routine_events()
    if fault == "skip":
        events[3]["skipped"] = True
    elif fault == "error":
        events[3]["result"] = "error"
    elif fault == "hidden":
        events[3]["hidden"] = True
    elif fault == "missing_done":
        events.pop()
    elif fault == "duplicate_done":
        events.append(events[-1])
    elif fault == "duplicate_completion":
        events.insert(4, events[3])
    elif fault == "duplicate_start":
        events.insert(4, events[2])
    elif fault == "unknown_case":
        events[2]["test"]["name"] = "Unrelated passing test"
    elif fault == "wrong_file":
        events[1]["suite"]["path"] = "/unrelated_test.dart"
    elif fault == "unfinished_case":
        events.pop(3)
    elif fault == "missing_summary":
        events.pop(-2)
    elif fault == "bool_identity":
        events[2]["test"]["id"] = False
    output = "\n".join(json.dumps(event) for event in events)
    if fault == "duplicate_keys":
        output = output.replace('"success": true', '"success": false,"success":true')
    elif fault == "trailing_error":
        output += "\nUnhandled failure"
    elif fault == "malformed_json":
        output = output.replace('"type": "testStart"', '"type": ', 1)
    assert routine_connected_passed(output) is (fault is None)
