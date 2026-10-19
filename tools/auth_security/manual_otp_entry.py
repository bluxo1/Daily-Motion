"""Local masked entry for the existing hosted SDK harness; no inbox automation."""

import json
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox
from urllib.request import Request, urlopen


def call(port, path, data=None):
    request = Request(
        f"http://127.0.0.1:{port}{path}",
        data=json.dumps(data).encode() if data is not None else None,
        headers={
            "X-DM-Qualification": "phase0-local",
            "Content-Type": "application/json",
        },
    )
    with urlopen(request, timeout=2) as response:
        return json.load(response)


class ManualEntry:
    def __init__(self, window, port):
        self.window = window
        self.port = port
        self.challenge_id = None
        self.running = False
        self.started = False
        self.last_status = None
        window.title("Daily Motion - private hosted qualification")
        window.geometry("700x450")
        self.message = tk.StringVar(
            value="Ready for staging A -> B -> A. Start when your inbox is ready.\n"
            "One fresh request per step; no automatic resend or incorrect-code probe."
        )
        tk.Label(window, textvariable=self.message, wraplength=600, justify="left").pack(
            padx=20, pady=(20, 8), anchor="w"
        )
        tk.Label(
            window,
            text="Read your inbox yourself. TYPE the newest requested six-digit code.\n"
            "Do not paste it here or into chat. Nothing is written to a code file.",
            justify="left",
        ).pack(padx=20, pady=8, anchor="w")
        self.code = tk.StringVar()
        self.entry = tk.Entry(window, textvariable=self.code, show="*", width=16)
        self.entry.pack(padx=20, pady=8, anchor="w")
        self.entry.configure(state="disabled")
        for binding in (
            "<<Copy>>",
            "<<Cut>>",
            "<<Paste>>",
            "<Control-c>",
            "<Control-x>",
            "<Control-v>",
            "<Control-Insert>",
            "<Shift-Insert>",
        ):
            self.entry.bind(binding, lambda event: "break")
        self.entry.bind("<Return>", lambda event: self.submit())
        self.submit_button = tk.Button(window, text="Submit code", command=self.submit)
        self.submit_button.pack(padx=20, pady=4, anchor="w")
        self.submit_button.configure(state="disabled")
        self.start_button = tk.Button(window, text="Start hosted qualification", command=self.start)
        self.start_button.pack(padx=20, pady=8, anchor="w")
        window.protocol("WM_DELETE_WINDOW", self.close)
        window.after(500, self.poll)
        window.attributes("-topmost", True)
        window.after(10000, lambda: window.attributes("-topmost", False))

    def start(self):
        if self.started:
            return
        try:
            result = call(self.port, "/start", {"case": "lifecycle"})
            if not result.get("started"):
                raise ValueError()
        except Exception:
            self.message.set("Could not start. No code was submitted.")
            return
        self.started = True
        self.running = True
        self.start_button.configure(state="disabled")
        self.message.set("Running against staging. Waiting for a fresh OTP request...")

    def submit(self):
        if self.challenge_id is None or not self.running:
            self.code.set("")
            return
        code = self.code.get()
        self.code.set("")
        if len(code) != 6 or not code.isascii() or not code.isdecimal():
            self.message.set("Enter exactly six digits for the current request.")
            return
        try:
            result = call(self.port, "/code", {"id": self.challenge_id, "code": code})
            if not result.get("submitted"):
                raise ValueError()
        except Exception:
            self.message.set("Code submission failed. Wait for status before retrying.")
            return
        finally:
            code = None
        self.submit_button.configure(state="disabled")
        self.entry.configure(state="disabled")
        self.message.set("Code sent privately to the Flutter test. Waiting for verification...")

    def poll(self):
        try:
            status = call(self.port, "/status")
            if status != self.last_status:
                print(json.dumps({"qualification_status": status}), flush=True)
                self.last_status = status
            self.running = status["running"]
            if self.started and not self.running:
                self.code.set("")
                self.submit_button.configure(state="disabled")
                self.entry.configure(state="disabled")
                if status["passed"]:
                    self.message.set("PASS: hosted SDK, refresh, receipts, restart and isolation.")
                else:
                    failure = call(self.port, "/result").get("failure") or {}
                    step = failure.get("step", status["challenge_count"])
                    account = failure.get("account") or "unknown"
                    returning = " (return to A)" if step == 3 and account == "A" else ""
                    self.message.set(
                        f"STOPPED at step {step}/3: Account {account}{returning}.\n"
                        f"Stage: {failure.get('stage', 'test')}; "
                        f"category: {failure.get('category', 'unclassified_failure')}.\n"
                        f"Preserved {len(status['events'])} passing checkpoint events. "
                        "No OTP will be resent. Diagnosis is required before another run."
                    )
            elif self.running:
                challenge = call(self.port, "/challenge")["challenge"]
                if challenge:
                    if challenge["id"] != self.challenge_id:
                        self.challenge_id = challenge["id"]
                        self.code.set("")
                        self.message.set(
                            f"Step {challenge['id']}/3: Account {challenge['account']}"
                            f"{' (return to A)' if challenge['id'] == 3 else ''}: "
                            f"{challenge['email']}\n"
                            f"Use the newest code requested at {challenge['requested_at']}."
                        )
                        self.entry.focus_set()
                        self.window.bell()
                    self.submit_button.configure(state="normal")
                    self.entry.configure(state="normal")
                else:
                    self.submit_button.configure(state="disabled")
                    self.entry.configure(state="disabled")
        except Exception:
            self.code.set("")
            self.submit_button.configure(state="disabled")
            self.entry.configure(state="disabled")
            self.message.set("Local bridge unavailable. No code is displayed or retained here.")
        self.window.after(500, self.poll)

    def close(self):
        self.code.set("")
        if self.running:
            messagebox.showinfo(
                "Qualification active",
                "Enter the requested code, or leave the input empty until the bounded test "
                "times out. This preserves orderly SDK cleanup.",
            )
            return
        self.window.destroy()


def main():
    bridge = subprocess.Popen(
        [sys.executable, str(Path(__file__).with_name("operator_bridge.py"))],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    try:
        initial = json.loads(bridge.stdout.readline())
        port = initial["bridge_port"]
        window = tk.Tk()
        ManualEntry(window, port)
        print(json.dumps({"manual_entry_ready": True, "bridge_port": port}), flush=True)
        window.mainloop()
        call(port, "/shutdown", {})
    except Exception:
        print(json.dumps({"manual_entry_error": "local_ui_unavailable"}), flush=True)
    finally:
        if bridge.poll() is None:
            bridge.terminate()
            bridge.wait(timeout=5)


if __name__ == "__main__":
    main()
