"""Check repository Markdown links, UTF-8 and fenced JSON without external tools."""

import json
import re
from pathlib import Path
from urllib.parse import unquote

root = Path(__file__).resolve().parents[1]
paths = [root / "README.md", *sorted((root / "docs").glob("*.md"))]
paths.extend(root / relative for relative in ["contracts/README.md", "infra/README.md"])
links = examples = 0
for path in paths:
    content = path.read_text(encoding="utf-8")
    if not content.endswith("\n"):
        raise ValueError(f"Missing final newline: {path.relative_to(root)}")
    if len(re.findall(r"^```", content, flags=re.MULTILINE)) % 2:
        raise ValueError(f"Unclosed code fence: {path.relative_to(root)}")
    for match in re.finditer(r"\[[^\]]+\]\(([^)]+)\)", content):
        target = match[1].split("#", 1)[0]
        if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        resolved = path.parent / unquote(target)
        if not resolved.exists():
            raise ValueError(f"Broken link in {path.relative_to(root)}: {target}")
        links += 1
    for match in re.finditer(r"^```json\s*\n(.*?)^```", content, flags=re.MULTILINE | re.DOTALL):
        json.loads(match[1])
        examples += 1
print(f"Validated {len(paths)} Markdown files, {links} local links and {examples} JSON examples")
