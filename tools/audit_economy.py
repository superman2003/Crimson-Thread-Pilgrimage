#!/usr/bin/env python3
"""G01 economy audit: rosin currency, regional materials and their sinks.

Recomputes the one-time (non-farmed) income of every region and the one-time
sinks, then enforces the invariants the plan asks for: maps are priced from
normal exploration income and affordable on a first pass, no purchase
requires grinding, late-game purchases still exist, and every tool's resupply
material drops where the tool is obtained. Enemies respawn at shrines, so
farming is possible; the audit only proves it is never required.
"""
from __future__ import annotations
import argparse
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot/data"
MAIN = ROOT / "godot/scripts/main_level.gd"
# Kill rewards live in main_level.gd; the audit fails if they drift.
KILL_CURRENCY = 8
BOSS_CURRENCY = 30
ELITE_FIRST_CURRENCY = 30        # main_level.gd: one-time bonus for each elite's first defeat
MAP_SHARE_OF_FIRST_CLEAR = 0.5   # a map costs at most half the region's first-clear kill income
TOOL_REFILL_KILLS = 2            # a full tool refill costs at most two regular kills
UPGRADED_REFILL_KILLS = 3        # with every capacity upgrade owned, at most three
ARTISANS = ("npc_threadsmith_apprentice", "npc_rain_smith_liu", "npc_beeswax_vendor")
INCOME_HEADROOM = 1.5            # one-time income covers one-time sinks 1.5x: no forced grind
MIN_SINK_SHARE = 0.35            # but sinks still take at least 35% of it: money matters late


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def audit() -> tuple[dict, list[str]]:
    errors: list[str] = []
    main = MAIN.read_text(encoding="utf-8")
    # The runtime must charge the seller's price, not a shared constant.
    cartography = (ROOT / "godot/scripts/cartography_runtime.gd").read_text(encoding="utf-8")
    if 'seller.get("price"' not in cartography or "JOURNAL.PRICE," in cartography.replace("JOURNAL.PRICE))", ""):
        errors.append("cartography_runtime.gd must charge each seller's own price from cartography_sellers.json")
    for amount in (KILL_CURRENCY, BOSS_CURRENCY):
        if f"_add_currency({amount})" not in main:
            errors.append(f"main_level.gd no longer grants {amount} currency; update the audit constants")
    if f"const ELITE_FIRST_CURRENCY := {ELITE_FIRST_CURRENCY}" not in main:
        errors.append("main_level.gd elite first-defeat bonus changed; update the audit constant")
    chapters = sorted(load("campaign_chapters.json").get("chapters", []), key=lambda c: int(c.get("index", 0)))
    order = [str(c.get("runtime_config_id", "")) for c in chapters]
    routes = load("world_routes.json")["chapters"]
    sellers = load("cartography_sellers.json")
    catalog = load("build_catalog.json")
    narrative = load("world_narrative.json")
    regions = sorted(routes)
    rows = {}
    challenge_patterns: dict[str, str] = {}
    for cid in regions:
        config = load(f"{cid}.json")
        kills = len(config.get("enemy_spawns", [])) * KILL_CURRENCY
        elites = sum(1 for s in config.get("enemy_spawns", []) if s.get("elite")) * ELITE_FIRST_CURRENCY
        workshops = sum(int(c.get("amount", 0)) for c in routes[cid].get("collectibles", []) if c.get("kind") == "currency")
        # B04 optional challenges: one-time clear currency. Challenge foes pay no per-kill loot.
        challenges = sum(int((c.get("reward") or {}).get("currency", 0)) for c in config.get("optional_challenges", []) if isinstance(c, dict))
        for challenge in config.get("optional_challenges", []):
            item = str(((challenge or {}).get("reward") or {}).get("item_id", ""))
            if item:
                challenge_patterns[item] = cid
        rows[cid] = {"first_clear_kills": kills, "boss": BOSS_CURRENCY if config.get("boss") else 0, "workshops": workshops,
                     "optional_challenges": challenges, "elite_first": elites, "quests": 0, "map_price": int(sellers.get(cid, {}).get("price", 0)), "drop": config.get("enemy_drop_item", "")}
    region_by_short = {cid.replace("demo_", ""): cid for cid in regions}
    tool_region: dict[str, str] = {}
    npcs = narrative["npcs"]
    for npc_id, npc in (npcs.items() if isinstance(npcs, dict) else [(n.get("id"), n) for n in npcs]):
        region = region_by_short.get(str(npc.get("region_id", npc.get("region", ""))), "")
        granted_currency = 0
        for state in npc.get("states", []):
            granted_currency = max(granted_currency, int((state.get("grant_rewards") or {}).get("currency", 0)))
            for flag in state.get("grant_flags", []):
                if flag.startswith("tool_") and flag.endswith("_found"):
                    tool_region.setdefault(flag[len("tool_"):-len("_found")], region)
        if region:
            rows[region]["quests"] += granted_currency
    # Map prices: affordable from the region's own first clear, never cheaper later on the route.
    previous = 0
    for cid in [c for c in order if c in rows] or regions:
        row = rows[cid]
        limit = math.floor(row["first_clear_kills"] * MAP_SHARE_OF_FIRST_CLEAR)
        if not 0 < row["map_price"] <= limit:
            errors.append(f"{cid}: map price {row['map_price']} must be 1..{limit} (half the first-clear kill income)")
        if row["map_price"] < previous:
            errors.append(f"{cid}: map price {row['map_price']} is cheaper than an earlier region's {previous}")
        previous = row["map_price"]
    # Tools: the material is the drop of the region that grants the tool; refills stay cheap.
    first_region = ([c for c in order if c in rows] or regions)[0]
    for tool_id, tool in catalog["tools"].items():
        region = tool_region.get(tool_id, first_region)
        materials = tool.get("resupply", {}).get("materials", {})
        for material in materials:
            if material != rows[region]["drop"]:
                errors.append(f"{tool_id}: resupply material {material} does not drop in {region} where the tool is obtained ({rows[region]['drop']})")
        # build_system.tool_capacity(): capacity bonuses (needlecase) apply to shard and mine.
        bonus = max(int(p.get("modifiers", {}).get("tool_capacity_bonus", 0)) for p in catalog["passives"].values()) if tool_id in ("shard", "mine") else 0
        refill = int(tool.get("resupply", {}).get("currency", 0)) * (int(tool.get("capacity", 0)) + bonus)
        if refill > TOOL_REFILL_KILLS * KILL_CURRENCY:
            errors.append(f"{tool_id}: a full refill costs {refill}, more than {TOOL_REFILL_KILLS} regular kills")
        # E04: artisan capacity upgrades raise the refill bill, but not past three kills.
        crafted = sum(int(r.get("amount", 0)) for r in catalog["recipes"].values() if r.get("kind") == "tool_capacity" and r.get("target") == tool_id)
        upgraded = int(tool.get("resupply", {}).get("currency", 0)) * (int(tool.get("capacity", 0)) + bonus + crafted)
        if upgraded > UPGRADED_REFILL_KILLS * KILL_CURRENCY:
            errors.append(f"{tool_id}: a full refill with every capacity upgrade costs {upgraded}, more than {UPGRADED_REFILL_KILLS} regular kills")
    # E04: artisan crafts use a challenge's evidence as a pattern (never consumed),
    # a material that drops somewhere, and a named artisan who actually exists.
    drops = {r["drop"]: cid for cid, r in rows.items()}
    crafts = 0
    for recipe_id, recipe in catalog["recipes"].items():
        if recipe.get("kind") not in ("tool_capacity", "slot_part"):
            continue
        crafts += int(recipe.get("currency", 0))
        if recipe.get("artisan") not in ARTISANS or recipe.get("artisan") not in npcs:
            errors.append(f"{recipe_id}: artisan {recipe.get('artisan')} is not one of the three artisans")
        patterns = recipe.get("requires_items", [])
        if not patterns:
            errors.append(f"{recipe_id}: an artisan craft needs a pattern from an optional challenge")
        for item in patterns:
            if item not in challenge_patterns:
                errors.append(f"{recipe_id}: pattern {item} is not an optional challenge reward")
        for material in recipe.get("materials", {}):
            if material not in drops:
                errors.append(f"{recipe_id}: material {material} drops in no region")
        if recipe.get("kind") == "tool_capacity":
            tool = catalog["tools"].get(recipe.get("target"), {})
            if set(recipe.get("materials", {})) != set(tool.get("resupply", {}).get("materials", {})):
                errors.append(f"{recipe_id}: a capacity upgrade uses the tool's own resupply material")
        if recipe.get("kind") == "slot_part":
            parts = [s for c in catalog["crests"].values() for slots in c.get("slot_layout", {}).values() for s in slots if s.get("requires_part") == recipe.get("part")]
            if len(parts) != len(catalog["crests"]) or any(not s.get("requires_mechanism") for s in parts):
                errors.append(f"{recipe_id}: part {recipe.get('part')} must open one mechanism-gated slot on every crest")
    # Totals.
    income = sum(r["first_clear_kills"] + r["elite_first"] + r["boss"] + r["workshops"] + r["optional_challenges"] + r["quests"] for r in rows.values())
    maps = sum(r["map_price"] for r in rows.values())
    # C04: each skill takes one 校习 direction; count the cheaper one as the
    # one-time sink. Switching direction later is an optional repeat purchase.
    cheapest_branch: dict[str, int] = {}
    for recipe in catalog["recipes"].values():
        if recipe.get("kind") == "skill_branch":
            target = recipe["target"]
            cheapest_branch[target] = min(cheapest_branch.get(target, 10**9), int(recipe["currency"]))
    for skill_id in catalog["skills"]:
        if skill_id not in cheapest_branch:
            errors.append(f"{skill_id}: no 校习 direction can be bought")
    skills = sum(cheapest_branch.values())
    sinks = maps + skills + crafts
    if income < INCOME_HEADROOM * sinks:
        errors.append(f"one-time income {income} is below {INCOME_HEADROOM}x one-time sinks {sinks}: purchases would need grinding")
    if sinks < MIN_SINK_SHARE * income:
        errors.append(f"one-time sinks {sinks} are under {MIN_SINK_SHARE:.0%} of income {income}: late currency has nothing to buy")
    report = {"regions": rows, "tool_regions": tool_region, "one_time_income": income, "map_sinks": maps,
              "skill_upgrade_sinks": skills, "artisan_craft_sinks": crafts, "one_time_sinks": sinks, "sink_share": round(sinks / income, 3) if income else 0}
    return report, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", help="write the full audit table as JSON")
    args = parser.parse_args()
    report, errors = audit()
    if args.report:
        Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    for error in errors:
        print("FAIL: " + error)
    print(f"ECONOMY_AUDIT {'FAIL' if errors else 'PASS'}: income={report['one_time_income']} sinks={report['one_time_sinks']} "
          f"share={report['sink_share']} maps={report['map_sinks']} skills={report['skill_upgrade_sinks']} crafts={report['artisan_craft_sinks']} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
