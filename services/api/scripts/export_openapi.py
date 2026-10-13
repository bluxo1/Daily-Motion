import json
from pathlib import Path

from daily_motion.main import app

target = Path(__file__).resolve().parents[3] / "contracts/openapi.json"
target.write_text(
    json.dumps(app.openapi(), indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
)
print(f"Wrote {target.name}")
