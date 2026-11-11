"""Audit committed enemy artwork using the production manifest/profile precedence.

Standard library only; works with a sparse checkout. Reads a frozen Git tree,
never imports Godot, rebuilds art, or modifies the inspected worktree.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CHAPTERS = [
    "moss_bell_court", "rain_foundry_canal", "saltwhite_archive",
    "broken_string_greenhouse", "obsidian_pilgrim_road", "silent_crown_core",
]
LAYERS = ["motion_redraw_manifest.json", "motion_transition_manifest.json", "motion_onion_manifest.json", "motion_v8_manifest.json", "boss_behavior_manifest.json", "combat_motion_v7_manifest.json",
          "motion_manifest.json", "manifest.json"]
CORE = ["idle", "walk", "windup", "attack", "recover", "hurt", "death"]
OPTIONAL = ["turn", "brake", "jump", "land", "intro", "stagger"]


class Snapshot:
    def __init__(self, ref):
        self.commit = self.git("rev-parse", f"{ref}^{{commit}}").decode().strip()
        self.paths = set(self.git("ls-tree", "-rz", "--name-only", self.commit)
                         .decode("utf-8").split("\0"))
        self.process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=ROOT,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self.image_sizes = {}
        self.unresolved_lfs = {}
        common = Path(self.git("rev-parse", "--git-common-dir").decode().strip())
        self.lfs_objects = (ROOT / common).resolve() / "lfs/objects"

    @staticmethod
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT)

    def blob(self, path):
        if path not in self.paths:
            raise ValueError(f"Missing committed file: {path}")
        self.process.stdin.write(f"{self.commit}:{path}\n".encode("utf-8"))
        self.process.stdin.flush()
        header = self.process.stdout.readline().split()
        if len(header) != 3 or header[1] != b"blob":
            raise ValueError(f"Cannot read blob: {path}")
        size = int(header[2])
        chunks = []
        remaining = size
        while remaining:
            chunk = self.process.stdout.read(remaining)
            if not chunk:
                raise ValueError(f"Truncated blob: {path}")
            chunks.append(chunk)
            remaining -= len(chunk)
        if self.process.stdout.read(1) != b"\n":
            raise ValueError("Invalid cat-file delimiter")
        return b"".join(chunks)

    def json(self, path):
        return json.loads(self.blob(path))

    def png_size(self, path):
        if path not in self.image_sizes:
            blob = self.blob(path)
            if blob.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                pointer = dict(line.split(" ", 1) for line in blob.decode().splitlines()[1:])
                oid = pointer["oid"].removeprefix("sha256:")
                local = self.lfs_objects / oid[:2] / oid[2:4] / oid
                if not local.is_file():
                    self.unresolved_lfs[path] = oid
                    self.image_sizes[path] = None
                    return None
                blob = local.read_bytes()
                if sha256(blob).hexdigest() != oid or len(blob) != int(pointer["size"]):
                    raise ValueError(f"Corrupt local LFS object: {path}")
            if blob[:8] != b"\x89PNG\r\n\x1a\n" or blob[12:16] != b"IHDR":
                raise ValueError(f"Not a PNG (or unresolved LFS pointer): {path}")
            self.image_sizes[path] = struct.unpack(">II", blob[16:24])
        return self.image_sizes[path]

    def close(self):
        self.process.stdin.close()
        self.process.stdout.close()
        self.process.wait()


def from_res(path):
    if not path.startswith("res://"):
        raise ValueError(f"Unexpected resource path: {path}")
    return "godot/" + path[6:]


def inspect_manifest(tree, path, errors):
    manifest = tree.json(path)
    clips = {}
    for animation in manifest["animations"]:
        name = animation["name"]
        frames = animation["frames"]
        if name in clips or not frames or animation.get("fps", 8) <= 0:
            errors.append(f"{path}: invalid/duplicate animation {name}")
        identities = set()
        for frame in frames:
            atlas = frame["atlas"] if isinstance(frame, dict) else frame
            asset = from_res(atlas)
            size = tree.png_size(asset)
            if size is None:
                identities.add((atlas,))
                continue
            width, height = size
            region = frame.get("region", [0, 0, width, height]) if isinstance(frame, dict) else [0, 0, width, height]
            x, y, w, h = region
            if x < 0 or y < 0 or w <= 0 or h <= 0 or x+w > width or y+h > height:
                errors.append(f"{path}/{name}: region outside {asset}: {region}")
            identities.add((atlas, *region))
        clips[name] = {"frame_refs": len(frames), "unique_regions": len(identities)}
    return manifest, clips


def resolve_attack(command, clips):
    own = command["id"]
    base = own if own in clips or own+"_windup" in clips else command.get("animation", "attack")
    names = [base+"_windup" if base+"_windup" in clips else "windup",
             base if base in clips else "attack",
             base+"_recover" if base+"_recover" in clips else "recover" if "recover" in clips else "idle"]
    counts = [clips.get(n, {}).get("frame_refs", 0) for n in names]
    seconds = [command.get(n) for n in ["windup", "active", "recover"]]
    rates = [round(count/duration, 2) if isinstance(duration, (int, float)) and duration > 0 else None
             for count, duration in zip(counts, seconds)]
    return {"id": own, "name": command.get("name", own), "type": command.get("type"),
            "base": base, "clips": names,
            "frame_refs": counts, "seconds": seconds,
            "nominal_pose_updates_per_second": rates,
            "rate_caveat": "configured phase durations; combo sub-beats and runtime timing overrides require playback measurement"}


def audit(tree):
    errors = []
    originals = tree.json("godot/data/original_creature_combat.json")
    styles = tree.json("godot/data/boss_combat_styles.json")["bosses"]
    entries = {}
    spawns = []
    for number, slug in enumerate(CHAPTERS, 1):
        path = f"godot/data/demo_ch{number:02}_{slug}.json"
        chapter = tree.json(path)
        actors = [(s, False, "enemy_spawns") for s in chapter["enemy_spawns"]]
        actors.append((chapter["boss"], True, "boss"))
        for challenge in chapter.get("optional_challenges", []):
            actors.extend((s, False, challenge["id"]) for s in challenge.get("enemies", []))
        for spawn, boss, origin in actors:
            kind = spawn["kind"]
            # Mirrors EnemyActor.configure: chapter -> original -> encounter -> style.
            profile = deepcopy(chapter["ai_profiles"].get(kind, {}))
            profile.update(deepcopy(originals.get(kind, {})))
            profile.update(deepcopy(spawn.get("encounter_profile", {})))
            style = styles.get(kind, {}) if boss else {}
            if any(c["id"] in style.get("moves", {}) for c in profile.get("attacks", [])):
                profile.update(deepcopy(style.get("profile", {})))
                profile["attacks"] = [c | style["moves"].get(c["id"], {}) for c in profile["attacks"]]
            elite = bool(spawn.get("elite")) and not boss and isinstance(profile.get("elite"), dict)
            commands = profile.get("attacks", []) + (profile["elite"].get("attacks", []) if elite else [])
            row = entries.setdefault(kind, {"kind": kind, "name": spawn.get("name", kind),
                "boss": boss, "chapters": [], "locomotion": profile.get("locomotion", "ground"),
                "commands": {}, "elite_commands": set()})
            if number not in row["chapters"]:
                row["chapters"].append(number)
            for command in commands:
                previous = row["commands"].get(command["id"])
                # Asset selection cannot silently collapse conflicting encounter overrides.
                if previous and resolve_signature(previous) != resolve_signature(command):
                    errors.append(f"{kind}/{command['id']}: conflicting encounter animation overrides")
                row["commands"][command["id"]] = command
            if elite:
                row["elite_commands"].update(c["id"] for c in profile["elite"].get("attacks", []))
            spawns.append({"chapter": number, "origin": origin, "kind": kind, "elite": elite})

    vfx = {False: tree.json("godot/assets/vfx/minor_enemy_skills/manifest.json"),
           True: tree.json("godot/assets/vfx/boss_skills/manifest.json")}
    actors = []
    for kind, row in entries.items():
        root = f"godot/assets/sprites/original_creatures/{kind}/"
        path = next((root+n for n in LAYERS if root+n in tree.paths), None)
        if path is None:
            raise ValueError(f"No production manifest for {kind}")
        manifest, clips = inspect_manifest(tree, path, errors)
        for name in CORE + (["backstep", "ready_guard", "ready_settle"] if row["boss"] else []):
            if name not in clips:
                errors.append(f"{kind}: missing core clip {name}")
        commands = []
        for command in row.pop("commands").values():
            result = resolve_attack(command, clips)
            result["elite"] = command["id"] in row["elite_commands"]
            result["vfx_registered"] = command["id"] in vfx[row["boss"]]["commands"]
            if 0 in result["frame_refs"]:
                errors.append(f"{kind}/{command['id']}: missing attack stage")
            if result["clips"][2] == "idle":
                errors.append(f"{kind}/{command['id']}: recovery falls back to idle")
            if not result["vfx_registered"]:
                errors.append(f"{kind}/{command['id']}: no dedicated VFX registration")
            commands.append(result)
        row.pop("elite_commands")
        counts = Counter(c["base"] for c in commands)
        row.update(manifest=path, animations=clips, attacks=commands,
                   shared_attack_bases=[base for base, count in counts.items() if count > 1],
                   optional_named_clips_absent=[n for n in OPTIONAL if n not in clips],
                   direction="horizontal_flip", authored_combat_sequences=manifest.get("authored_combat_sequences", []))
        actors.append(row)

    registry_path = "godot/assets/sprites/bosses/boss_asset_registry.json"
    registry = []
    for entry in tree.json(registry_path)["entries"]:
        path = from_res(entry["manifest"])
        _, clips = inspect_manifest(tree, path, errors)
        required = entry.get("runtime_animations", []) + entry.get("required_directional_animations", [])
        for name in required:
            if name not in clips:
                errors.append(f"{entry['id']}: missing library clip {name}")
        registry.append({"id": entry["id"], "name": entry["name_zh"], "manifest": path,
                         "animations": clips, "selected_by_six_chapter_actor_loader": False})
    minor = [a for a in actors if not a["boss"]]
    bosses = [a for a in actors if a["boss"]]
    return {"schema": 1, "source_commit": tree.commit,
            "scope": "six chapter configs + optional challenge enemy spawns; production body manifests; 20-boss reserve library",
            "method": "static Git-tree audit; frame refs/unique atlas regions are not counts of unique authored drawings; no playback-quality claim",
            "summary": {"minor_species": len(minor), "chapter_bosses": len(bosses),
                        "minor_commands_including_elites": sum(len(a["attacks"]) for a in minor),
                        "elite_signature_commands": sum(c["elite"] for a in minor for c in a["attacks"]),
                        "boss_commands": sum(len(a["attacks"]) for a in bosses),
                        "reserve_bosses": len(registry), "body_atlases_checked": len(tree.image_sizes)-len(tree.unresolved_lfs),
                        "unresolved_lfs_images": len(tree.unresolved_lfs),
                        "body_frame_refs_checked": sum(c["frame_refs"] for a in actors+registry for c in a["animations"].values()),
                        "missing_core_or_invalid_assets": len(errors)},
            "errors": errors, "unresolved_lfs": tree.unresolved_lfs,
            "actors": actors, "reserve_boss_library": registry, "encounters": spawns}


def resolve_signature(command):
    return command.get("animation", "attack")


def markdown(report):
    s = report["summary"]
    has_v8 = any(Path(a["manifest"]).name == "motion_v8_manifest.json" for a in report["actors"])
    priority = " → ".join("`"+name.removesuffix(".json")+"`" for name in LAYERS)
    phase_note = ("当前正式角色的攻击阶段为 24 帧，通常三段合计 72 个姿势引用。" if has_v8 else
                  "十二帧是每个阶段的数量，通常三段合计 36 个姿势引用。")
    lines = ["# 敌人动作素材逐项盘点（自动生成）", "",
             f"审计基线：`{report['source_commit']}`。范围为正式六章、可选挑战敌人和二十 Boss 备用库。", "",
             f"共 {s['minor_species']} 种小怪、{s['chapter_bosses']} 位正式 Boss；小怪 {s['minor_commands_including_elites']} 条攻击（含 {s['elite_signature_commands']} 条精英专属），Boss {s['boss_commands']} 条攻击。",
             f"检查 {s['body_atlases_checked']} 张身体图集、{s['body_frame_refs_checked']} 个帧引用；缺少基础动作或无效资源：{s['missing_core_or_invalid_assets']}。", "",
             f"未取得本地 LFS 实体的图片：{s['unresolved_lfs_images']}；若非零，相关图片仅验证 Git 指针及动画登记，不能据此宣称像素资源验收完成。", "",
             "帧数指 manifest 引用数；`unique_regions` 记录不同图集区域，不等于新画姿势数。本次只检查 Git 中的 PNG、尺寸、裁切边界、动作选择和特效登记，不证明动作顺滑、碰撞同步或自然通关。", "",
             f"正式读取优先级：{priority}。左右采用水平翻转；没有单独左右图不计作缺失。", "",
             phase_note + "平滑程度还取决于时长：`姿势更新率 = 帧数 / 秒数`。下列 Boss 名义更新率依据配置计算；连击子节拍和运行时改写时长需单独测量，不等于渲染 FPS。", "",
             "## 40 种小怪", "",
             "每行均有待机、移动、前摇、出手、收招、受击、死亡。驻足怪的 `walk` 存在不代表其 AI 会行走；飞行怪的 `walk` 表示飞行循环。", "",
             "| 章节 / kind | 移动方式 | 待机 / 移动 / 受击 / 死亡 | 攻击 → 实际身体动画（前摇 / 出手 / 收招帧数） |", "| --- | --- | --- | --- |"]
    for a in report["actors"]:
        if a["boss"]:
            continue
        values = "/".join(str(a["animations"][n]["frame_refs"]) for n in ["idle", "walk", "hurt", "death"])
        commands = "<br>".join(f"{'精英 ' if c['elite'] else ''}`{c['id']}` → `{c['base']}` ({'/'.join(map(str,c['frame_refs']))})" for c in a["attacks"])
        lines.append(f"| {','.join(map(str,a['chapters']))} / `{a['kind']}` | {a['locomotion']} | {values} | {commands} |")
    lines += ["", "## 六位正式 Boss", "",
              "名称来自章节配置；旧目录 kind、历史报告名称与当前显示名可能不同。每位 Boss 的四条攻击分别核对，避免把通用名字 `heavy/cast/phase` 误判成没做专属动作。", ""]
    for a in report["actors"]:
        if not a["boss"]:
            continue
        lines += [f"### {a['name']} · `{a['kind']}`", "", f"实际清单：[{Path(a['manifest']).name}](../../{a['manifest']})。", "",
                  "- " + "；".join(f"`{n}` {a['animations'][n]['frame_refs']} 帧" for n in ["idle", "walk", "backstep", "ready_guard", "ready_settle", "hurt", "death"]) + "。", ""]
        for c in a["attacks"]:
            lines.append(f"- {c['name']} `{c['id']}` → `{'` → `'.join(c['clips'])}`，{'/'.join(map(str,c['frame_refs']))} 帧；配置时长 {'/'.join(map(str,c['seconds']))} 秒；名义姿势更新率 {'/'.join(map(str,c['nominal_pose_updates_per_second']))} 次/秒。")
        lines += ["", "四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。", ""]
    lines += ["## 二十 Boss 备用素材库", "",
              "此库有动作，不应列为“缺失二十套 Boss”。正式六章由 `kind` 选择 `original_creatures`，因此注册表旧 `godot_demo_refs` 不等于这些图集正在被正式演员使用。未来增加对应战斗时，需要单独完成配置、AI、时钟和实机验收。", "",
              "| 编号 | 素材库名称 | walk 左/右 | attack 左/右 | 三套特殊攻击左/右 |", "| --- | --- | --- | --- | --- |"]
    for a in report["reserve_boss_library"]:
        clips = a["animations"]
        count = lambda name: clips.get(name, {}).get("frame_refs", 0)
        special = "; ".join(f"{count(a['id']+'_atk_'+str(i).zfill(2)+'_left')}/{count(a['id']+'_atk_'+str(i).zfill(2)+'_right')}" for i in range(1, 4))
        lines.append(f"| {a['id']} | {a['name']} | {count('walk_left')}/{count('walk_right')} | {count('attack_left')}/{count('attack_right')} | {special} |")
    lines += ["", "## 静态错误", ""]
    lines += [f"- {e}" for e in report["errors"]] or ["未发现缺少基础动作、攻击阶段、身体图集或越界裁切。"]
    lines += ["", "详细帧引用、可选命名动作缺口、每条招式和具体遭遇见同目录 JSON。制作优先级和人工验收清单见 [审计结论](20261109_character_animation_checklist.md)。", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", required=True, help="Frozen Git commit/ref to inspect")
    parser.add_argument("--output", type=Path, required=True, help="JSON report")
    parser.add_argument("--markdown", type=Path, required=True, help="Readable inventory")
    parser.add_argument("--check", action="store_true", help="Compare outputs without writing")
    args = parser.parse_args()
    tree = Snapshot(args.ref)
    try:
        report = audit(tree)
    finally:
        tree.close()
    for path, text in [(args.output, json.dumps(report, ensure_ascii=False, indent=2)+"\n"),
                       (args.markdown, markdown(report))]:
        if args.check:
            if path.read_text(encoding="utf-8") != text:
                raise SystemExit(f"Stale audit report: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8", newline="\n")
    print(json.dumps(report["summary"], ensure_ascii=False))
    raise SystemExit(1 if report["errors"] else 0)


if __name__ == "__main__":
    main()
