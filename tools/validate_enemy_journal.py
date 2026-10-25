"""Keep localized battle notes complete and aligned with authored enemy behavior."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def validate() -> list[str]:
    combat = json.loads((ROOT / "godot/data/original_creature_combat.json").read_text(encoding="utf8"))
    journal = json.loads((ROOT / "godot/data/enemy_journal.json").read_text(encoding="utf8"))
    entries = journal.get("entries", {})
    errors = []
    if journal.get("version") != 1 or set(entries) != set(combat):
        errors.append("journal must cover exactly the authored enemy kinds")
    for kind, entry in entries.items():
        name = entry.get("name", "")
        if not re.search(r"[\u4e00-\u9fff]", name) or kind in name:
            errors.append(f"{kind}: needs a localized player-facing name")
        if entry.get("habit") != combat.get(kind, {}).get("combat_identity"):
            errors.append(f"{kind}: battle note differs from its actual combat identity")
        for field in ("warning", "response"):
            value = entry.get(field)
            if not isinstance(value, str) or not value.strip() or not re.search(r"[\u4e00-\u9fff]", value):
                errors.append(f"{kind}: needs a localized {field} note")
    return errors


if __name__ == "__main__":
    failures = validate()
    for failure in failures:
        print("FAIL: " + failure)
    print(f"ENEMY_JOURNAL_DATA errors={len(failures)}")
    raise SystemExit(bool(failures))
