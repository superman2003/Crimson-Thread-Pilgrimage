// Temporary: mirror the static asserts from godot/scripts/*_validation.gd
// across all six runtime chapter configs, and report failures per chapter.
import { readFileSync } from "node:fs";

const FILES = [
  "godot/data/demo_ch01_moss_bell_court.json",
  "godot/data/demo_ch02_rain_foundry_canal.json",
  "godot/data/demo_ch03_saltwhite_archive.json",
  "godot/data/demo_ch04_broken_string_greenhouse.json",
  "godot/data/demo_ch05_obsidian_pilgrim_road.json",
  "godot/data/demo_ch06_silent_crown_core.json",
];

const rect = (p) => p.rect.map(Number);
const isDict = (v) => v && typeof v === "object" && !Array.isArray(v);

function playableFloorAllowed(p) {
  const [_, __, w, h] = rect(p);
  const id = String(p.id || "").toLowerCase();
  if (id.includes("wall") || id.includes("gate") || id.includes("locked")) return false;
  return w >= 86 && h <= 90;
}

function positionHasFloor(cfg, pos, clearance = 40) {
  if (!Array.isArray(pos) || pos.length < 2) return false;
  const [x, y] = pos.map(Number);
  const top = y + clearance;
  return (cfg.platforms || []).some((p) => {
    if (!playableFloorAllowed(p)) return false;
    const [px, py, pw] = rect(p);
    return x >= px - 1 && x <= px + pw + 1 && Math.abs(py - top) <= 8;
  });
}

function roomContains(room, x, y) {
  const lr = room.layout_rect || room.play_rect;
  if (Array.isArray(lr) && lr.length === 4) {
    const [rx, ry, rw, rh] = lr.map(Number);
    if (x >= rx && x <= rx + rw && y >= ry && y <= ry + rh) return true;
  }
  for (const vr of room.visit_rects || []) {
    if (!Array.isArray(vr) || vr.length < 4) continue;
    const [rx, ry, rw, rh] = vr.map(Number);
    if (x >= rx && x <= rx + rw && y >= ry && y <= ry + rh) return true;
  }
  return false;
}

function usesLayoutRects(room) {
  const lr = room.layout_rect || room.play_rect;
  return Array.isArray(lr) && lr.length === 4 && Number(lr[2]) > 0 && Number(lr[3]) > 0;
}

function positionInsideAnyRoom(cfg, pos) {
  if (!Array.isArray(pos) || pos.length < 2) return false;
  const [x, y] = pos.map(Number);
  for (const room of cfg.map_rooms || []) {
    if (roomContains(room, x, y)) return true;
    if (usesLayoutRects(room)) continue;
    const r = room.range || [];
    if (r.length >= 2 && x >= Number(r[0]) && x <= Number(r[1])) return true;
  }
  return false;
}

function check(file) {
  const cfg = JSON.parse(readFileSync(file, "utf8"));
  const fails = [];
  const A = (cond, label) => { if (!cond) fails.push(label); };
  const id = cfg.id;
  const world = cfg.world || {};
  const rooms = cfg.map_rooms || [];
  const platforms = cfg.platforms || [];
  const conns = cfg.connections || [];
  const interactives = cfg.interactives || [];

  // ---- demo_validation.gd static asserts (ch01 only) ----
  if (id.includes("ch01")) {
    A(Number(world.width) >= 5200 && Number(world.height) >= 2400 && world.width * world.height >= 14e6,
      `demo_validation: world expanded 2D (got ${world.width}x${world.height})`);
    A(rooms.length >= 10, "demo_validation: rooms >= 10");
    A(platforms.length >= 20, "demo_validation: platforms >= 20");
    A((cfg.enemy_spawns || []).length >= 7, "demo_validation: enemies >= 7");
    A((cfg.hazards || []).length >= 6, "demo_validation: hazards >= 6");
    A((cfg.save_points || []).length >= 2 && (cfg.save_points || []).length <= 4, "demo_validation: save_point_total in 2..4");
  }
  // ---- ch02_demo_validation.gd static asserts (boxgarden rebuild) ----
  if (id.includes("ch02")) {
    A(rooms.length >= 30, "ch02_validation: boxgarden rooms >= 30");
    A((cfg.save_points || []).length >= 2 && (cfg.save_points || []).length <= 4, "ch02_validation: save points in 2..4");
    const gates = cfg.locked_gates || [];
    A(gates.length >= 7, "ch02_validation: locked gates >= 7");
    A(gates.every((g) => g.id && Array.isArray(g.rect) && g.rect.length === 4 && g.required_ability && g.from && g.to),
      "ch02_validation: locked gates expose id/rect/required_ability/from/to");
    const byAbility = {};
    for (const g of gates) byAbility[g.required_ability] = (byAbility[g.required_ability] || 0) + 1;
    A(byAbility.thread_dash === 2 && byAbility.silk_wall_grip === 3 && byAbility.echo_hook === 2,
      "ch02_validation: gate matrix dash x2 / wall x3 / hook x2");
    const catalog = (cfg.inventory || {}).catalog || {};
    const itemIds = (cfg.collectibles || []).map((c) => c.item_id);
    for (const req of ["silk_wall_grip", "echo_hook", "testimony_02"])
      A(itemIds.includes(req), `ch02_validation: ${req} pickup exists`);
    A((cfg.collectibles || []).every((c) => c.kind === "item" && catalog[c.item_id]),
      "ch02_validation: collectibles are catalog items only");
    A((cfg.cross_chapter_anchors || []).length >= 5, "ch02_validation: cross-chapter anchors declared");
    A(((cfg.inventory || {}).starting_tools || []).includes("thread_dash"), "ch02_validation: thread_dash back-compat starting tool");
  }
  // ---- story data layer: ch03-ch06 dialogue state machines + testimony chain ----
  const chMatch = id.match(/ch0([3-6])/);
  if (chMatch) {
    const testimonyId = `testimony_0${chMatch[1]}`;
    const itemIds = (cfg.collectibles || []).map((c) => c.item_id);
    A(itemIds.includes(testimonyId), `story_data: ${testimonyId} pickup exists`);
    A(isDict(((cfg.inventory || {}).catalog || {})[testimonyId]), `story_data: ${testimonyId} in inventory catalog`);
    const tCol = (cfg.collectibles || []).find((c) => c.item_id === testimonyId) || {};
    A(positionInsideAnyRoom(cfg, tCol.position) && positionHasFloor(cfg, tCol.position),
      `story_data: ${testimonyId} pickup sits on a floored platform inside a room`);
    for (const n of cfg.npcs || []) {
      const sd = n.story_dialogue || {};
      for (const state of ["first_meet", "repeat", "after_ability", "after_boss", "late_game", "true_ending_branch"])
        A(Array.isArray(sd[state]) && sd[state].length >= 2, `story_data: ${n.id}.story_dialogue.${state} has >= 2 lines`);
      const meta = n.dialogue_meta || {};
      A(typeof meta.ability_ref === "string" && meta.ability_ref !== "" &&
        typeof meta.testimony_ref === "string" && /^testimony_0[1-6]$/.test(meta.testimony_ref),
        `story_data: ${n.id}.dialogue_meta has ability_ref/testimony_ref`);
      A("quest_flag" in meta && "leave" in meta, `story_data: ${n.id}.dialogue_meta has quest_flag/leave keys`);
      A(Array.isArray(n.dialogue) && n.dialogue.length >= 3 &&
        n.dialogue.every((line, i) => line === (sd.first_meet || [])[i]),
        `story_data: ${n.id} fallback dialogue mirrors first_meet head`);
    }
  }
  // ---- ch06 ending gates + wish board (runtime contract: {id, ending, label, requires:{items,flags}, message}) ----
  if (id.includes("ch06")) {
    const gates = cfg.ending_gates || [];
    A(gates.length === 3, "ch06: ending_gates has exactly 3 gates");
    A(gates.every((g) => g.id && g.ending && g.label && isDict(g.requires) &&
      Array.isArray(g.requires.items) && Array.isArray(g.requires.flags) &&
      typeof g.message === "string" && g.message.length > 0),
      "ch06: ending_gates expose id/ending/label/requires{items,flags}/message");
    // Runtime contract (main_level.gd _spawn_ending_gates / ENDING_GATE_TINTS /
    // "%s_done" flag): ending must be one of ending_a|ending_b|ending_c, matching
    // the docs flag table ending_a/b/c_done. Gate identity stays in id.
    A(gates.every((g) => ["ending_a", "ending_b", "ending_c"].includes(g.ending)),
      "ch06: ending values use runtime enum ending_a/b/c");
    const byId = Object.fromEntries(gates.map((g) => [g.id, g]));
    const resound = byId.ending_gate_resound;
    const severed = byId.ending_gate_severed;
    const rewrite = byId.ending_gate_rewrite;
    A(resound && resound.ending === "ending_a" && resound.requires.items.length === 0 && resound.requires.flags.length === 0,
      "ch06: resound gate is ending_a with no requirements");
    A(severed && severed.ending === "ending_b" && severed.requires.items.length === 0 && severed.requires.flags.length === 0,
      "ch06: severed gate is ending_b with no requirements");
    const wantTestimonies = ["testimony_01", "testimony_02", "testimony_03", "testimony_04", "testimony_05", "testimony_06"];
    A(rewrite && rewrite.ending === "ending_c" && wantTestimonies.every((t) => rewrite.requires.items.includes(t)) &&
      rewrite.requires.flags.includes("true_ending_testimony_complete"),
      "ch06: rewrite gate is ending_c and requires six testimonies + true_ending_testimony_complete");
    const wishes = cfg.wish_board || [];
    A(wishes.length >= 1 && wishes.length <= 2 &&
      wishes.every((w) => w.id && w.title && w.desc && w.kind &&
        typeof w.target_flag === "string" && w.target_flag !== "" && typeof w.reward_currency === "number"),
      "ch06: wish_board entries expose id/title/desc/kind/target_flag/reward_currency");
  }

  A(cfg.progression_mode === "combat_clear", "combat_clear progression");
  A((cfg.collectibles || []).filter((c) => c.kind !== "item").length === 0, "no route-token collectibles");
  A((cfg.parkour_segments || []).length >= 1, "has parkour segment");
  A(conns.some((c) => c.type === "one_way_drop" || c.edge_kind === "one_way_drop"), "has one_way_drop connection");
  A(conns.some((c) => c.type === "shortcut" || c.edge_kind === "unlock_shortcut" || (c.shortcut_id || "") !== ""), "has shortcut connection");

  // main route: physics BFS from player_start supports (mirrors audit_platform_geometry.py)
  const standable = platforms.filter((p) => !["wall", "ceiling", "decorative"].includes(String(p.collision_role || "").toLowerCase()));
  const SPEED = 285, JUMP = 710, GRAV = 1850, DASH = 780 * 0.16 * 0.82, SAFE = 0.82, MULT = 1.22;
  const jumpH = JUMP * JUMP / (2 * GRAV);
  const combined = SPEED * (2 * JUMP / GRAV) * SAFE + DASH;
  const canJump = (a, b) => {
    const [ax, ay, aw] = rect(a); const [bx, by, bw] = rect(b);
    const dy = by - ay;
    if (-dy > jumpH * 0.88 || dy > 320) return false;
    const disc = JUMP * JUMP + 2 * GRAV * dy;
    if (disc < 0) return false;
    const t = (JUMP + Math.sqrt(disc)) / GRAV;
    const allowed = Math.min(SPEED * t * SAFE + DASH, combined * MULT);
    const gap = Math.max(0, bx - (ax + aw), ax - (bx + bw));
    if (gap > 0 && bw < 64) return false;
    return gap <= allowed;
  };
  const startIdx = [];
  standable.forEach((p, i) => {
    const [px, py, pw] = rect(p);
    const [sx, sy] = (cfg.player_start || [0, 0]).map(Number);
    if (sx >= px - 17 && sx <= px + pw + 17) { const off = py - sy; if (off >= -8 && off <= 100) startIdx.push(i); }
  });
  const reach = new Set(startIdx); const q = [...startIdx];
  while (q.length) { const c = q.shift(); standable.forEach((p, i) => { if (!reach.has(i) && canJump(standable[c], p)) { reach.add(i); q.push(i); } }); }
  const mainUnreached = standable.filter((p, i) => p.route_role === "main" && !reach.has(i)).map((p) => p.id);
  A(startIdx.length > 0, "player_start has support platform");
  A(mainUnreached.length === 0, `main route physics-reachable (unreached: ${mainUnreached.slice(0, 6).join(",")})`);

  // parkour clearance
  A((cfg.parkour_segments || []).some((s) => Number(s.safety_contract?.minimum_full_jump_clearance || 0) >= 200), "parkour clearance >= 200");

  // ---- all_chapters_demo_validation.gd static asserts (updated 2D form) ----
  A(Number(world.width) >= 5200 && Number(world.height) >= 2400 && world.width * world.height >= 14e6,
    `all_chapters: world expanded 2D (got ${world.width}x${world.height})`);
  const vertices = Number(cfg.map_topology?.graph_fingerprint?.vertices || 0);
  A(rooms.length === vertices, `all_chapters: rooms(${rooms.length}) == topology vertices(${vertices})`);
  A(platforms.length >= rooms.length * 2, "all_chapters: platforms >= rooms*2");

  // rooms cover world: every room has positive layout_rect; union spans >=72% w, >=55% h
  let cw = { minx: Infinity, miny: Infinity, maxx: -Infinity, maxy: -Infinity };
  let allHaveLayout = true;
  for (const r of rooms) {
    const lr = r.layout_rect || r.play_rect;
    if (!Array.isArray(lr) || lr.length !== 4 || Number(lr[2]) <= 0 || Number(lr[3]) <= 0) { allHaveLayout = false; break; }
    const [x, y, w, h] = lr.map(Number);
    cw.minx = Math.min(cw.minx, x); cw.miny = Math.min(cw.miny, y);
    cw.maxx = Math.max(cw.maxx, x + w); cw.maxy = Math.max(cw.maxy, y + h);
  }
  A(allHaveLayout && (cw.maxx - cw.minx) >= world.width * 0.72 && (cw.maxy - cw.miny) >= world.height * 0.55,
    `all_chapters: rooms cover world (span ${allHaveLayout ? `${(cw.maxx - cw.minx).toFixed(0)}x${(cw.maxy - cw.miny).toFixed(0)}` : "missing layout_rect"} vs world ${world.width}x${world.height})`);

  // multilayer room kinds: >=3 room types, layer span >= 3
  const types = new Set(rooms.map((r) => String(r.room_type || r.kind || "")));
  const layers = rooms.map((r) => Number(r.layer ?? r.depth ?? 0));
  A(types.size >= 3 && Math.max(...layers) - Math.min(...layers) >= 3,
    `all_chapters: multilayer kinds (types=${types.size}, layer span=${Math.max(...layers) - Math.min(...layers)})`);

  // multilevel platforms: thirds of playable floor span, span >= 1200
  const floorYs = platforms.filter(playableFloorAllowed).map((p) => rect(p)[1]);
  const fMin = Math.min(...floorYs), fMax = Math.max(...floorYs), band = (fMax - fMin) / 3;
  const bandHit = [false, false, false];
  for (const y of floorYs) bandHit[Math.min(2, Math.floor((y - fMin) / Math.max(1, band)))] = true;
  A(fMax - fMin >= 1200 && bandHit.every(Boolean),
    `all_chapters: multilevel bands (span=${(fMax - fMin).toFixed(0)}, bands=${bandHit})`);

  // connections reference rooms
  const roomIds = new Set(rooms.map((r) => r.id));
  A(conns.length > 0 && conns.every((c) => roomIds.has(c.from) && roomIds.has(c.to)), "all_chapters: connections reference rooms");

  // positions map to rooms
  const outOfRoom = [];
  const positions = [["player_start", cfg.player_start], ["boss_checkpoint", cfg.boss_checkpoint], ["boss", cfg.boss?.position]];
  for (const e of cfg.enemy_spawns || []) positions.push([`enemy ${e.id}`, e.position]);
  for (const s of cfg.save_points || []) positions.push([`save ${s.id}`, s.position]);
  for (const n of cfg.npcs || []) positions.push([`npc ${n.id}`, n.position]);
  for (const i of interactives) positions.push([`interactive ${i.id}`, i.position]);
  for (const [label, pos] of positions) if (!positionInsideAnyRoom(cfg, pos)) outOfRoom.push(label);
  A(outOfRoom.length === 0, `all_chapters: positions inside rooms (out: ${outOfRoom.slice(0, 8).join(", ")})`);

  // floors under key positions
  const bossRoom = rooms.find((r) => r.kind === "boss");
  const bossGate = interactives.find((i) => i.kind === "boss_gate") || {};
  const exit = interactives.find((i) => i.kind === "chapter_exit" || i.kind === "ending_exit") || {};
  A(positionHasFloor(cfg, cfg.boss_checkpoint), "all_chapters: boss checkpoint has floor");
  A(positionHasFloor(cfg, bossGate.position), "all_chapters: boss gate has floor");
  A(positionHasFloor(cfg, cfg.boss?.position), "all_chapters: boss spawn has floor");
  A(positionHasFloor(cfg, exit.position), "all_chapters: exit has floor");
  A(bossRoom && positionInsideAnyRoom({ map_rooms: [bossRoom] }, cfg.boss?.position), "all_chapters: boss inside boss room");
  A(bossRoom && positionInsideAnyRoom({ map_rooms: [bossRoom] }, bossGate.position), "all_chapters: boss gate inside boss room");

  // boss ai profile
  const bossKind = cfg.boss?.kind;
  const prof = (cfg.ai_profiles || {})[bossKind] || {};
  const atkTypes = new Set((prof.attacks || []).map((a) => a.type));
  A((prof.attacks || []).length >= 9, "all_chapters: boss >= 9 attacks");
  A(atkTypes.has("shockwave") && atkTypes.has("retreat") && atkTypes.has("feint"), "all_chapters: boss attack types");
  A((prof.attacks || []).every((a) => a.windup_scale && a.active_scale && a.recover_offset), "all_chapters: boss pose keys");
  for (const kind of new Set((cfg.enemy_spawns || []).map((e) => e.kind))) {
    const p = (cfg.ai_profiles || {})[kind];
    if (!p) { fails.push(`ai profile missing: ${kind}`); continue; }
    if ((p.attacks || []).length !== 1) fails.push(`small enemy attacks != 1: ${kind}`);
  }

  // save points
  A((cfg.save_points || []).length <= 4, "save points <= 4");
  A((cfg.save_points || []).some((s) => s.hidden), "has hidden save point");

  // exit points to next
  if (id.endsWith("silent_crown_core")) A(exit.kind === "ending_exit", "ch06 exit is ending_exit");
  else {
    const t = cfg.chapter_transition || {};
    A(exit.kind === "chapter_exit" && t.to_runtime_config_id && exit.next_runtime_config_id === t.to_runtime_config_id, "exit matches chapter_transition");
  }

  // enemy spawn platform allowed (86 wide, <=90 tall, not wall/gate) near requested pos
  const badSpawn = [];
  for (const e of cfg.enemy_spawns || []) {
    const pid = e.platform_id;
    const p = platforms.find((x) => x.id === pid);
    if (!p) { badSpawn.push(`${e.id}: platform ${pid} missing`); continue; }
    const [px, py, pw, ph] = rect(p);
    const lowered = String(pid).toLowerCase();
    if (lowered.includes("wall") || lowered.includes("gate") || lowered.includes("locked") || pw < 86 || ph > 90) badSpawn.push(`${e.id}: platform ${pid} not allowed`);
  }
  A(badSpawn.length === 0, `enemy platforms allowed (${badSpawn.slice(0, 5).join("; ")})`);

  // leash radius
  A((cfg.enemy_spawns || []).every((e) => Number(e.leash_radius || 0) > 0 && Number(e.leash_radius) <= 280), "enemy leash radius in (0,280]");

  // npc dialogue
  A((cfg.npcs || []).every((n) => (n.dialogue || []).length >= 3), "npcs have >= 3 dialogue lines");

  // materials: unique per chapter checked globally later
  return { id, fails, world, rooms: rooms.length, platforms: platforms.length, materials: [...new Set(platforms.map((p) => p.material))].sort() };
}

const results = FILES.map(check);
let total = 0;
const matSets = new Map();
for (const r of results) {
  console.log(`\n=== ${r.id}  world=${r.world.width}x${r.world.height} rooms=${r.rooms} platforms=${r.platforms}`);
  console.log(`materials: ${r.materials.join(",")}`);
  const sig = r.materials.join("|");
  if (matSets.has(sig)) console.log(`FAIL material signature duplicates ${matSets.get(sig)}`);
  matSets.set(sig, r.id);
  if (r.fails.length === 0) console.log("ALL STATIC CHECKS PASS");
  for (const f of r.fails) { console.log(`FAIL ${f}`); total++; }
}
console.log(`\nTOTAL FAILURES: ${total}`);
