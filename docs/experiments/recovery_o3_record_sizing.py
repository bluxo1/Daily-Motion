"""Conservative documentation-shape sizing, not record validation/certification.

No database, identity or provider. Replaced fields invalidate the old example's
hashes intentionally: only encoded length is measured, never authentic evidence.
"""

import copy
import hashlib
import json
import sys
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "services/api"))

from daily_motion.contracts import CreateSession, ExerciseSnapshot, canonical_json  # noqa: E402
from daily_motion.recovery import MAX_COUNTER  # noqa: E402


def main() -> None:
    example = ROOT / "docs/evidence/recovery-o3-certificate-v1-example.json"
    original = json.loads(example.read_text(encoding="utf-8"))
    exercises = CreateSession.model_json_schema()["properties"]["exercises"]["maxItems"]
    sets = ExerciseSnapshot.model_json_schema()["properties"]["sets"]["maxItems"]
    total = 1 + exercises + exercises * sets
    observation = copy.deepcopy(original["observation"])
    certificate = copy.deepcopy(original["certificate"])
    committed = certificate["committed"]
    identifiers = sorted([committed["root"], *(str(UUID(int=n)) for n in range(1, total))])
    committed.update(
        affected_ids=identifiers,
        retired_ids=identifiers,
        activation_serial=MAX_COUNTER,
        private_position=MAX_COUNTER,
        erasure_epoch=MAX_COUNTER,
    )
    committed["outcome"].update(
        accepted_revision=MAX_COUNTER, accepted_at="9999-12-31T23:59:59.999999Z"
    )
    for record in (certificate, observation):
        record["committed"] = committed
        record["activation_binding"]["activation_serial"] = MAX_COUNTER
        record["prior_checkpoint"]["order"] = MAX_COUNTER - 2
        record["prior_checkpoint"]["digest"] = "e" * 64
        record["prepared_checkpoint"]["order"] = MAX_COUNTER - 1
    certificate["previous_checkpoint"]["order"] = MAX_COUNTER - 1
    certificate["checkpoint"]["order"] = MAX_COUNTER
    observation["append_predecessor"]["order"] = MAX_COUNTER - 1
    # Printable ASCII reference bytes can need two JSON bytes each.
    certificate["observation"]["verifier_principal_ref"] = "\\" * 256
    observation["verifier_principal_ref"] = "\\" * 256
    binding = certificate["activation_binding"]
    view = {
        "record_type": "dm.recovery.current_view",
        "record_version": 1,
        "request_nonce": observation["request_nonce"],
        "purpose": "workout_publish",
        "scope": {
            "environment": committed["environment"],
            "requested_activation": binding,
            "owner": committed["owner"],
            "attempt": committed["attempt"],
            "mutation": committed["mutation"],
            "request_digest": committed["request_digest"],
            "certificate_id": certificate["certificate_id"],
        },
        "current_activation": {**binding, "state": "ACTIVE"},
        "authority_root": {
            "record_type": "dm.recovery.authority_root",
            "record_version": 1,
            "environment": committed["environment"],
            "revision": MAX_COUNTER,
            "previous_root": "e" * 64,
            "state_digest": "e" * 64,
            "root_digest": "e" * 64,
        },
        "requested_activation_state": "ACTIVE",
        "current_owner": {
            "owner": committed["owner"],
            "generation": committed["generation"],
            "checkpoint": certificate["checkpoint"],
            "erasure_high_water": MAX_COUNTER,
            "lifecycle_state": "active",
            "inventory_ref": "e" * 64,
            "pending_attempt": None,
        },
        "certificate": certificate,
        "inclusion": {
            "certificate_id": certificate["certificate_id"],
            "owner_checkpoint": certificate["checkpoint"],
            "classification": "included_current",
        },
    }
    sizes = {
        name: len(canonical_json(body).encode("utf-8"))
        for name, body in {
            "observation": observation,
            "certificate": certificate,
            "publication_view": view,
        }.items()
    }
    print(
        json.dumps(
            {
                "scope": (
                    "Synthetic shape byte counts only; invalidated example hashes, "
                    "no validation/commit/authentication"
                ),
                "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "input_example_sha256": hashlib.sha256(example.read_bytes()).hexdigest(),
                "dto_exercises": exercises,
                "dto_sets_per_exercise": sets,
                "conservative_retired_id_count": total,
                "compact_utf8_bytes": sizes,
                "candidate_body_cap": 1048576,
                "all_measured_shapes_below_cap": all(size < 1048576 for size in sizes.values()),
                "limits": (
                    "DTO cardinality ceiling may exceed command byte admission; current workout "
                    "variant only, not lifecycle/complete inventory or arbitrary future versions."
                ),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
