#!/usr/bin/env python3
"""List the creature frames most worth redrawing, most visible and most broken first.

Report only: nothing here gates CI or changes the game. For every clip the
game plays (same layer order as hand_drawn_assets.character_manifest) it marks

- size: frames whose body is 8% or more larger / smaller than the frames around
  them (frame_fit.json from tools/build_creature_frame_fit.py; the runtime
  hides this, a redraw at the right size removes the need);
- jump: steps where more than half of the silhouette is replaced between two
  consecutive frames as the game places them (limb or prop pops with nothing in
  between: needs an in-between or a redraw of one side);
- boil: calm clips (idle, walk) whose outline changes on average three times
  as much as sliding the same drawing by 2 px (the whole clip is redrawn frame
  by frame: needs one consistent model sheet, not single-frame fixes).

Order is an estimate, not a measurement: how often a player meets the creature
(spawns in the six chapters, earlier chapters first, a boss counted as a long
fight) times how often the clip plays (idle and walk always, attacks often,
hurt sometimes) times how much is wrong.

    python tools/build_creature_redraw_list.py                # rewrite the list
    python tools/build_creature_redraw_list.py --sheets DIR   # also write contact sheets of the top clips
"""
from __future__ import annotations

import argparse
import json
import math
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import build_creature_frame_fit as fit

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot/data"
LIST = ROOT / "docs/research/20261111_creature_redraw_list.md"
RECORD = ROOT / "docs/research/20261111_creature_redraw_list.json"
SIZE = 0.08          # log-free: |scale - 1| of the stored correction
JUMP = 0.5           # same threshold as tools/audit_animation_smoothness.py
BOIL = 3.0           # mean outline change relative to a 2 px slide
BOSS_SPAWNS = 6      # a boss fight shows its clips about as often as six field enemies
CLIP_WEIGHT = {"idle": 3.0, "walk": 3.0, "attack": 2.0, "hurt": 1.0, "other": 1.0}


def role_of(name: str) -> str:
    base = name.removesuffix("_left").removesuffix("_right")
    if base.startswith("idle"):
        return "idle"
    if base.startswith(("walk", "move")):
        return "walk"
    if base.startswith("hurt"):
        return "hurt"
    if base in ("guard", "retreat", "settle", "phase", "charge", "travel"):
        return "other"
    return "attack"


def exposure() -> dict[str, dict]:
    """Spawns and first chapter per kind; bosses from the roster."""
    seen: dict[str, dict] = {}
    for path in sorted(DATA.glob("demo_ch0[1-6]_*.json")):
        chapter = int(path.name[7:9])
        data = json.loads(path.read_text(encoding="utf-8"))
        for spawn in data.get("enemy_spawns", []):
            row = seen.setdefault(spawn.get("kind", ""), dict(spawns=0, chapter=chapter, boss=False))
            row["spawns"] += 1
    roster = json.loads((DATA / "original_creature_designs.json").read_text(encoding="utf-8"))["designs"]
    bosses = [design["kind"] for design in roster if design.get("boss")]
    for chapter, kind in enumerate(bosses, start=1):
        seen[kind] = dict(spawns=BOSS_SPAWNS, chapter=chapter, boss=True)
    return seen


def placed(alpha: Image.Image, frame: dict, canvas: list[int]) -> np.ndarray:
    mask = np.zeros((canvas[1], canvas[0]), bool)
    margin = frame.get("margin", [0, 0, 0, 0])
    solid = np.asarray(alpha) > fit.SOLID_ALPHA
    x, y = max(0, margin[0]), max(0, margin[1])
    part = solid[:canvas[1] - y, :canvas[0] - x]
    mask[y:y + part.shape[0], x:x + part.shape[1]] = part
    return mask


def change(a: np.ndarray, b: np.ndarray) -> float:
    union = int((a | b).sum())
    return 1.0 - int((a & b).sum()) / union if union else 0.0


def measure(kind: str) -> list[dict]:
    folder = fit.CREATURES / kind
    path = fit.active_manifest(folder)
    manifest = json.loads(path.read_text(encoding="utf-8"))
    table = {}
    if (folder / fit.OUTPUT).exists():
        table = json.loads((folder / fit.OUTPUT).read_text(encoding="utf-8"))["frames"]
    atlases = fit.Atlases()
    canvas = manifest.get("canvas")
    rows = []
    for clip in fit.animations_of(manifest):
        frames = clip["frames"]
        name = clip["name"]
        if name.endswith("_left") or name.startswith("death") or len(frames) < 2 or not canvas:
            continue
        if not all(isinstance(frame, dict) for frame in frames):
            continue
        masks = [placed(atlases.alpha(frame), frame, canvas) for frame in frames]
        loop = bool(clip.get("loop", True))
        steps = [(i, (i + 1) % len(masks)) for i in range(len(masks) if loop else len(masks) - 1)]
        changes = [change(masks[a], masks[b]) for a, b in steps]
        slide = [change(mask[:, 2:], mask[:, :-2]) for mask in masks]
        relative = float(np.mean(changes)) / max(0.02, float(np.mean(slide)))
        corrections = table.get(name, [])
        size = [dict(frame=i, scale=row[0]) for i, row in enumerate(corrections) if abs(row[0] - 1.0) >= SIZE]
        jumps = [dict(after=a, before=b, change=round(value, 2)) for (a, b), value in zip(steps, changes) if value > JUMP]
        role = role_of(name)
        boil = role in ("idle", "walk") and relative >= BOIL
        if size or jumps or boil:
            rows.append(dict(kind=kind, clip=name, role=role, frames=len(frames), layer=path.name,
                             mean_change=round(float(np.mean(changes)), 3), slide_2px=round(float(np.mean(slide)), 3),
                             size=size, jumps=jumps, boil=boil))
    return rows


def score(row: dict, seen: dict) -> float:
    meet = seen.get(row["kind"], dict(spawns=1, chapter=6))
    visibility = meet["spawns"] * (1.0 + (6 - meet["chapter"]) * 0.2) * CLIP_WEIGHT[row["role"]]
    wrong = sum(abs(item["scale"] - 1.0) / SIZE for item in row["size"]) + sum(item["change"] / JUMP for item in row["jumps"])
    if row["boil"]:
        wrong += row["frames"] * 0.5
    return visibility * wrong


def frames_text(numbers: list[int]) -> str:
    """Compact frame list: 3, 5-8, 11."""
    out, start, last = [], None, None
    for number in sorted(set(numbers)):
        if start is None:
            start = last = number
        elif number == last + 1:
            last = number
        else:
            out.append(str(start) if start == last else f"{start}–{last}")
            start = last = number
    if start is not None:
        out.append(str(start) if start == last else f"{start}–{last}")
    return "、".join(out) or "—"


def sheet(row: dict, out: Path):
    """The clip as the game places it; marked frames get a coloured bar (red size, yellow jump)."""
    folder = fit.CREATURES / row["kind"]
    manifest = json.loads((folder / row["layer"]).read_text(encoding="utf-8"))
    clip = next(c for c in fit.animations_of(manifest) if c["name"] == row["clip"])
    canvas = manifest["canvas"]
    scale = min(1.0, 150 / canvas[1])
    cell = (max(1, round(canvas[0] * scale)), max(1, round(canvas[1] * scale)))
    columns = min(len(clip["frames"]), 12)
    lines = math.ceil(len(clip["frames"]) / columns)
    page = Image.new("RGBA", (cell[0] * columns, (cell[1] + 14) * lines), (38, 38, 46, 255))
    draw = ImageDraw.Draw(page)
    size = {item["frame"] for item in row["size"]}
    jump = {item["before"] for item in row["jumps"]}
    pages = {}
    for number, frame in enumerate(clip["frames"]):
        if frame["atlas"] not in pages:
            pages[frame["atlas"]] = Image.open(ROOT / "godot" / frame["atlas"].removeprefix("res://")).convert("RGBA")
        x, y, w, h = frame["region"]
        art = pages[frame["atlas"]].crop((x, y, x + w, y + h)).resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.Resampling.LANCZOS)
        left, top = (number % columns) * cell[0], (number // columns) * (cell[1] + 14)
        page.alpha_composite(art, (left + max(0, round(frame["margin"][0] * scale)), top + 14 + max(0, round(frame["margin"][1] * scale))))
        if number in size:
            draw.rectangle((left, top, left + cell[0] // 2 - 1, top + 3), fill=(230, 70, 70, 255))
        if number in jump:
            draw.rectangle((left + cell[0] // 2, top, left + cell[0] - 1, top + 3), fill=(240, 200, 60, 255))
        draw.text((left + 3, top + 3), str(number), fill=(235, 235, 235, 255))
    page.convert("RGB").save(out, quality=80)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sheets", type=Path)
    parser.add_argument("--top", type=int, default=24, help="contact sheets for this many clips")
    parser.add_argument("--jobs", type=int, default=0)
    args = parser.parse_args()
    seen = exposure()
    with ProcessPoolExecutor(max_workers=args.jobs or None) as pool:
        rows = [row for part in pool.map(measure, fit.kinds()) for row in part]
    for row in rows:
        row["score"] = round(score(row, seen), 1)
    rows.sort(key=lambda row: (-row["score"], row["kind"], row["clip"]))
    by_kind: dict[str, list[dict]] = {}
    for row in rows:
        by_kind.setdefault(row["kind"], []).append(row)
    order = sorted(by_kind, key=lambda kind: -sum(row["score"] for row in by_kind[kind]))
    size_frames = sum(len(row["size"]) for row in rows)
    jump_steps = sum(len(row["jumps"]) for row in rows)
    boil_clips = sum(row["boil"] for row in rows)
    text = ["# 怪物动作重画清单（按优先级）", "",
            "> 由 `tools/build_creature_redraw_list.py` 生成，只是报告，不影响游戏和 CI。重新生成：`python tools/build_creature_redraw_list.py --sheets artifacts/creature_redraw_list_20261111`。", "",
            f"46 种怪物实际播放的片段里，{len(rows)} 段至少有一项问题：大小不一致的帧 {size_frames} 帧，跳帧 {jump_steps} 处，整段“沸腾”的待机／走路 {boil_clips} 段。", "",
            "三种标记的含义：", "",
            f"- **大小**：这一帧的身体比前后帧大或小 {int(SIZE * 100)}% 以上（括号里是运行时目前用来遮掩的缩放值，重画时按这个比例改身体大小即可）。",
            "- **跳帧**：相邻两帧之间一半以上的轮廓被替换，肢体或道具直接跳到新位置。写作“a→b”，需要在两帧之间补一张，或重画其中一张。",
            "- **整段重画**：待机、走路这类平静动作，轮廓平均变化达到“整体平移 2px”的 3 倍以上，说明每帧都是重新画的。单修某一帧没用，要按同一套造型整段重出。", "",
            "排序是估算，不是实测：出场次数（六章生成点数量，越早的章节越靠前，Boss 按 6 个小怪计）× 片段出现频率（待机和走路最高，攻击其次，受击最低）× 问题多少。帧号从 0 开始，是游戏当前读取的图层里的序号；`_left` 片段与 `_right` 内容对应，只列一边；死亡片段不列。", "",
            "## 各怪物汇总", "", "| 顺序 | 怪物 | 首次出现 | 生成点 | 问题片段 | 大小 | 跳帧 | 整段重画 |", "|---|---|---|---|---|---|---|---|"]
    for position, kind in enumerate(order, start=1):
        meet = seen.get(kind, dict(spawns=0, chapter=0, boss=False))
        clips = by_kind[kind]
        text.append(f"| {position} | `{kind}`{'（Boss）' if meet.get('boss') else ''} | 第 {meet['chapter']} 章 | {meet['spawns'] if not meet.get('boss') else '—'} | {len(clips)} | "
                    f"{sum(len(c['size']) for c in clips)} | {sum(len(c['jumps']) for c in clips)} | {sum(c['boil'] for c in clips)} |")
    clean = [kind for kind in fit.kinds() if kind not in by_kind]
    if clean:
        text += ["", "没有标记的怪物：" + "、".join(f"`{kind}`" for kind in clean) + "。"]
    top = rows[:args.top]
    if args.sheets:
        args.sheets.mkdir(parents=True, exist_ok=True)
        for stale in args.sheets.glob("*.jpg"):
            stale.unlink()
        for row in top:
            sheet(row, args.sheets / f"{row['kind']}__{row['clip']}.jpg")
        relative = Path("../..") / args.sheets.resolve().relative_to(ROOT)
        text += ["", f"## 最该先看的 {len(top)} 段", "", "每格左上角是帧号；格子顶部红条表示大小不一致，黄条表示它与上一帧之间跳帧。", ""]
        for row in top:
            text += [f"**`{row['kind']}` / `{row['clip']}`**", "", f"![{row['kind']} {row['clip']}]({relative.as_posix()}/{row['kind']}__{row['clip']}.jpg)", ""]
    text += ["", "## 逐怪物、逐片段", ""]
    for kind in order:
        text += [f"### `{kind}`", "", "| 片段 | 帧数 | 大小不一致的帧 | 跳帧 | 整段重画 |", "|---|---|---|---|---|"]
        for row in by_kind[kind]:
            size = "；".join(f"{item['frame']}（×{item['scale']}）" for item in row["size"]) or "—"
            jumps = "、".join(f"{item['after']}→{item['before']}" for item in row["jumps"]) or "—"
            text.append(f"| `{row['clip']}` | {row['frames']} | {size} | {jumps} | {'是' if row['boil'] else '—'} |")
        text.append("")
    LIST.write_text("\n".join(text).rstrip() + "\n", encoding="utf-8", newline="\n")
    RECORD.write_text(json.dumps(dict(thresholds=dict(size=SIZE, jump=JUMP, boil=BOIL), clips=rows), ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(dict(clips=len(rows), size_frames=size_frames, jump_steps=jump_steps, boil_clips=boil_clips, creatures=len(by_kind))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
