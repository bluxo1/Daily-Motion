import base64
import importlib.util
import json
from pathlib import Path

import pytest

from daily_motion.config import Settings

spec = importlib.util.spec_from_file_location(
    "credential_guard", Path(__file__).resolve().parents[3] / "tools/check_secrets.py"
)
assert spec is not None and spec.loader is not None
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


@pytest.mark.parametrize("role", ["authenticated", "service_role", None])
def test_guard_rejects_literal_non_publishable_jwts(role: str | None) -> None:
    def segment(value: object) -> bytes:
        return base64.urlsafe_b64encode(json.dumps(value).encode()).rstrip(b"=")

    token = b".".join([segment({"alg": "HS256"}), segment({"role": role}), b"x" * 32])
    assert guard.findings(b"first line\n" + token) == [(2, "non-publishable JWT")]
    assert token.decode() not in repr(guard.findings(token))


def test_guard_allows_client_safe_keys_and_rejects_private_material() -> None:
    header = base64.urlsafe_b64encode(b'{"alg":"HS256"}').rstrip(b"=")
    payload = base64.urlsafe_b64encode(b'{"role":"anon"}').rstrip(b"=")
    assert guard.findings(b".".join([header, payload, b"x" * 32])) == []
    assert guard.findings(b"sb_publishable_" + b"x" * 32) == []
    assert guard.findings(b"-----BEGIN PUBLIC KEY-----") == []
    for material in [
        b"-----BEGIN " + b"EC PRIVATE KEY-----",
        b"sb_secret_" + b"x" * 32,
        b"ghp_" + b"x" * 32,
        b"github_pat_" + b"x" * 32,
    ]:
        found = guard.findings(material)
        assert len(found) == 1
        assert material.decode() not in repr(found)


def test_configuration_repr_does_not_expose_connection_or_signing_credentials() -> None:
    values = {
        "database_url": "postgresql://fixture:synthetic-password@localhost/test",
        "sync_signing_key": "synthetic-repr-redaction-key",
        "supabase_publishable_key": "sb_publishable_synthetic-repr-key",
    }
    rendered = repr(Settings(**values))
    assert all(value not in rendered for value in values.values())
