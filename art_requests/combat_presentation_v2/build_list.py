"""Build missing hero VFX and the six runtime bosses' warning-art requests.

This writes briefs/prompts and copies existing references; it never draws art or
changes the game. Boss coverage comes from the actual six chapter configurations.
Run with --check to verify the generated documents without changing files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GODOT = ROOT / "godot"
PLAYER = "godot/scripts/player_controller.gd"
ACTOR = "godot/scripts/enemy_actor.gd"
EFFECT = "godot/scripts/enemy_attack_effect.gd"

# stem, name, visual brief, runtime hook, anchor, playback
HERO = [
    ("guard_raise", "格挡起手／护幕", "A narrow curved half-shield of interwoven old-brass filaments and pale silk, braced on the RIGHT side. A few crimson knots bind its rim; a small bell-shaped notch identifies the bell guard. It has layered painted material and a clearly open back, never a complete circle or a plain line. Do not paint a physical shield or a character.", "_try_guard; _apply_special_skill defense（ward）", "front", "guard"),
    ("guard_block", "普通挡击", "A blunt impact dent in a woven brass-and-silk half-shield on the right, followed by a short sideways shower of dull copper chips and loose silk. Broad soft recoil, clearly less sharp and bright than a perfect parry. No full circular shockwave.", "take_damage: blockable and guard_timer; perfect=false", "front", "burst"),
    ("guard_perfect", "完美格挡", "A precise ivory needle-point contact flare on the right, snapping crimson knots and a short angular crown of brass chips. A crisp white-gold contact core, two hooked silk tongues and a restrained bell resonance halo made of broken engraved fragments. Visibly different from the softer ordinary block; no screen-filling white flash.", "take_damage: perfect=true（首0.14秒）", "front", "burst"),
    ("heal_channel", "缝补蓄力", "Fine crimson sewing threads wind UPWARD around an empty body-shaped space, drawing pale silk stitches together. A small warm ivory knot pulses near the centre, with several hand-painted wisps. No body, no floating health icon, no concentric geometric circles.", "_try_heal; heal_timer; heal_state_changed started", "body", "channel"),
    ("heal_complete", "缝补完成", "The last crimson stitch closes into a tiny ivory knot and releases a compact upward fan of soft silk fibres and muted brass motes. Calm successful completion, not an explosion or a damage hit.", "_update_heal: successful completion; heal_state_changed", "body", "burst"),
    ("heal_interrupt", "缝补被打断", "A partially sewn crimson knot tears apart; interrupted pale stitches sag and unravel downward in two ragged strands. Dark red and dim ivory, distinctly different from successful healing. No health pickup or successful completion flash.", "_interrupt_heal（仅已有缝补时触发）", "body", "burst"),
    ("double_jump", "二段跳丝翼", "Two small symmetrical moth-wing-shaped fans of crimson silk unfurl to either side under an empty centre and then shed loose fibres downward. Layered torn-silk membranes, pale inner strands and a dark ink rim; no insect or body.", "_spawn_double_jump_vfx", "feet", "burst"),
    ("dash_ribbon", "冲刺收线轨迹", "A horizontal crimson silk wake pointing RIGHT, with three tapered textured ribbons, a narrow ivory inner filament and a few torn fibres. Strong travelling direction; the trailing left end frays. This is only the material of a motion trail, without a character or a copied silhouette.", "_spawn_dash_trail（角色残影继续复用当前角色帧）", "center", "burst"),
    ("hook_head", "回声钩头", "A small RIGHT-pointing hooked sewing needle of worn ivory and old brass, crimson thread tied through its eye. A curved tactile hook silhouette with a pale cutting tip; subtle glint changes only, consistent shape and scale. No rope extending across the cel.", "_try_start_grapple; _spawn_hook_trail_vfx: HookTipVfx", "center", "loop"),
    ("hook_cord", "回声钩绳纹理", "A horizontal length of taut twisted crimson silk cord with a thin pale spiral strand. It extends exactly from LEFT tile edge to RIGHT tile edge at the same vertical level; the pattern and alpha must join seamlessly along the horizontal axis. Animate a small glint travelling right. No knots, hooks, caps or dangling ends inside this repeating tile.", "_try_start_grapple: grapple_line（随真实两端铺纹理）", "tile", "tile"),
    ("hook_latch", "钩索命中／收回", "An ivory hook-contact prick gathers crimson silk into a tight knot, then loosens into a small retracting curl. Fine brass flecks and tactile silk fibres. Empty centre, no hook target, scenery or character.", "钩索有效挂接、收回边界；_stop_grapple", "center", "burst"),
    ("downstrike", "荆针下砸落地", "A downward needle strike hits the ground baseline, splitting a short jagged crown of dark thorn chips and crimson fibres to both sides. A pale ivory point at the impact centre; low curling dust and a few sharp thorn splinters. Not a large circular shockwave. No drawn ground slab.", "thorn_downstrike: traversal_downstrike_active 落地分支", "ground", "burst"),
    ("phase", "灯相进入／维持／退出", "A thin translucent blue-grey lantern veil with irregular torn-silk edges surrounds an EMPTY human-sized space. Muted cold light, a few ivory fibres and sparse crimson stitches. Entry gathers the veil, its middle breathes quietly, exit unravels it. No ghost character, lantern prop, magic circle or opaque smoke wall.", "_update_phase; phase_active; _stop_phase", "body", "phase"),
    ("resonance", "王冠共鸣", "A radial pulse of separated worn brass crown fragments and ivory bell-silk waves opens around an empty centre. Small crimson joins between pieces, dark engraved rims, a readable circular extent made from broken ornament and textured sound ribbons rather than a bare circle. Keep the central character space open.", "_try_resonance; _apply_special_skill: resonance", "body", "channel"),
    ("skill_slash", "技能重斩／交叉斩", "A broad curved sword smear pointing RIGHT, formed from layered crimson silk and a pale ivory leading edge. Two distinct crossing strands near the centre can support a crosscut. Hand-painted torn taper, dark contour, short brass splinters, empty interior. No blade or character. Retain a concise silhouette at small size.", "_spawn_skill_slash_vfx; cleave/crosscut 的有效帧", "center", "burst"),
    ("hurt_snap", "受伤断线", "Five short crimson silk strands snap away from an empty contact centre, their torn ivory fibres curling and losing tension. Sparse dark red flecks, no blood spray, no full-body silhouette and no circular ring.", "_spawn_thread_snap_vfx", "body", "burst"),
    ("land", "落地尘絮", "A low sideways puff of brown-grey dust mixed with short pale silk fibres, opening left and right from the ground baseline. Painterly clumps with dark contours and thin transparent gaps. No green laser line, no ground slab and no character.", "_spawn_land_vfx（轻重落地可调数量与缩放）", "ground", "burst"),
    ("wall_grip", "蹬墙／攀附擦丝", "A small right-facing contact tuft of crimson silk clinging to an invisible vertical surface, with several pale fibres scraping downward and tiny dark grit fragments. The wall side is RIGHT; do not draw the wall. Modest scale, no large smoke plume.", "wall_sliding 进入、蹬墙离开；silk_wall_grip", "contact", "burst"),
    ("death_unweave", "死亡散线", "A loose cocoon of crimson silk collapses around an EMPTY body-shaped space, then unweaves into falling dark red ribbons and pale frayed fibres. Melancholy and restrained, no corpse, no human silhouette, no gore, no successful healing knot.", "take_damage: hp<=0; death_timer（保留角色死亡姿势）", "body", "phase"),
    ("respawn_weave", "复活织回", "Crimson threads rise from an empty ground baseline and weave a loose open cocoon around an EMPTY body-shaped centre; a few pale ivory stitches settle inward, then the outer silk clears away. A quiet reconstruction effect, no character, no corpse, no flat circular halo.", "respawn_reveal_timer; _set_death_visibility", "body", "phase"),
    ("blade_trace", "普通挥刀材质", "A short tapered ivory blade smear with fine crimson silk grain and an uneven dark ink rim. A curved narrow wedge with an open transparent interior, broad at the right cutting edge and fraying to the left. No weapon or character, no huge crescent spanning a whole hitbox. This image supplies material to a short weapon-following trace.", "player_melee_feedback.gd: spawn_swing（沿实测刀根／刀尖贴合）", "center", "burst"),
    ("hit_spark", "近战命中碎屑", "A compact RIGHT-facing ivory contact notch breaks into a few old-brass chips and crimson silk ends, a crisp tiny centre with a dark ink rim. Directional and short-lived; no circular halo or screen flash. Material-neutral so enemy-specific chips can be tinted in the game.", "player_melee_feedback.gd: spawn_hit; enemy_actor.gd: HitSpark", "contact", "burst"),
]

# One explicit design per authored command, including close attacks that v1 omitted.
# topology controls placement, not damage or timing.
WARNINGS = {
    "boss_moss_scythe": ("sweep", "A low curved rake of pale scythe-edge light intertwined with hanging moss fibres and a few tiny white flower motes. The leading edge is on the RIGHT, with broken old-brass bell engravings near the base. Anticipatory and translucent, no completed slash impact."),
    "boss_moss_stamp": ("source", "A squat downward bell-pressure motif: three nested broken bronze bell shoulders press toward a jagged moss root tuft under the caster. Low weight and gathering force, not a moving damaging wave."),
    "boss_moss_spores": ("source", "Five small tightly closed green spore buds gather around a short right-facing muzzle of moss fibres. Pale-yellow inner pollen, tiny ivory hairs, all buds remain near the source; do not draw a full fan trajectory or launched projectiles."),
    "boss_moss_roots": ("eruption", "A mound-shaped pre-eruption crack of intertwined moss roots, pinhead white flowers and dim pale sap. Root tips stay curled UNDER the crack. Low tension and rising dust grains, no tall spikes or erupted roots yet."),
    "boss_shears_close": ("sweep", "Two short crossing scissor-shaped silk tensions in faded crimson, bordered by tiny tarnished-brass hinge fragments. Pale inner thread, sharp cutting direction to the RIGHT. An anticipatory crossed pattern, not a finished hit or a physical pair of scissors."),
    "boss_shears_thread": ("beam", "Parallel stretched crimson filaments with tiny dark brass staples and frayed ivory highlights, making a woven narrow threatening corridor. Restrained warm warning glint, no active burning beam. Repeating horizontal weave; avoid a lone clean laser stroke."),
    "boss_shears_knots": ("pool", "A low intricate crimson knotwork nest with small tarnished-brass staples, a translucent empty centre and tight pale silk tendrils tucked inward. The danger perimeter is formed by woven knotted material, not a bare drawn circle. No risen trap or snaring victim yet."),
    "boss_shears_turn": ("source", "Two asymmetrical curled crimson ribbon feathers gather into an upward-turning scissor flourish near the caster, with a small dull brass hinge glint. A compact preparation for a vault, not a predicted landing target or a full flight arc."),
    "boss_mantis_guard": ("guard", "Two layered interlocking ash-grey mantis-blade ridges form a small RIGHT-facing defensive wedge, worn bone edges and a dim ember at the joint. Angular solid chitin textures, open back. Distinct defensive anticipation, no all-around invulnerability circle."),
    "boss_mantis_lunge": ("sweep", "A long low mantis-lance tension made of overlapping ash-grey chitin shards, pointed bone tips and fine drifting ash. Narrow and right-facing with one assertive tip, visibly different from an overhead cut or multi-hit fan. No clean HUD arrow."),
    "boss_mantis_overhead": ("sweep", "An overhead hooked mantis-blade tension descends toward the RIGHT, layered charred chitin and pale bone with a sparse falling ash tail. Clearly high-to-low, different from the flat lunge; no completed ground impact."),
    "boss_mantis_flurry": ("sweep", "Three staggered short hooked chitin-blade tensions overlap on the RIGHT in a comb-like rhythm, pale worn edges and separate ash wisps. Visible repeated-cut character without multiple opaque blades filling the whole area. No completed strikes."),
    "boss_bishop_staff": ("sweep", "A crozier-shaped curling copper root gesture leans RIGHT, with pale bark highlights and tiny orange seed-husk flecks. A bent woody preparation arc, no staff prop, no character and no finished shockwave."),
    "boss_bishop_seeds": ("source", "Three closed orange seed husks and curled copper-green tendrils gather in a tight right-facing crozier-head cluster. Faint pale pollen but no launched seeds or full fan of trajectories. Use the bishop's orange pods, not generic green spores."),
    "boss_bishop_roots": ("eruption", "A dry branching copper-root fissure with pale bark ridges, curled amber buds and tiny green leaf scraps. All tips remain coiled at the ground baseline, ready to erupt. Distinct from the matriarch's wet moss-root crack; no tall active thorn."),
    "boss_bishop_cage": ("pool", "A flattened woven ring of copper roots and folded green leaves with tight orange buds at several joints. The centre stays transparent; fragile bark texture defines the full boundary. All cage ribs are folded down, not trapping anything yet."),
    "boss_bride_crescent": ("sweep", "A delicate right-facing silver crescent anticipation made of fractured mirror flakes and thin dark veiling ribbons. Cold ivory glints, muted violet-grey edges, shallow reflection ripples, no generic golden slash and no finished hit."),
    "boss_bride_mirror": ("source", "Two offset narrow broken-mirror fragments wrapped in a small black-violet bridal veil curl at the caster. A split pale glint suggests imminent displacement. No character silhouette, decoy, destination target or full route line."),
    "boss_bride_pools": ("pool", "A low circular mirrorpool mosaic made of irregular silver-grey reflective shards and black-violet veil lace. Translucent dark centre, clear ragged silver perimeter, a few still inward ripples. No actual floor, standing water scenery or risen damaging splash."),
    "boss_bride_dash": ("source", "A compact upward-curled ivory veil and three slanted mirror flakes draw tight at the caster's trailing side, preparing a vaulting dash. Quiet violet-grey dust; no flight parabola, landing target or launched attack."),
    "boss_key_cleave": ("sweep", "An angular right-facing cleave anticipation made of tarnished brass key teeth, bone-white slit highlights and a short dark crown ribbon. Distinct stepped key silhouette, no legible rune, physical weapon or full hit explosion."),
    "boss_key_return": ("source", "Three tiny key-tooth glints fold around a small open old-brass keyhole motif at the caster's right. Fine pale metal dust, tightly grouped before release, no launched keys or guaranteed return-path line."),
    "boss_key_gate": ("beam", "A narrow horizontal woven lane of repeated worn brass gate teeth and pale keyhole slit fragments, bound by a dim crimson filament. Crisp aged metal texture with a dark rim, visibly a gate mechanism rather than the scissor boss's silk lane. No active burning beam."),
    "boss_key_rings": ("source", "Two compressed low shoulders of segmented brass key teeth press outward from the caster, pale slit highlights between dark crown fragments. A gathering bell-gate pressure, not two moving damaging rings or the whole arena filled with circles."),
}

CHARGE = {
    "rust_crown_guardian": "A compact gathering crest of worn bronze bell ribs, hanging moss fibres, three tiny white flowers and pale sap motes. An empty centre and a heavy downward hanging shape, preparing the matriarch's remote root magic.",
    "sunken_hammer_smith": "A compact knot of taut crimson silk loops and tiny tarnished brass scissor-hinge flakes, pale tension at the crossed centre. The two unequal trailing ribbons curl inward, preparing a distant thread trap or beam.",
    "saltwhite_contract_judge": "A compact defensive crown of overlapping ash-grey chitin ridges and pale worn mantis edges. A few falling ember-grey ash flakes, a sharp asymmetric wedge. No circular aura or actual crown prop.",
    "broken_string_gardener": "A compact spiral of copper roots and small orange seed husks, pale bark highlights and two folded green leaves. Crozier-like curling asymmetry and quiet growing tension, preparing remote root or cage magic.",
    "silent_pilgrim_commander": "A compact hollow mirror fragment framed with torn black-violet bridal veil, cold ivory edge glints and a few dust-like silver shards. Offset reflections, no human image inside, preparing a remote mirrorpool or a phase transition.",
    "silent_crown_core": "A compact half-crown assembled from worn brass key teeth and bone-white slit reflections, a few dim crimson binding fibres and dark aged metal. Uneven broken silhouette, no readable runes, preparing the gatekeeper's remote beam or phase shift.",
}

COMMON = """Use case: production transparent game VFX sprite sheet for Crimson Thread Pilgrimage, a 2D side-scrolling dark fantasy game. Match the supplied reference's hand-painted materials, muted earthy colours, crisp dark ink contours and textured shading. Not pixel art, not neon, not a 3D render, not a flat UI icon. The reference supplies STYLE AND MATERIAL only: draw ONLY the effect, never the character, body silhouette, weapon prop or scenery. Genuine transparent alpha background with fully clear gutters: no white/black fill, checkerboard, floor, cast shadow, text, labels, numbers or grid lines. Each cel is separate and fully inside its cell; consistent scale, anchor and fixed side-view camera. Use bold readable material clumps with a thin dark contour; the game displays small images on both dark and pale scenes, so fine filigree alone is insufficient. Soft fringe is allowed but must be sparse and faint. No effect touches a neighbouring cel. The one exception is a requested seamless tile: only its horizontal join edges may touch the cell border.
"""

WARNING_PLAN = [
    "Warning begins immediately readable, fully outlined material footprint already present; no invisible first frame.",
    "Inner material gathers, same fixed outer bounds and anchor.",
    "More concentrated texture and a few restrained motes, same footprint.",
    "Stronger inner tension, clearly still anticipation, same footprint.",
    "Near release; brightest restrained inner detail, entire boundary remains legible.",
    "Hold at full warning tension, same footprint. NO active hit, blast, eruption or fading away.",
]
BURST_PLAN = [
    "Compact readable onset at the contact anchor.", "Effect opens with clearly changed hand-drawn contours.",
    "Peak material shape with the strongest readable silhouette.", "Material separates into a few larger fibres or fragments.",
    "Fragments thin and move outward or retract according to the effect brief.", "Sparse faint last fibres; nearly clear, no hard cut-off chunk.",
]


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def source_hook(path: str, token: str) -> str:
    for i, line in enumerate((ROOT / path).read_text(encoding="utf-8").splitlines(), 1):
        if token in line:
            return f"{path}:{i}"
    raise ValueError(f"missing source hook: {path} {token}")


def pose_ref(manifest: dict, animation: str) -> Path:
    item = next(a for a in manifest["animations"] if a["name"] == animation)
    frame = item["frames"][0]
    resource = frame["atlas"] if isinstance(frame, dict) else frame
    return GODOT / resource.removeprefix("res://")


def playback_plan(mode: str) -> list[str]:
    if mode == "tile":
        return [f"Seamless cord loop frame {i+1} of 4, a glint advances RIGHT; frame 4 leads back to frame 1. Identical tile edge alpha and alignment." for i in range(4)]
    if mode == "loop":
        return [f"Small glint/flutter loop frame {i+1} of 6, constant object shape and anchor; frame 6 leads back to frame 1." for i in range(6)]
    if mode == "channel":
        return ["Gather frame 1, compact but visible.", "Gather frame 2, reach the full footprint."] + [f"Sustained loop frame {i+1} of 4; frame 6 can return to frame 3 without a jump." for i in range(4)] + ["Release frame 1: material loosens.", "Release frame 2: last sparse fibres clear away."]
    if mode == "phase":
        return ["Entry frame 1: effect gathers visibly.", "Entry frame 2: silhouette becomes established."] + [f"Middle progression frame {i+1} of 4, visibly changing silk contours." for i in range(4)] + ["Exit frame 1: main material breaks into strands.", "Exit frame 2: strands almost entirely clear."]
    if mode == "guard":
        return ["First guard threads gather on the RIGHT.", "The half-shield braces, still opening.", "Full braced guard; open back, no all-around coverage.", "Second held guard pose with small material tension change; can alternate with frame 3.", "Guard begins retracting toward the hand-side anchor.", "Last small curling threads retract, nearly clear."]
    return BURST_PLAN


def make_request(stem, name, group, look, refs, hook, anchor, mode="burst", topology=None, command=None, boss=None):
    plan = WARNING_PLAN if group.startswith("boss") else playback_plan(mode)
    count = len(plan)
    columns = 4 if count in (4, 8) else 3
    rows = count // columns
    cel = [512, 256] if topology == "beam" else [512, 384] if mode == "tile" else [384, 384]
    if mode == "tile":
        columns, rows = 2, 2
    layout = f"Exactly {count} cels in a {columns}-column x {rows}-row grid, read left-to-right then top-to-bottom. Canvas {columns*cel[0]}x{rows*cel[1]} px; every cell {cel[0]}x{cel[1]} px."
    if topology == "beam" or mode == "tile":
        registration = "Tile centreline stays at 50% cell height. Continuous material joins LEFT to RIGHT with matching alpha and texture. Keep the top and bottom 20% of each cell transparent."
    elif anchor in ("ground", "feet"):
        registration = "Effect origin is at x=50%, y=80% of every cell. Ground plane is only an invisible baseline; all material stays above it except sparse loose fibres. Main material fits inside x=15..85%, y=15..80%."
    elif anchor == "front":
        registration = "Contact origin is x=50%, y=50%; guard material occupies the RIGHT side of this origin. Main material stays inside x=45..85%, y=15..85%. The left side is open."
    else:
        registration = "Effect origin is x=50%, y=50%. Main material stays inside x=15..85%, y=15..85%; at least 10% fully transparent gutter on every side."
    extra = ""
    if group.startswith("boss"):
        extra = "This is ANTICIPATION ONLY. No damaging active projectile, impact, tall erupted spike, completed slash or generic featureless circle/line. Full warning boundary must stay legible throughout; intensify inner texture without expanding the outer footprint. No blinking to invisible and no fade-out inside the warning sheet. Readability must also come from shape/material, not colour alone.\n"
    if topology == "beam":
        extra += "Draw one repeating warning corridor material tile, horizontal to the RIGHT; no caps, perspective vanishing point or thick terminal blob. Runtime tiles then clips the visible lane to the real obstruction-truncated length and width.\n"
    if topology in ("pool", "eruption"):
        extra += "Side-view ground cue. Its horizontal danger footprint must stay fixed in all frames, even when interior wisps move. Do not draw the eventual risen hazard in a warning.\n"
    if topology == "source":
        extra += "A small LOCAL charge cue at the caster, not a promise of a whole projectile path, a landing position or a damaging area. No arena-scale cone, arrow or range disc.\n"
    prompt = COMMON + f"Reference file(s): {', '.join(refs)}.\nThe effect: {look}\n{layout}\n{registration}\n{extra}" + "\n".join(f"Cel {i+1}: {p}" for i, p in enumerate(plan)) + "\n"
    return dict(file=stem+".png", name=name, group=group, status="needs_generation", frame_count=count,
                requested_layout=dict(columns=columns, rows=rows, cel_size=cel, canvas_size=[columns*cel[0], rows*cel[1]]),
                anchor=anchor, playback=mode if not group.startswith("boss") else "windup_0_to_1_hold_last",
                topology=topology, refs=refs, runtime_hook=hook, boss_kind=boss, command=command, prompt=prompt)


def collect():
    requests, copies, bosses = [], {}, []
    hero = read(GODOT / "assets/sprites/player/generated_hero_v3/manifest.json")
    for anim in ["idle", "guard", "heal", "hook_throw", "phase", "resonance"]:
        source = pose_ref(hero, anim)
        target = f"refs/hero_{anim}{source.suffix}"
        copies[target] = source
    for stem, name, look, hook, anchor, mode in HERO:
        refs = ["refs/hero_idle.png"]
        animation = "guard" if stem.startswith("guard_") else "heal" if stem.startswith("heal_") else "hook_throw" if stem.startswith("hook_") else stem if stem in ("phase", "resonance") else None
        if animation:
            refs.append(f"refs/hero_{animation}.png")
        requests.append(make_request("FX_H2_"+stem, name, "hero", look, refs, hook, anchor, mode))
    main = (GODOT / "scripts/main_level.gd").read_text(encoding="utf-8")
    profiles = read(GODOT / "data/original_creature_combat.json")
    seen = set()
    for chapter in sorted((GODOT / "data").glob("demo_ch0*.json")):
        data = read(chapter)
        boss = data.get("boss", {})
        kind = boss.get("kind")
        if not kind or kind in seen:
            continue
        seen.add(kind)
        manifest_path = re.search(r'"'+re.escape(kind)+r'": "(res://assets/sprites/bosses/[^\"]+/manifest.json)"', main)[1]
        manifest = read(GODOT / manifest_path.removeprefix("res://"))
        ref = "refs/"+kind+".png"
        copies[ref] = ROOT / manifest["source_concept"]
        # The engine registry's displayed identity overrides misleading legacy kind strings.
        name = manifest["name_zh"]
        boss_commands = data["ai_profiles"][kind]["attacks"]
        reference_commands = {a["id"]: a for a in profiles[kind]["attacks"]}
        if {a["id"] for a in boss_commands} != set(reference_commands):
            raise ValueError("chapter/profile command coverage drift: "+kind)
        bosses.append(dict(kind=kind, name=name, source=str(chapter.relative_to(ROOT)).replace("\\", "/"), manifest=manifest_path,
                           phase_threshold=data["ai_profiles"][kind].get("phase_threshold"), command_ids=[a["id"] for a in boss_commands]))
        for command in boss_commands:
            cid = command["id"]
            topology, look = WARNINGS[cid]
            facts = {key: command[key] for key in ["id", "name", "type", "windup", "active", "recover", "phase", "radius", "hit_width", "hit_height", "offset", "beam_length", "warning", "shot_count", "spacing", "hazard_life", "targeted", "blockable", "spread", "projectile_speed"] if key in command}
            anchor = "ground" if topology in ("pool", "eruption") else "tile" if topology == "beam" else "front" if topology == "guard" else "center"
            hook = "enemy_attack_effect.gd: _draw age<arm_delay + enemy_actor.gd: _effect" if topology in ("pool", "eruption", "beam") else "enemy_actor.gd: _spawn_windup_vfx / _original_attack_arc(warning=true)"
            requests.append(make_request("FX_T_"+cid.removeprefix("boss_"), name+"·"+command["name"]+"预警", "boss_warning", look, [ref], hook, anchor, topology=topology, command=facts, boss=kind))
        requests.append(make_request("FX_C_"+kind, name+"·施法／转阶段蓄势", "boss_charge", CHARGE[kind], [ref], "enemy_actor.gd: _spawn_windup_vfx / _physics_process: battle_phase 与 phase_pause", "center", topology="source", boss=kind))
    actual = {r["command"]["id"] for r in requests if r["command"]}
    if actual != set(WARNINGS) or seen != set(CHARGE):
        raise ValueError(f"uncovered or stale boss requests: {actual ^ set(WARNINGS)}, {seen ^ set(CHARGE)}")
    for source in copies.values():
        if not source.is_file():
            raise FileNotFoundError(source)
        with source.open('rb') as stream:
            if stream.read(8) != b'\x89PNG\r\n\x1a\n':
                raise ValueError(f'Reference is not hydrated PNG data: {source}; run git lfs checkout for this source before building briefs')
    for request in requests:
        source = HERE / 'incoming' / request['file']
        if source.is_file():
            request['status'] = 'source_saved_pending_review'
            metadata = source.with_suffix('.json')
            if metadata.is_file():
                record = read(metadata)
                current = record.get('image_sha256') == hashlib.sha256(source.read_bytes()).hexdigest()
                if current and not record.get('measured_issues') and record.get('visual_review', {}).get('status') == 'source_reviewed':
                    request['status'] = 'source_reviewed_runtime_pending'
    return requests, copies, bosses


def generate_files(requests, bosses):
    hero = [r for r in requests if r["group"] == "hero"]
    warnings = [r for r in requests if r["group"] == "boss_warning"]
    charges = [r for r in requests if r["group"] == "boss_charge"]
    total = sum(r["frame_count"] for r in requests)
    files = {"prompts/"+Path(r["file"]).stem+".txt": r["prompt"] for r in requests}
    payload = dict(version=2, audited_on="2026-10-23", scope="briefs_only_no_generated_art_no_runtime_changes", total_sheets=len(requests), total_frames=total, bosses=bosses, requests=requests)
    files["requests.json"] = json.dumps(payload, ensure_ascii=False, indent=2)+"\n"
    md = [f"""# 主角动作特效与 Boss 技能预警出图清单（v2）

2026-10-23 按本地当前源码、主角实际动画清单、六章 Boss 配置和正式 Boss 资源登记核对。**清单与提示词已完成，素材分批绘制中，尚未接入游戏。** 源图与逐张检查记录见 [交付目录](incoming/README.md)，机器可读进度见 [delivery_status.json](incoming/delivery_status.json)。

新增 **{len(requests)} 张、{total} 格**：主角 {len(hero)} 张、当前六个 Boss 的 {len(warnings)} 招预警 {len(warnings)} 张、Boss 专属施法／转阶段蓄势 {len(charges)} 张。每项完整英文提示词在 `prompts/`，结构化数量、布局、引用和真实招式参数在 [requests.json](requests.json)。

## 先纠正上次遗漏

- [v1 攻击特效](../attack_effects_v1/README.md) 的 39 张／288 格已经交付源图，**运行时仍未接入**；不要重复出图。这批补上 v1 排除的预警、格挡等随身效果与近战材质。
- 主角 `guard` 已有 4 张人物姿势，问题在外层护幕和受击反馈：起手、普通挡击、完美格挡目前复用 `_ability_ring`。本批不重画人物，而是分别补 3 套可辨认的效果；普通挡击不能冒用完美格挡的成功闪光。
- **预警也要素材。** 代码负责位置、方向、范围、遮挡裁切、前摇进度和取消清理；贴图负责材质、轮廓、动画和 Boss 主题。细边界可辅助精确读范围，主体不能仍只是一条线或一个圈。
- 按当前六章真正生成的 Boss 核对，共 24 招。仓库虽有 20 套 Boss 资源，余下 14 套没有在这六章中启用；这里不虚称完成 20 个可战斗 Boss。
- `kind` 是旧内部键，不一定等于人物身份。例如 `sunken_hammer_smith` 当前显示“绯线执剪者”，不能照旧键画锤子；应以所附正式 Boss 概念图为准。

## 通用要求与交付

1. 逐项打开提示词并附上该项列出的参考图，参考图只用于配色、材质与主题；只画特效，不画角色、武器、地板、场景或 UI。主角动画和特效分层，避免左右翻转、不同配装时出现双人物。
2. 真透明 PNG，独立格有透明留白；只有注明横向平铺的钩绳／光束通道可以在左右接边。不得黑底、白底、棋盘格、文字、编号或格线。
3. 6 格使用 3×2，8 格使用 4×2，钩绳 4 格使用 2×2；精确画布尺寸见各自提示词。生成器实际输出尺寸不同，要记录实际切格坐标，不能按期望尺寸盲切。
4. 将选定的原始图放进 `incoming/`，使用清单文件名；当次**实际使用**的提示词同名保存为 `.txt`。另附同名 `.json`，记录原图尺寸、每格 `rect_xyxy`（右下不含）、有效材质范围、锚点、透明通道与检查结论。`prompts/` 是出图前任务提示词，不冒充实际生成记录。
5. 不同效果不能靠纯换色区分。格挡要有护幕／撞凹／针尖反弹差异；六个 Boss 要有苔根、剪线、灰螳刃、铜根、镜池、钥冠的材质差异。
6. 预警首帧就可读，最后一帧仍是预警；中途不消失、不淡到看不见、不把边界越扩越大。到出手时由游戏切换生效素材，被打断、死亡、切区时立即取消。
7. 不能用所有预警都铺圆圈的方式交付。近战按刀势，防御按护刃，远程只提示枪口／施法点；落点、根刺与光束必须使用独立地面／通道素材。
8. 默认警戒色服从游戏的温暖危险提示，再叠各 Boss 材质；色弱下仍凭轮廓识别。主动伤害判定、不可格挡规则与无障碍亮度规则保持由游戏驱动，不能从素材颜色猜规则。

## 接入时必须对齐的范围

- 近战：从实际 `hit_width / hit_height / offset` 和出手方向定位，不能让大刀光自行决定判定。普通挥刀材质沿实测刀根、刀尖贴合，不拉成整个矩形判定框。
- 光束：`enemy_attack_effect.gd` 的起点沿 `heading` 到 `length`，横向半宽 `radius`。`length` 已受墙体截断，按裁切后的值铺材质；不能把贴图拉出墙外。
- 池区：原点在地面附近，但当前命中使用圆心距离 `< radius + 23`（含玩家中心的近似体积），不是一个扁椭圆。贴图的水平实体边界对齐基础半径；垂直范围必须保留清楚的危险薄幕／边界，不能画成看似能安全站进去的细地缝。
- 根刺：当前命中矩形为原点 `(-radius,-92)` 到 `(radius,8)`；预警必须让人读出将向上刺出，不能只缩成脚下一粒点。素材地缝对齐左右 `radius`，竖向危险提示由游戏按真实矩形补足。
- 远程扇射／地波／瞬移／翻越：当前没有完整未来轨迹判定。只画局部蓄力，不凭空画“安全保证”的整条路径或落点圈。
- 主角防御：只保护朝向的一侧；护幕朝向随 `facing` 镜像，不画成全向罩。Q 格挡 0.42 秒，防御技能 `ward` 时长读取技能参数；前 0.14 秒为完美窗口。护幕须持续到防御结束或受击；结算后切普通／完美挡击反馈。
- 帧数不决定时长：预警 6 格按各招 `windup`／每个效果实际 `arm_delay` 的归一化进度取帧，不能统一播放固定半秒；根刺还包含逐个递增延迟。

## 建议出图顺序

先做主角格挡三项 → 六 Boss 的地刺、池区、光束预警 → 其余逐招预警与蓄势 → 主角恢复、位移、战斗、死亡效果。v1 的 39 张可同时安排接入，无需等新图全部完成。

## A. 主角动作特效

"""]
    for i, r in enumerate(hero, 1):
        md.append(f"{i}. **{r['name']}** · `{r['file']}` · {r['frame_count']} 格\n\n   - [完整提示词](prompts/{Path(r['file']).stem}.txt)；参考："+"、".join(f"[{Path(ref).stem}]({ref})" for ref in r["refs"])+f"。\n   - 触发：`{r['runtime_hook']}`；锚点 `{r['anchor']}`，播放方案 `{r['playback']}`。\n\n")
    md.append("主角持续方案：格挡 1–2 起手、3–4 持守、5–6 收回；缝补／共鸣 1–2 聚起、3–6 循环、7–8 收束；灯相 1–2 进入、3–6 可循环、7–8 退出。死亡与复活 8 格顺播，禁止将其当循环。钩绳和钩头为可循环材质。所有循环在状态取消时立即终止；缝补被打断只能播断线，不能继续播完成。\n\n## B. 六个 Boss 逐招预警\n\n")
    topologies = {"source": "施法点局部蓄力", "sweep": "刀势／出手方向", "guard": "前侧防御", "beam": "真实光束通道", "pool": "真实危险池区", "eruption": "逐点根刺地缝"}
    for boss in bosses:
        md.append(f"### {boss['name']} · `{boss['kind']}`\n\n配置：`{boss['source']}`。参考正式登记：`{boss['manifest']}`。\n\n")
        for r in [r for r in warnings if r["boss_kind"] == boss["kind"]]:
            c = r["command"]
            parameters = "，".join(f"`{key}={value}`" for key,value in c.items() if key not in ("id", "name", "type"))
            md.append(f"- **{c['name']}** · `{c['id']}` · `{c['type']}`\n\n  素材 `{r['file']}`，{r['frame_count']} 格，[完整提示词](prompts/{Path(r['file']).stem}.txt)，[角色参考]({r['refs'][0]})。\n\n  用途：**{topologies[r['topology']]}**。当前参数：{parameters}。\n\n")
        charge = next(r for r in charges if r["boss_kind"] == boss["kind"])
        md.append(f"- **通用施法／转阶段蓄势** · `{charge['file']}`，6 格，[完整提示词](prompts/{Path(charge['file']).stem}.txt)。与地面／光束预警分层，挂在 Boss 身上；不把施法点光晕冒充地面命中范围。现有转阶段保留人物 `phase` 动画，外层蓄势素材接到 `battle_phase`／`phase_pause` 状态，播放进度以该状态时长为准。\n\n")
    md.append("""## 状态与验收

- 本目录 `needs_generation` 代表尚未出图；`source_saved_pending_review` 代表已保存、待检查；`source_reviewed_runtime_pending` 代表源图基础检查通过、仍待运行时接入验收。v1 源图有独立交付状态；两批互不覆盖。
- 出图验收：逐格清点、有真 alpha、无串格、材质有可见变化、固定锚点与大小。预警不得混入生效格；缩到真实游戏尺寸后仍能凭材质分辨，深浅背景都可读。
- 接入验收：分别截格挡起手／普通挡击／完美格挡；六 Boss 每招至少取起始预警、临出手、生效、取消四状态，并叠真实判定核对。确认切区／死亡／打断会清掉随身和地面预警，暂停／UI 锁定时不偷跑播放。
- 这是一批美术任务书，未执行游戏运行时验收；不得把提示词数量当作游戏视觉已经修复。

## 源码定位与复核

""")
    for path, token in [(PLAYER, "func _try_guard"), (PLAYER, "func _ability_ring"), (PLAYER, "func _spawn_heal_effect"), (PLAYER, "func take_damage"), (ACTOR, "func _spawn_command_effects"), (ACTOR, "func _show_telegraph"), (ACTOR, "func _original_attack_arc"), (EFFECT, "func _draw"), (EFFECT, "func _hits_player")]:
        md.append(f"- `{source_hook(path, token)}` — `{token.removeprefix('func ')}`\n")
    md.append("\n在仓库根目录运行 `python -X utf8 art_requests/combat_presentation_v2/build_list.py --check`，核对 24 招完整覆盖、参考文件与已生成清单／提示词无漂移。不带 `--check` 可按当前配置重新生成本目录；不会修改运行时代码或替换 `incoming/` 原始图。\n")
    files["README.md"] = "".join(md)
    saved = [r for r in requests if r['status'] != 'needs_generation']
    incoming = [f"# 素材源图交付\n\n已保存 **{len(saved)}／{len(requests)} 张、{sum(r['frame_count'] for r in saved)}／{total} 格**。通过内置 imagegen 按 [PR #202](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/202) 制作；原始 PNG 字节保持不变，未缩放、重排或切帧。尚未接入游戏。\n\n每张附实际使用的提示词 `.txt` 与检查记录 `.json`。实际图幅可能与提示词要求不同，按检查记录的 `frames[].rect_xyxy` 切格；锚点对齐、警戒范围、光束接缝和实机缩小后的辨识度继续待验收。完整进度见 [delivery_status.json](delivery_status.json)。\n\n"]
    for r in saved:
        stem = Path(r['file']).stem
        incoming.append(f"- [{r['file']}]({r['file']}) — {r['name']}，{r['frame_count']} 格；[实际提示词]({stem}.txt)、[检查记录]({stem}.json)，`{r['status']}`。\n")
    incoming.append("\n使用 `python -X utf8 art_requests/combat_presentation_v2/inspect_sources.py` 更新检查记录；加 `--check` 可校验记录未漂移。检查脚本只读取图片，不修改像素。逐张预写任务提示词在 `../prompts/`；不要混入 v1 已交付的 39 张。\n")
    files["incoming/README.md"] = ''.join(incoming)
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    requests, copies, bosses = collect()
    files = generate_files(requests, bosses)
    issues = []
    for name, content in files.items():
        target = HERE / name
        if args.check:
            if not target.is_file() or target.read_text(encoding="utf-8") != content:
                issues.append(name)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8", newline="\n")
    for name, source in copies.items():
        target = HERE / name
        if args.check:
            if not target.is_file() or target.read_bytes() != source.read_bytes():
                issues.append(name)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    if issues:
        raise SystemExit("Missing or stale request files: "+", ".join(issues))
    print(f"COMBAT_PRESENTATION_V2 {'CHECK' if args.check else 'BUILD'} sheets={len(requests)} frames={sum(r['frame_count'] for r in requests)} bosses={len(bosses)} commands={len(WARNINGS)} refs={len(copies)}")


if __name__ == "__main__":
    main()
