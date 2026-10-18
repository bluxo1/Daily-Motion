"""Scan versioned/source files without ever printing a matched credential.

This is a small CI guard, not a claim of a comprehensive security audit. Public
keys/publishable anon JWTs are allowed; private keys and user/service JWTs are not.
"""

import base64
import json
import re
import subprocess
from pathlib import Path

PATTERNS = {
    "private key": re.compile(rb"-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----"),
    "Supabase secret key": re.compile(rb"\bsb_secret_[A-Za-z0-9_-]{20,}\b"),
    "GitHub credential": re.compile(
        rb"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"
    ),
    "AWS access key": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "Render hook credential": re.compile(
        rb"https://api\.render\.com/(?:deploy|sync)/[A-Za-z0-9_-]+"
        rb"\?[^\s\"'<>]*\bkey=[^&\s\"'<>]+",
        re.IGNORECASE,
    ),
}
JWT = re.compile(rb"\beyJ[A-Za-z0-9_-]{9,}\.([A-Za-z0-9_-]{12,})\.[A-Za-z0-9_-]{16,}\b")


def findings(content: bytes) -> list[tuple[int, str]]:
    result = [
        (content[: match.start()].count(b"\n") + 1, category)
        for category, pattern in PATTERNS.items()
        for match in pattern.finditer(content)
    ]
    for match in JWT.finditer(content):
        payload = match[1]
        try:
            claims = json.loads(base64.urlsafe_b64decode(payload + b"=" * (-len(payload) % 4)))
        except (ValueError, UnicodeDecodeError):
            # Malformed JWT-looking material is not a verified publishable key.
            claims = None
        if not isinstance(claims, dict) or claims.get("role") != "anon":
            result.append((content[: match.start()].count(b"\n") + 1, "non-publishable JWT"))
    return sorted(result)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root
    ).split(b"\0")
    count = failures = 0
    for raw in sorted(set(paths)):
        if not raw:
            continue
        path = root / raw.decode("utf-8")
        if not path.is_file():
            continue
        count += 1
        for line, category in findings(path.read_bytes()):
            # No snippets, tokens or provider exception text reaches CI output.
            print(f"{path.relative_to(root).as_posix()}:{line}: prohibited {category}")
            failures += 1
    print(f"Credential guard: {count} source files checked, {failures} findings")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
