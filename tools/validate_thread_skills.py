#!/usr/bin/env python3
"""C03 data rules for thread skills: thread cost and action timing are the
main limit; cooldowns are short recovery locks, control keeps a gap, and no
skill can pay for itself."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFUNDS = {"crosscut": 10}  # player_controller.gd: empowered crosscut refunds at most 10 once


def validate(catalog: dict) -> list[str]:
    errors = []
    meter = min(int(c["max_energy"]) for c in catalog["crests"].values())
    rows = []
    for key, row in catalog["skills"].items():
        rows.append((key, row))
        # C04: every 校习 direction must keep the same limits as the base skill.
        branches = row.get("branches", {})
        if sorted(branches) != ["a", "b"]:
            errors.append(f"{key}: needs exactly two 校习 directions a and b")
        for branch, data in branches.items():
            variant = dict(row)
            for stat, delta in data.get("modifiers", {}).items():
                variant[stat] = variant.get(stat, 0) + delta
            if variant.get("kind") == "defense" and variant.get("duration", 0) > 0.65:
                errors.append(f"{key}/{branch}: guard window {variant['duration']} exceeds the 0.65 s runtime clamp")
            if min(variant["windup"], variant["recovery"], variant.get("damage", 0)) < 0:
                errors.append(f"{key}/{branch}: a modifier drives timing or damage below zero")
            rows.append((f"{key}/{branch}", variant))
    for key, row in rows:
        action = row["windup"] + row["active"] + row["recovery"] + (row.get("duration", 0) if row["kind"] == "defense" else 0)
        if row["kind"] == "control":
            if not row["cooldown"] > row.get("duration", 0):
                errors.append(f"{key}: control cooldown {row['cooldown']} must exceed its {row.get('duration')} s effect so it cannot chain-lock")
            if row["cooldown"] > 2.5:
                errors.append(f"{key}: control cooldown {row['cooldown']} is a multi-second gate")
        elif row["cooldown"] > action + 0.4:
            errors.append(f"{key}: cooldown {row['cooldown']} exceeds its {action:.2f} s action by more than 0.4 s")
        casts = meter // int(row["energy_cost"])
        if not 2 <= casts <= 5:
            errors.append(f"{key}: a full meter allows {casts} casts; thread cost should allow 2-5")
        if REFUNDS.get(key, 0) >= int(row["energy_cost"]):
            errors.append(f"{key}: refund {REFUNDS[key]} pays for the skill itself")
        if row.get("refund_on_interrupt") != 0:
            errors.append(f"{key}: interrupted casts must not refund")
    return errors


def main() -> int:
    errors = validate(json.loads((ROOT / "godot/data/build_catalog.json").read_text()))
    for error in errors:
        print("FAIL: " + error)
    print(f"THREAD_SKILLS {'FAIL' if errors else 'PASS'}: errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
