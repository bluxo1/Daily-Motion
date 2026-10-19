"""Ephemeral, loopback-only operator bridge; no code/session values on disk."""

import ast
import datetime
import json
import os
import re
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

root = Path(__file__).resolve().parents[2]
addresses = {}
configuration = {}
state = {
    "started": False,
    "running": False,
    "passed": None,
    "case": None,
    "challenges": [],
    "codes": {},
    "events": [],
    "failure": None,
}
lock = threading.RLock()
cases = {"lifecycle": ("DM_HOSTED_AUTH_LIFECYCLE", "hosted_auth_lifecycle_test.dart")}
allowed_events = {
    "expiry_wait_started",
    "elapsed_otp_expiry_rejected",
    "fresh_delivered_code_verified_after_expiry",
    "qualification_session_signed_out",
    "provider_resend_throttle_passed",
    "incorrect_code_rejected",
    "a_verified",
    "b_verified",
    "sdk_refresh_passed",
    "retry_receipt_replay_passed",
    "controller_file_restart_passed",
    "remote_sign_out_pending_and_revocation_passed",
    "cross_owner_feed_and_mutation_denial_passed",
    "a_b_a_pending_recovery_and_hosted_bootstrap_passed",
}


def failure_summary(output, challenges):
    """Return only allowlisted categories and account-step metadata."""
    clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
    match = re.search(r"Hosted (verification|OTP request) failed:\s*([a-z_]+)", clean)
    permitted = {
        "invalid_or_expired_code",
        "throttled",
        "provider_unavailable",
        "network_unavailable",
        "timeout",
        "authentication_required",
        "initialization_failed",
        "wrong_owner",
        "local_storage_unavailable",
        "secure_storage_unavailable",
        "account_inactive",
    }
    stage, category = "test", "unclassified_failure"
    if match:
        stage = "verification" if match[1] == "verification" else "request"
        category = match[2] if match[2] in permitted else "unclassified_failure"
    elif "Recipient inbox verification timed out" in clean:
        stage, category = "manual_entry", "recipient_entry_timeout"
    last = challenges[-1] if challenges else {}
    return {
        "stage": stage,
        "category": category,
        "account": last.get("account") if last.get("account") in ("A", "B") else None,
        "step": len(challenges),
    }


def launch(case):
    flag, test = cases[case]
    env = {key: value for key, value in os.environ.items() if not key.startswith("DM_")}
    env.update(configuration)
    env.update(
        {
            flag: "1",
            "DM_HOSTED_MANUAL_OTP": "1",
            "DM_HOSTED_OTP_BRIDGE": f"http://127.0.0.1:{server.server_port}",
            "PUB_CACHE": str(root / ".tools/pub-cache"),
            "TEMP": str(root / ".tools/temp"),
            "TMP": str(root / ".tools/temp"),
        }
    )
    try:
        result = subprocess.run(
            [
                "cmd",
                "/d",
                "/c",
                str(root / ".tools/flutter/bin/flutter.bat"),
                "test",
                "--no-pub",
                f"test/{test}",
                "--reporter",
                "expanded",
            ],
            cwd=root / "apps/mobile",
            env=env,
            capture_output=True,
            text=True,
        )
    except Exception:
        with lock:
            state.update(
                failure=failure_summary("", state["challenges"]), passed=False, running=False
            )
        return
    with lock:
        failure = (
            failure_summary(result.stdout + result.stderr, state["challenges"])
            if result.returncode != 0
            else None
        )
        state.update(failure=failure, passed=result.returncode == 0, running=False)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        self.run_request()

    def do_POST(self):
        self.run_request()

    def run_request(self):
        try:
            self.handle_request()
        except Exception:
            self.respond({"error": "request_failed"}, 400)

    def handle_request(self):
        if (
            self.headers.get("X-DM-Qualification") != "phase0-local"
            or self.headers.get("Origin")
            or self.headers.get("Host") != f"127.0.0.1:{self.server.server_port}"
        ):
            return self.respond({"error": "denied"}, 403)
        if self.path in ("/start", "/code", "/event", "/shutdown") and self.command != "POST":
            return self.respond({"error": "method"}, 405)
        length = int(self.headers.get("Content-Length", "0"))
        if length < 0 or length > 4096:
            return self.respond({"error": "size"}, 413)
        data = json.loads(self.rfile.read(length)) if length else {}
        with lock:
            path = self.path
            if path == "/settings":
                return self.respond({"otp_expiry_seconds": 600})
            if path in ("/account/A", "/account/B"):
                return self.respond({"email": addresses[path[-1]]})
            if path == "/challenge" and self.command == "POST":
                sequence = ("A", "B", "A")
                step = len(state["challenges"])
                if (
                    step >= len(sequence)
                    or data.get("account") != sequence[step]
                    or step
                    and not state["challenges"][-1]["submitted"]
                ):
                    return self.respond({"error": "challenge"}, 409)
                item = {
                    "id": len(state["challenges"]) + 1,
                    "account": data["account"],
                    "email": addresses[data["account"]],
                    "requested_at": data["requested_at"],
                    "subject": "Your Daily Motion staging code",
                    "submitted": False,
                }
                state["challenges"].append(item)
                return self.respond({"id": item["id"]})
            if path == "/challenge":
                return self.respond(
                    {
                        "challenge": next(
                            (c for c in reversed(state["challenges"]) if not c["submitted"]), None
                        )
                    }
                )
            if path.startswith("/code/"):
                return self.respond({"code": state["codes"].pop(int(path.split("/")[-1]), None)})
            if path == "/code":
                item = next(c for c in state["challenges"] if c["id"] == data["id"])
                if (
                    item != state["challenges"][-1]
                    or item["submitted"]
                    or not re.fullmatch(r"[0-9]{6}", str(data["code"]))
                ):
                    return self.respond({"error": "invalid"}, 400)
                state["codes"][item["id"]] = data["code"]
                item["submitted"] = True
                return self.respond({"submitted": True})
            if path == "/event":
                if data.get("event") not in allowed_events:
                    return self.respond({"error": "event"}, 400)
                item = {
                    "event": data["event"],
                    "at": datetime.datetime.now(datetime.UTC).isoformat(),
                }
                for key in ("configured_seconds", "elapsed_seconds"):
                    if isinstance(data.get(key), int):
                        item[key] = data[key]
                state["events"].append(item)
                return self.respond({"recorded": True})
            if path == "/start":
                case = data.get("case")
                if state["started"] or state["running"] or case not in cases:
                    return self.respond({"error": "unavailable"}, 409)
                state.update(
                    started=True,
                    running=True,
                    passed=None,
                    case=case,
                    challenges=[],
                    codes={},
                    events=[],
                    failure=None,
                )
                threading.Thread(target=launch, args=(case,), daemon=True).start()
                return self.respond({"started": True, "case": case})
            if path == "/status":
                return self.respond(
                    {k: state[k] for k in ("running", "passed", "case", "events")}
                    | {
                        "challenge_count": len(state["challenges"]),
                        "submitted_codes": sum(c["submitted"] for c in state["challenges"]),
                    }
                )
            if path == "/diagnostic":
                # Redaction patterns cannot recognize every refresh-token format.
                # Expose only classifications; raw reporter output never leaves launch().
                return self.respond({"failure": state["failure"]})
            if path == "/result":
                return self.respond(
                    {
                        "running": state["running"],
                        "passed": state["passed"],
                        "failure": state["failure"],
                    }
                )
            if path == "/shutdown":
                if state["running"]:
                    return self.respond({"error": "running"}, 409)
                state["codes"].clear()
                state["failure"] = None
                self.respond({"stopped": True})
                threading.Thread(target=server.shutdown, daemon=True).start()
                return
            self.respond({"error": "not_found"}, 404)


def private_inputs():
    module = ast.parse((root / ".tools/staging/otp_request_probe.py").read_text())
    recipients = next(
        ast.literal_eval(n.value)
        for n in module.body
        if isinstance(n, ast.Assign)
        and any(isinstance(t, ast.Name) and t.id == "emails" for t in n.targets)
    )
    client = json.loads((root / ".tools/staging/mobile.json").read_text())
    expected = {"DM_ENVIRONMENT", "DM_SUPABASE_URL", "DM_SUPABASE_PUBLISHABLE_KEY", "DM_API_URL"}
    if (
        set(client) != expected
        or not all(isinstance(value, str) for value in client.values())
        or client["DM_ENVIRONMENT"] != "staging"
        or client["DM_SUPABASE_URL"].rstrip("/") != "https://pulruylvpehwftwqcvct.supabase.co"
        or client["DM_API_URL"].rstrip("/") != "https://daily-motion-staging-api.onrender.com"
        or not client["DM_SUPABASE_PUBLISHABLE_KEY"].startswith("sb_publishable_")
        or set(recipients) != {"A", "B"}
        or not all(isinstance(value, str) and "@" in value for value in recipients.values())
        or recipients["A"].strip().lower() == recipients["B"].strip().lower()
    ):
        raise ValueError("Private qualification configuration is invalid")
    return recipients, client


def main():
    global addresses, configuration, server
    try:
        addresses, configuration = private_inputs()
    except Exception:
        print(json.dumps({"ready": False, "error": "private_configuration_invalid"}), flush=True)
        return
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print(json.dumps({"bridge_port": server.server_port, "ready": True}), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
