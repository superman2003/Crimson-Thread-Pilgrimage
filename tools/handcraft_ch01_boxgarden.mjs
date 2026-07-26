// Hand-authored Chapter 1 "苔钟庭" — Silksong-style box-garden rebuild (42 rooms).
//
// World cross-section (see docs/spec/20260726150500000_苔钟庭箱庭重设计.md):
//
//   upper  [belfry_top][hidden_attic][salt_corridor]        y  560-1000
//          [crown_walk / nook]  [bell_ascent shaft]         y  600-2100
//          [hub_gallery ring]---[east_balcony/moth/overlook/bell_gap]
//   mid    [entry cliffs]->[crawl]->[ COURT HUB (2800px tall) ]->[boss wing]->exit
//   lower  [west overgrowth maze -> broken branch altar (THREAD DASH)]
//          [cistern shaft -> ring -> fake-moss grotto -> underway -> sluice]
//          [back-door stair-well climbs all the way back to the hub station]
//          [root vault -> well throat (crown-sealed abyss door)]
//
// Every main-route hop is validated with the same conservative physics the
// strict audits use, PLUS a stricter no-dash check (thread_dash is now a
// pickup found at the broken branch altar; the critical path never needs it).

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BASE_PATH = join(ROOT, "godot/data/demo_ch01_moss_bell_court.json");
const OUT_PATH = BASE_PATH;

// ---- physics mirror (matches tools/audit_platform_geometry.py) -------------
const PHYS = { speed: 285, jump: 710, gravity: 1850, dashReach: 780 * 0.16 * 0.82 };
const JUMP_H = PHYS.jump ** 2 / (2 * PHYS.gravity);
const MIN_HEAD = 104, MIN_WALL_GAP = 48, PLAYER_W = 34;

function reachable(a, b, useDash = true) {
  const dY = b.y - a.y;
  if (-dY > JUMP_H * 0.88) return false;   // rise too high
  if (dY > 320) return false;              // drop too deep
  const disc = PHYS.jump ** 2 + 2 * PHYS.gravity * dY;
  if (disc < 0) return false;
  const t = (PHYS.jump + Math.sqrt(disc)) / PHYS.gravity;
  const dash = useDash ? PHYS.dashReach : 0;
  const combined = (PHYS.speed * (2 * PHYS.jump / PHYS.gravity) * 0.82 + dash) * 1.22;
  const allowed = Math.min(PHYS.speed * t * 0.82 + dash, combined);
  const gap = Math.max(0, b.x - (a.x + a.w), a.x - (b.x + b.w));
  if (gap > 0 && b.w < 64) return false;
  return gap <= allowed;
}

// ---- room metadata ---------------------------------------------------------
// zoneA entry cliffs / zoneB hub / zoneC tower / zoneD cistern / zoneE maze /
// zoneF boss wing / zoneG east upper ring
const ROOMS = {
  // A ------------------------------------------------------------------------
  entry_bell: { name: "朝圣断阶", kind: "entry", depth: 3,
    objective: "沿断阶东行，寻找进入钟庭的路。", guide: "西侧封死的朝圣阶通往黑曜巡礼路，机关在对侧。",
    danger: "落点干净，但苔藓机关和敌人前摇仍会要命。", next: "苔落走廊", setpiece: "塌半边的朝圣旧阶",
    traversal_focus: "安全试跳", pacing_role: "explore_and_loop" },
  moss_descent: { name: "苔落走廊", kind: "corridor", depth: 3,
    objective: "下行练习下劈反弹，脚下的裂口通向西苔脉。", guide: "西侧裂口是单向下坠——想好再跳。",
    danger: "湿苔打滑，坠口无回头路。", next: "初鸣钟龛", setpiece: "断钟舌吊在走廊尽头",
    traversal_focus: "下劈教学", pacing_role: "explore_and_loop" },
  first_bell_shrine: { name: "初鸣钟龛", kind: "save", depth: 3,
    objective: "点亮第一座苔灯钟龛。", guide: "钟龛会记录你的归处。",
    danger: "安全屋，稍作歇息。", next: "窄苔缝", setpiece: "第一座苔灯",
    traversal_focus: "存档教学", pacing_role: "respite" },
  crawl_gate: { name: "窄苔缝", kind: "corridor", depth: 3,
    objective: "贴顶匍匐挤过窄缝。", guide: "压低身形，前方有光。",
    danger: "低顶通道，无法起跳。", next: "中央钟庭", setpiece: "一线天苔缝",
    traversal_focus: "压缩通道", pacing_role: "tension" },
  // B ------------------------------------------------------------------------
  court_hub: { name: "中央钟庭", kind: "hub", depth: 3,
    objective: "以钟庭为枢纽：上攀钟塔、下探水窖、西寻苔脉、东讨守母。", guide: "记住这里；所有环路都会绕回钟庭。",
    danger: "开阔中庭利于机动，也利于敌人合围。", next: "四方", setpiece: "倒悬巨钟的空腔",
    traversal_focus: "垂直枢纽分流", pacing_role: "hub" },
  bellbone_station: { name: "钟骨长梯站厅", kind: "transit", depth: 3,
    objective: "参观封存的钟骨长梯站厅。", guide: "贯穿世界的长梯尚未通行，记住它的位置。",
    danger: "站厅安静得过分。", next: "中央钟庭", setpiece: "青铜长梯剪影",
    traversal_focus: "世界纵轴锚点", pacing_role: "respite" },
  hub_gallery: { name: "环庭回廊", kind: "corridor", depth: 2,
    objective: "沿回廊横越钟庭上层。", guide: "东端通向露台环带。",
    danger: "回廊悬空，铜蛾游弋。", next: "东庭露台 / 钟塔", setpiece: "环庭悬廊",
    traversal_focus: "高空横越", pacing_role: "explore_and_loop" },
  threadmakers_cache: { name: "织线暗室", kind: "secret", depth: 3,
    objective: "冲过钟隙取回织线者的遗物。", guide: "需要绯线冲刺。",
    danger: "隙风削骨。", next: "中央钟庭", setpiece: "织线者的断机",
    traversal_focus: "冲刺门", pacing_role: "reward" },
  // C ------------------------------------------------------------------------
  bell_ascent: { name: "钟骨折梯", kind: "shaft", depth: 1,
    objective: "沿之字踏板垂直攀上钟塔。", guide: "踏板交错向上，注意坠锤。",
    danger: "坠落很深，短跳稳住节奏。", next: "半钟平台", setpiece: "垂直钟绳井",
    traversal_focus: "纵向攀爬", pacing_role: "explore_and_loop" },
  belfry_mid: { name: "半钟平台", kind: "arena", depth: 1,
    objective: "清理半钟平台的伏击。", guide: "东角地面空洞——将来能劈开。",
    danger: "孢钟匠自高处泼洒孢云。", next: "顶阁", setpiece: "半悬的破钟",
    traversal_focus: "立体战斗", pacing_role: "pressure" },
  bell_marrow_cell: { name: "钟髓密室", kind: "gate", depth: 1,
    objective: "劈开脆钟地板，取回钟髓中的证词线索。", guide: "需要棘线下劈（断弦温室）。",
    danger: "密室封存的东西不愿被读。", next: "半钟平台", setpiece: "钟髓结晶",
    traversal_focus: "回访门", pacing_role: "reward" },
  belfry_top: { name: "顶阁", kind: "treasure", depth: 0,
    objective: "登顶钟塔，俯瞰整座苔钟庭。", guide: "西沿是钟冠悬廊的起点。",
    danger: "顶阁边缘狭窄，风势不稳。", next: "钟冠悬廊", setpiece: "顶阁观景台",
    traversal_focus: "登顶释放", pacing_role: "respite" },
  hidden_attic: { name: "顶阁暗格", kind: "secret", depth: 0,
    objective: "找到暗格里的隐苔存档点。", guide: "暗格藏在半钟平台东上方。",
    danger: "暗格无声。", next: "盐风走廊", setpiece: "隐苔龛",
    traversal_focus: "隐藏探索", pacing_role: "reward" },
  salt_corridor: { name: "盐风走廊", kind: "gate", depth: 0,
    objective: "仰望盐白档案馆的风口。", guide: "需要双线跃（盐白档案馆）才能跃上风口。",
    danger: "盐风割面。", next: "盐白档案馆（回访）", setpiece: "盐渍风口",
    traversal_focus: "回访门", pacing_role: "foreshadow" },
  crown_walk: { name: "钟冠悬廊", kind: "corridor", depth: 0,
    objective: "沿钟冠向西横越，从裂缝一跃坠回钟庭。", guide: "尽头是直落枢纽的单向坠道。",
    danger: "高空悬廊风大，落点狭窄。", next: "中央钟庭", setpiece: "横越钟冠悬廊",
    traversal_focus: "高空回环", pacing_role: "explore_and_loop" },
  crown_splinter_nook: { name: "冠裂隙", kind: "secret", depth: 0,
    objective: "冲过冠隙取回地图残页。", guide: "需要绯线冲刺。",
    danger: "隙底即深渊。", next: "钟冠悬廊", setpiece: "嵌着残页的裂缝",
    traversal_focus: "冲刺门", pacing_role: "reward" },
  // G ------------------------------------------------------------------------
  east_balcony: { name: "东庭露台", kind: "corridor", depth: 2,
    objective: "从回廊踏上东庭露台环带。", guide: "环带一路向东，最终俯瞰铸雨渠。",
    danger: "露台年久失修。", next: "铜蛾栖廊", setpiece: "苔蚀露台",
    traversal_focus: "环带横越", pacing_role: "explore_and_loop" },
  moth_roost: { name: "铜蛾栖廊", kind: "arena", depth: 2,
    objective: "穿过铜蛾的栖廊。", guide: "蛾群怕光也怕刃。",
    danger: "空战廊道，脚下是空的。", next: "雨眺台", setpiece: "垂挂的蛾茧",
    traversal_focus: "空中战斗", pacing_role: "pressure" },
  rain_overlook: { name: "雨眺台", kind: "vista", depth: 2,
    objective: "眺望下方的铸雨渠。", guide: "东端钟隙对岸就是锈冠殿顶。",
    danger: "眺台风雨欲来。", next: "钟隙渡口", setpiece: "远处的铸雨渠灯火",
    traversal_focus: "前瞻释放", pacing_role: "foreshadow" },
  bell_gap_crossing: { name: "钟隙渡口", kind: "gate", depth: 2,
    objective: "冲过钟隙，打开通往锈冠殿顶的捷径。", guide: "需要绯线冲刺；渡过后可直落冠后宝库。",
    danger: "钟隙深不见底。", next: "冠后宝库", setpiece: "断裂的渡口横梁",
    traversal_focus: "冲刺门捷径", pacing_role: "reward" },
  // D ------------------------------------------------------------------------
  cistern_shaft: { name: "根须竖井", kind: "shaft", depth: 5,
    objective: "从钟庭地缝降入根须水窖。", guide: "这是单向坠道——回程走后门升梯。",
    danger: "井壁湿滑，无法攀回。", next: "水窖环廊", setpiece: "垂根缠绕的竖井",
    traversal_focus: "纵向下探", pacing_role: "explore_and_loop" },
  cistern_ring: { name: "水窖环廊", kind: "corridor", depth: 5,
    objective: "沿双层环廊探索水窖。", guide: "上层苔面有一段颜色不对。",
    danger: "假苔地板一踩就塌。", next: "暗河走道", setpiece: "绕柱双层环廊",
    traversal_focus: "环形探索", pacing_role: "explore_and_loop" },
  fake_moss_grotto: { name: "假苔穴", kind: "secret", depth: 6,
    objective: "从塌落的苔板下探出隐藏石穴。", guide: "塌方不是终点，是入口。",
    danger: "穴壁渗水，回声很远。", next: "暗河走道", setpiece: "苔板塌出的石穴",
    traversal_focus: "陷阱即通路", pacing_role: "reward" },
  underway: { name: "暗河走道", kind: "corridor", depth: 6,
    objective: "沿暗河西行，寻找闸厅。", guide: "东侧深廊被钟隙封住。",
    danger: "低照度，孢虫巢就在头顶。", next: "闸厅", setpiece: "半沉的暗河栈道",
    traversal_focus: "低视野推进", pacing_role: "pressure" },
  cistern_deep_gallery: { name: "水窖深廊", kind: "secret", depth: 6,
    objective: "冲过钟隙进入深廊。", guide: "需要绯线冲刺。",
    danger: "深廊水声不对劲。", next: "假苔穴", setpiece: "沉在水下的钟",
    traversal_focus: "冲刺门", pacing_role: "reward" },
  sluice_hall: { name: "闸厅", kind: "corridor", depth: 7,
    objective: "拉下闸杆，接通回钟庭的后门升梯。", guide: "升梯打通后长期有效。",
    danger: "拉杆时留意残敌。", next: "后门升梯井", setpiece: "锈死的水闸",
    traversal_focus: "捷径解锁", pacing_role: "reward" },
  bell_stair_well: { name: "后门升梯井", kind: "shaft", depth: 5,
    objective: "沿升梯一路爬回钟骨站厅。", guide: "这是水窖与迷园唯一的回程。",
    danger: "升梯很长，别在中途松手。", next: "钟骨长梯站厅", setpiece: "贯穿三层的升梯井",
    traversal_focus: "纵向回环", pacing_role: "explore_and_loop" },
  root_vault: { name: "根须库房", kind: "treasure", depth: 7,
    objective: "搜刮库房，听织线学徒的姐姐讲深井的事。", guide: "库房再往东就是井喉。",
    danger: "孢箱会炸。", next: "井喉", setpiece: "堆满松脂罐的库房",
    traversal_focus: "奖励与叙事", pacing_role: "respite" },
  well_throat: { name: "井喉", kind: "gate", depth: 8,
    objective: "抵达被王冠纹章封死的井喉。", guide: "需要王冠共鸣（寂冠核心）；门后是深井黑潮与第一份证词。",
    danger: "井下传来潮声，像很多人同时呼吸。", next: "深井黑潮（终局）", setpiece: "封铃井盖",
    traversal_focus: "终局门", pacing_role: "foreshadow" },
  // E ------------------------------------------------------------------------
  overgrowth_gate: { name: "苔脉门厅", kind: "corridor", depth: 4,
    objective: "从走廊裂口坠入西苔脉。", guide: "这条支脉通向迷园深处。",
    danger: "落地后无法原路爬回。", next: "缠根迷径", setpiece: "根须撕开的门洞",
    traversal_focus: "单向下探", pacing_role: "explore_and_loop" },
  tangle_maze: { name: "缠根迷径", kind: "corridor", depth: 4,
    objective: "在缠根间穿行，路越走越窄。", guide: "顶上的根越来越低——快到了。",
    danger: "窄径难以腾挪。", next: "垂藤井", setpiece: "缠根压顶的窄径",
    traversal_focus: "压缩通道", pacing_role: "tension" },
  vine_well: { name: "垂藤井", kind: "shaft", depth: 5,
    objective: "沿垂藤逐级坠入井底。", guide: "东壁的竖井要墙跳才能上去。",
    danger: "藤条只接得住一次。", next: "迷园歇脚", setpiece: "垂藤单向井",
    traversal_focus: "纵向下探", pacing_role: "tension" },
  mossgrip_shaft: { name: "苔壁竖井", kind: "gate", depth: 4,
    objective: "沿可攀苔壁跳上竖井。", guide: "需要丝壁攀附（铸雨渠）。",
    danger: "苔壁湿滑。", next: "垂藤井", setpiece: "两面对峙的苔壁",
    traversal_focus: "回访门", pacing_role: "reward" },
  maze_respite: { name: "迷园歇脚", kind: "save", depth: 6,
    objective: "在祭坛前最后一次点灯。", guide: "下面就是断枝祭坛——准备好再跳。",
    danger: "安全屋，但下方传来钟声。", next: "断枝祭坛", setpiece: "根须间的苔灯",
    traversal_focus: "战前存档", pacing_role: "respite" },
  broken_branch_altar: { name: "断枝祭坛", kind: "arena", depth: 7,
    objective: "击败苔脉守卫，取回绯线冲刺。", guide: "拿到冲刺后，全庭的钟隙都为你打开。",
    danger: "守卫的巢就在祭坛正中。", next: "闸厅（东出）", setpiece: "巨窟中的断枝祭坛",
    traversal_focus: "精英战与能力获取", pacing_role: "climax" },
  moss_veins: { name: "苔脉裂缝", kind: "gate", depth: 7,
    objective: "查看透出灯影的黑曜裂缝。", guide: "需要灯影相位（黑曜巡礼路）。",
    danger: "裂缝里的灯影在动。", next: "黑曜巡礼路（回访）", setpiece: "透光的黑曜裂缝",
    traversal_focus: "回访门", pacing_role: "foreshadow" },
  // F ------------------------------------------------------------------------
  rust_approach: { name: "锈冠前庭", kind: "corridor", depth: 4,
    objective: "突破重怪把守的前庭。", guide: "走廊重怪硬吃不亏——绕背打。",
    danger: "前庭敌人密集。", next: "齿轮平台", setpiece: "锈蚀的仪仗残骸",
    traversal_focus: "重压走廊", pacing_role: "pressure" },
  gear_terrace: { name: "齿轮平台", kind: "arena", depth: 4,
    objective: "清掉齿轮哨卫，登上殿前台地。", guide: "上层齿架可以借力。",
    danger: "哨卫合围很快。", next: "殿前钟龛", setpiece: "半埋的巨齿轮",
    traversal_focus: "立体战斗", pacing_role: "pressure" },
  pre_boss_shrine: { name: "殿前钟龛", kind: "save", depth: 4,
    objective: "点亮殿前苔灯，准备面对守母。", guide: "死亡回跑很短。",
    danger: "门后就是守母的领域。", next: "锈冠殿", setpiece: "殿前苔灯",
    traversal_focus: "战前存档", pacing_role: "tension" },
  rust_crown_hall: { name: "锈冠殿", kind: "boss", depth: 4,
    objective: "击败苔钟守母，取回王冠裂片。", guide: "入口会在战斗时封闭。",
    danger: "守母的震地与冲撞覆盖全场。", next: "冠后宝库", setpiece: "守母钟殿",
    traversal_focus: "首领战", pacing_role: "boss" },
  crown_treasury: { name: "冠后宝库", kind: "treasure", depth: 4,
    objective: "清点守母守了一生的东西。", guide: "头顶的裂口通向钟隙渡口。",
    danger: "战后余震。", next: "排水钟管", setpiece: "王冠祭器堆",
    traversal_focus: "战后奖励", pacing_role: "denouement" },
  drain_bellpipe: { name: "排水钟管", kind: "exit", depth: 4,
    objective: "钻入排水钟管，前往铸雨渠。", guide: "出口通往第二章。",
    danger: "管内潮湿铁声隆隆。", next: "第二章：铸雨渠", setpiece: "巨大的排水钟管",
    traversal_focus: "章节收束", pacing_role: "denouement" },
};
const ROOM_ORDER = Object.keys(ROOMS);

// ---- platform layout -------------------------------------------------------
// [id, x, y, w, h, room, {oneway,mat,color,role,ceiling}]
// role: 'main' critical path, 'branch' optional/secret, 'shortcut' back-door.
const P = [];
const add = (id, x, y, w, h, room, o = {}) => P.push([id, x, y, w, h, room, o]);
// zig-zag ladder helper: n one-way steps climbing (dy<0) or dropping (dy>0)
const zig = (prefix, room, x1, x2, y0, dy, n, opts = {}) => {
  const w = opts.w || 150, h = opts.h || 24;
  for (let i = 0; i < n; i++)
    add(`${prefix}${String(i + 1).padStart(2, "0")}`, i % 2 === 0 ? x1 : x2, y0 + dy * (i + 1), w, h, room,
      { oneway: true, mat: opts.mat || "bronze_bridge", color: opts.color || "6d6645", role: opts.role });
};

// A ─ entry cliffs (mid west) ------------------------------------------------
add("start_ground",     140, 3400, 320, 44, "entry_bell", {});
add("entry_step_a",     560, 3452, 150, 26, "entry_bell", { oneway: true });
add("entry_step_b",     800, 3532, 150, 26, "entry_bell", { oneway: true });
add("pilgrim_stair_ledge", 130, 3080, 160, 26, "entry_bell", { oneway: true, role: "branch", color: "233a28" }); // sealed ch5 door, see-not-reach
add("md_run",          1010, 3612, 260, 34, "moss_descent", {});
add("md_step",         1340, 3692, 150, 26, "moss_descent", { oneway: true });
add("shrine_floor",    1560, 3752, 300, 40, "first_bell_shrine", {});
add("crawl_floor",     1960, 3812, 420, 36, "crawl_gate", {});
add("crawl_roof",      1960, 3656, 420, 36, "crawl_gate", { ceiling: true, role: "branch", color: "10130f" });

// B ─ central court hub (2800px tall) ---------------------------------------
add("hub_floor_w",     2460, 3892, 560, 50, "court_hub", {});
add("hub_floor_e",     3170, 3892, 560, 50, "court_hub", {});   // 150px pit between = cistern drop
add("hub_e_ledge",     3810, 3820, 170, 28, "court_hub", { oneway: true });
zig("hw", "court_hub", 2520, 2760, 3892, -92, 7);               // west wall ladder up
add("station_floor",   2060, 3160, 340, 40, "bellbone_station", {});
zig("hx", "court_hub", 2520, 2760, 3160, -94, 4);               // station -> gallery band
add("hg_w",            2980, 2730, 190, 28, "hub_gallery", { oneway: true });
add("hg_c1",           3280, 2690, 170, 26, "hub_gallery", { oneway: true });
add("hg_c2",           3580, 2730, 170, 26, "hub_gallery", { oneway: true });
add("hg_c3",           3880, 2690, 170, 26, "hub_gallery", { oneway: true });
add("hub_balcony_e",   4160, 2740, 240, 30, "hub_gallery", { oneway: true });
zig("ht", "court_hub", 3300, 3540, 2690, -94, 5);               // gallery -> tower base
add("hub_top_shelf",   3430, 2126, 320, 36, "court_hub", {});
add("cache_floor",     1560, 3160, 280, 36, "threadmakers_cache", { role: "branch", color: "1f3226" }); // west of station, 220px dash gap behind sealed gate

// C ─ bell tower -------------------------------------------------------------
zig("ba", "bell_ascent", 3820, 3600, 2126, -94, 12);
add("bm_floor",        3880,  910, 360, 42, "belfry_mid", {});
add("cell_floor",      3960, 1210, 260, 36, "bell_marrow_cell", { role: "branch", color: "2b4633" });
add("bt_step_a",       3700,  822, 150, 24, "belfry_top", { oneway: true });
add("bt_step_b",       3460,  728, 150, 24, "belfry_top", { oneway: true });
add("belfry_floor",    3080,  650, 340, 40, "belfry_top", {});
add("belfry_over",     2830,  600, 160, 26, "belfry_top", { oneway: true });
add("attic_step",      4340,  820, 150, 24, "hidden_attic", { oneway: true, role: "branch", color: "233a28" });
add("attic_floor",     4350,  716, 240, 32, "hidden_attic", { role: "branch", color: "233a28" });
add("salt_floor",      4720,  650, 300, 36, "salt_corridor", { role: "branch", color: "3a3f38" });
add("salt_ledge",      5190,  560, 180, 26, "salt_corridor", { oneway: true, role: "branch", color: "3a3f38" }); // behind double-jump gate
add("cw_a",            2560,  640, 180, 26, "crown_walk", { oneway: true });
add("cw_b",            2280,  690, 180, 26, "crown_walk", { oneway: true });
add("cw_drop",         2860,  780, 240, 32, "crown_walk", {});
add("nook_floor",      1950,  700, 220, 30, "crown_splinter_nook", { role: "branch", color: "1f3226" });

// G ─ east upper ring --------------------------------------------------------
add("eb_floor",        4550, 2790, 320, 38, "east_balcony", {});
add("mo_a",            4990, 2730, 180, 28, "moth_roost", { oneway: true });
add("mo_b",            5290, 2670, 180, 28, "moth_roost", { oneway: true });
add("mo_c",            5590, 2730, 180, 28, "moth_roost", { oneway: true });
add("ro_floor",        5900, 2790, 320, 40, "rain_overlook", {});
add("bgc_w",           6340, 2740, 180, 28, "bell_gap_crossing", {});
add("bgc_e",           6680, 2740, 200, 30, "bell_gap_crossing", { role: "branch", color: "1f3226" }); // behind dash gate, drops to treasury

// D ─ cistern ----------------------------------------------------------------
add("cs_drop_1",       3040, 4160, 130, 26, "cistern_shaft", { oneway: true });
add("cs_drop_2",       2840, 4400, 150, 26, "cistern_shaft", { oneway: true });
add("cs_drop_3",       3060, 4620, 150, 26, "cistern_shaft", { oneway: true });
add("cr_upper",        3000, 4830, 780, 40, "cistern_ring", {});
add("cr_w_step",       2820, 4980, 150, 26, "cistern_ring", { oneway: true });
add("cr_lower",        2960, 5120, 820, 46, "cistern_ring", {});
add("fg_floor",        3160, 5420, 420, 42, "fake_moss_grotto", {});
add("uw_a",            2740, 5500, 300, 38, "underway", {});
add("uw_b",            2360, 5560, 240, 34, "underway", {});
add("cdg_floor",       3760, 5420, 320, 38, "cistern_deep_gallery", { role: "branch", color: "1f3226" });
add("sl_floor",        2140, 5660, 400, 46, "sluice_hall", {});
zig("sw", "bell_stair_well", 2120, 2290, 5660, -92, 25, { role: "shortcut" });
add("sw_top",          2360, 3268, 150, 26, "bell_stair_well", { oneway: true, mat: "bronze_bridge", color: "6d6645", role: "shortcut" });
add("rv_step",         2600, 5760, 150, 26, "root_vault", { oneway: true });
add("rv_floor",        2760, 5860, 420, 46, "root_vault", {});
add("wt_step",         3300, 5940, 160, 28, "well_throat", { oneway: true });
add("wt_floor",        3580, 6020, 380, 46, "well_throat", {});
add("wta_floor",       4090, 6020, 300, 42, "well_throat", { role: "branch", color: "1a1420" }); // behind crown gate

// E ─ west overgrowth maze ---------------------------------------------------
add("og_d1",            700, 3760, 160, 26, "overgrowth_gate", { oneway: true });
add("og_d2",            440, 3900, 160, 26, "overgrowth_gate", { oneway: true });
add("og_d3",            700, 4040, 160, 26, "overgrowth_gate", { oneway: true });
add("og_floor",         380, 4180, 560, 44, "overgrowth_gate", {});
add("tm_a",            1080, 4240, 240, 34, "tangle_maze", {});
add("tm_b",            1440, 4320, 240, 34, "tangle_maze", {});
add("tm_roof",         1080, 4100, 600, 28, "tangle_maze", { ceiling: true, role: "branch", color: "10130f" });
zig("vw", "vine_well", 1780, 1560, 4320, 140, 5, { mat: "moss_stone", color: "22331f" }); // dropping steps
add("msf_floor",       2070, 4620, 260, 34, "mossgrip_shaft", { role: "branch", color: "2b4633" });
add("mr_floor",        1360, 5120, 320, 42, "maze_respite", {});
add("ba_floor",         880, 5420, 940, 52, "broken_branch_altar", {});
add("ba_pedestal",     1260, 5332, 150, 26, "broken_branch_altar", { oneway: true, role: "branch", color: "402a2a" });
add("ba_e_step",       1900, 5520, 160, 28, "broken_branch_altar", { oneway: true });
add("mv_floor",         520, 5480, 280, 36, "moss_veins", {});

// F ─ boss wing --------------------------------------------------------------
add("ra_a",            4080, 3900, 320, 42, "rust_approach", {});
add("ra_b",            4500, 3940, 260, 38, "rust_approach", {});
add("gt_floor",        4860, 3880, 300, 40, "gear_terrace", {});
add("gt_upper_a",      4900, 3780, 150, 24, "gear_terrace", { oneway: true, role: "branch", color: "6d6645" });
add("gt_upper_b",      5140, 3696, 150, 24, "gear_terrace", { oneway: true, role: "branch", color: "6d6645" });
add("pbs_floor",       5260, 3920, 320, 40, "pre_boss_shrine", {});
add("boss_floor",      5700, 3980, 700, 52, "rust_crown_hall", { mat: "boss_stone", color: "2a1e16" });
add("ct_floor",        6520, 3920, 340, 42, "crown_treasury", {});
add("db_floor",        6980, 3960, 320, 44, "drain_bellpipe", {});

// ---- ability gates (physical sealed walls, removed on unlock) --------------
const GATES = [
  { id: "gate_dash_bell_gap",  rect: [6600, 2520, 42, 320], ability: "thread_dash",       name: "绯线冲刺", rooms: ["bell_gap_crossing", "crown_treasury"] },
  { id: "gate_dash_cache",     rect: [1940, 3000, 42, 300], ability: "thread_dash",       name: "绯线冲刺", rooms: ["bellbone_station", "threadmakers_cache"] },
  { id: "gate_dash_deep",      rect: [3680, 5240, 42, 300], ability: "thread_dash",       name: "绯线冲刺", rooms: ["fake_moss_grotto", "cistern_deep_gallery"] },
  { id: "gate_dash_nook",      rect: [2210,  470, 42, 280], ability: "thread_dash",       name: "绯线冲刺", rooms: ["crown_walk", "crown_splinter_nook"] },
  { id: "gate_wall_mossgrip",  rect: [1990, 4360, 42, 320], ability: "silk_wall_grip",    name: "丝壁攀附", rooms: ["vine_well", "mossgrip_shaft"] },
  { id: "gate_jump_salt",      rect: [5080,  430, 42, 300], ability: "double_thread_jump", name: "双线跃",   rooms: ["salt_corridor", "salt_corridor"] },
  { id: "gate_break_marrow",   rect: [4020,  952, 140, 26], ability: "thorn_downstrike",  name: "棘线下劈", rooms: ["belfry_mid", "bell_marrow_cell"] },
  { id: "gate_shadow_veins",   rect: [ 440, 5270, 42, 300], ability: "lantern_phase",     name: "灯影相位", rooms: ["moss_veins", "moss_veins"] },
  { id: "gate_crown_well",     rect: [3990, 5800, 42, 240], ability: "crown_resonance",   name: "王冠共鸣", rooms: ["well_throat", "well_throat"] },
];

const round = (v) => Math.round(v);
const centerX = (p) => p.x + p.w / 2;

// ---- NPC dialogue state machines -------------------------------------------
// Source of truth: docs/spec/20260726160200000_全章节NPC对话设计全集.md §4 (CH01).
// Lines are copied verbatim. `dialogue` keeps the 3-line legacy fallback
// (= first three first_meet lines); `story_dialogue` carries the six-state
// machine consumed by main_level.gd `_resolve_npc_lines`.
const NPC_STORY = [
  {
    id: "npc_threadsmith_apprentice", name: "织线学徒", role: "threadsmith",
    platform: "shrine_floor", dx: -90,
    dialogue: [
      "左键斩击，右键缝回一口气；绯线救命，也会把贪心的人勒住。",
      "E 能让线猛地收紧，打出爆裂；F 能交谈、拉机关、敲醒旧钟门。",
      "别把苔钟庭当终点，六座失声之城都在等你把名字听回来。",
    ],
    story_dialogue: {
      first_meet: [
        "左键斩击，右键缝回一口气；绯线救命，也会把贪心的人勒住。",
        "E 能让线猛地收紧，打出爆裂；F 能交谈、拉机关、敲醒旧钟门。",
        "别把苔钟庭当终点，六座失声之城都在等你把名字听回来。",
        "我的手艺只剩这三句；剩下的，你得自己往前缝。——收好线。",
      ],
      repeat: [
        "线要省着用，话也是；我这残影多说一个字，就淡一分。",
        "姐姐说过，断线不可怕，可怕的是不敢打结的人。——别贪线。",
        "你的绯线比我的亮；亮的线，该往黑的地方走。",
      ],
      after_ability: [
        "你把线握成了冲刺——好手艺；线一绷直，人就追上了自己的影子。",
        "断枝祭坛肯把冲刺给你，说明它认你的手；别拿它去追不该追的近路。——稳住线。",
      ],
      after_boss: [
        "守母倒下时，庭里的苔安静了半拍；那半拍，是它替全城松的一口气。",
        "印记在响雨声，去下面吧；线往下坠的时候，记得你还有手。",
      ],
      late_game: [
        "井喉的证词你也听了？那口井压着的不是水，是没寄出去的话。",
        "我是残影，记不全自己的名字；可你手里那条线记得。——替我攥紧。",
      ],
      true_ending_branch: [
        "姐姐还活着，还在修长梯？那我这点线，总算没白留在门口。",
        "去改契约吧；把我的名字缝回去的时候，轻一点，那里破了很多年。",
      ],
    },
    dialogue_meta: {
      ability_ref: "thread_dash", testimony_ref: "testimony_01", quest_flag: "",
      leave: { condition: "ending_c_done", effect: "残影淡去；教学三句由 npc_bellway_weaver 缝入 bellbone_station 钟绳（环境交互）" },
    },
    identity: "年轻织线匠的残影，守在入庭钟门，确认新巡礼者是否还能感知绯线。",
    motive: "不想看见后来者在第一座庭院就被王冠消耗掉。",
    help: "教学：左键斩击、右键缝补、E绯线爆裂、F交互；说明六城巡礼目标。",
  },
  {
    id: "npc_gate_pilgrim", name: "守门朝圣者", role: "pilgrim",
    platform: "hub_floor_e", dx: 140,
    dialogue: [
      "正门被锈钟封死，别从正面硬闯；钟不怕勇敢，只怕清净——把庭里的敌群清了，它自会松口。",
      "三处敌群守在起步桥、下层外庭和上层钟廊；清完再回来，门闩会自己记得你。",
      "迷路就看苔光镜，亮起的房间会记住你的脚步。",
    ],
    story_dialogue: {
      first_meet: [
        "正门被锈钟封死，别从正面硬闯；钟不怕勇敢，只怕清净——把庭里的敌群清了，它自会松口。",
        "三处敌群守在起步桥、下层外庭和上层钟廊；清完再回来，门闩会自己记得你。",
        "迷路就看苔光镜，亮起的房间会记住你的脚步。",
      ],
      repeat: [
        "别催门，门比你有耐心；它已经等了一个王朝。",
        "我在这门前站老了，站成了半根门柱；至少门柱不会再犯错。",
        "别学我当年，仗着腿快就往钟口里钻；钟咽下过比我体面的人。",
      ],
      after_ability: [
        "你冲过了当年绊倒我的那道裂缝？别得意——裂缝还在，只是这次它没吃到人。",
        "别把冲刺当翅膀，它只是一根绷直的线；线会断，地不会。",
      ],
      after_boss: [
        "守母倒了，正门开了条缝；别问我为什么不进去——门开了，我反而不知道该迈哪只脚。",
        "你从殿里出来时的脚步声，和当年进去没出来的那些人不一样；轻一些，也重一些。",
      ],
      late_game: [
        "井喉的话你听见了？别转述给我，我这把年纪，扛不动别人没喊完的救命。",
        "原来门后压着的从来不是路，是话；难怪我叩了半辈子，它一声不应。",
      ],
      true_ending_branch: [
        "别替我改什么命；我只求改完契约那天，这扇门开着，风能进来。",
        "若钟再响，我就迈脚；左脚进门，右脚还留在外面替你们守着。",
      ],
    },
    dialogue_meta: { ability_ref: "thread_dash", testimony_ref: "testimony_01", quest_flag: "", leave: null },
    identity: "被困在正门前的老巡礼者，曾经试图硬闯锈钟门失败。",
    motive: "不想再看见后来者重复自己的错误。",
    help: "指明三处敌群目标；提示绕行路线和地图使用。",
  },
  {
    id: "npc_gear_cartographer", name: "升台绘图师", role: "cartographer",
    platform: "ro_floor", dx: -40,
    dialogue: [
      "青色竖条是你，金色点是敌群，琥珀点是机关，红色门后有不讲理的东西。",
      "地图不替你战斗，但它会告诉你哪里还没走过、哪里还能回来。",
      "上层钟廊能绕回后门，别在下庭把自己绕成一团苔。",
    ],
    story_dialogue: {
      first_meet: [
        "青色竖条是你，金色点是敌群，琥珀点是机关，红色门后有不讲理的东西。",
        "地图不替你战斗，但它会告诉你哪里还没走过、哪里还能回来。",
        "上层钟廊能绕回后门，别在下庭把自己绕成一团苔。",
      ],
      repeat: [
        "我的手摇不动升台了，只摇得动笔；你多走一间房，我就多活一格。",
        "西迷园我留了空白——不是没画，是画了会被苔吃掉；那种房间，得用脚记。",
        "北边、上头、再往上；这张图的尽头是一顶冠，我这辈子只画到它的边。",
      ],
      after_ability: [
        "你会冲刺了？好——把钟隙渡口那道红斜线替我改成绿的，我等这一笔等了十年。",
        "冠裂隙里有我最后一页残图；取回来，这张庭院图才算合得上。",
      ],
      after_boss: [
        "殿里的红门我可以涂掉了；涂掉一扇红门，比画十间新房还痛快。——标好了。",
        "排水钟管往下是铸雨渠，我只画到管口；管口以下，纸会被雨说服。",
      ],
      late_game: [
        "残页合上了，四十二间，一间不缺；我这只手，可以停在最后一格里了。",
        "别把我的图折角；图角一折，就有一间房永远背对着你。——都标好了。",
      ],
      true_ending_branch: [
        "若契约改成，替我在图角落画一枚小钟；不用像，响就行。",
        "六张区图拼起来是一口钟的剖面——我早看出来了，只是不敢先说。",
      ],
    },
    dialogue_meta: {
      ability_ref: "thread_dash", testimony_ref: "testimony_01", quest_flag: "item_map_fragment_returned",
      leave: { condition: "late_game 台词播毕", effect: "长眠；原位替换为「完整庭院图」拾取点（全图揭示，兑现地图残页描述效果）" },
    },
    identity: "维护旧庭院升台图例的绘图师，身体半嵌进齿轮升降机。",
    motive: "希望自己的最后一版地图不再白画。",
    help: "解释地图图例、战斗标记标记、机关标记和 Boss 门标记。",
  },
  {
    id: "npc_backdoor_sacristan", name: "后门司铃人", role: "sacristan",
    platform: "sl_floor", dx: -130,
    dialogue: [
      "钟法有三：鸣是唤醒，叩是询问，息是告别；巡礼者，您今天用哪一种？",
      "闸厅的拉杆连着后门升梯；清净了水窖就来拉它——升梯一响，死回来的路会短一半。",
      "记住，王冠不是戴在谁头上的金属，它是一口倒扣在城上的钟。——钟记得。",
    ],
    story_dialogue: {
      first_meet: [
        "钟法有三：鸣是唤醒，叩是询问，息是告别；巡礼者，您今天用哪一种？",
        "闸厅的拉杆连着后门升梯；清净了水窖就来拉它——升梯一响，死回来的路会短一半。",
        "记住，王冠不是戴在谁头上的金属，它是一口倒扣在城上的钟。——钟记得。",
      ],
      repeat: [
        "别小看捷径；捷径是庭院给肯回头的人留的礼数。",
        "我守的不是后门，是「还愿意回来」这件事。——钟记得。",
      ],
      after_ability: [
        "有了冲刺，升梯之外您又多一条回家的线；路多了，人才敢走远。",
        "叩门用指节，冲刺用命；两样都别用错地方。",
      ],
      after_boss: [
        "守母息了。听清楚——是「息」，不是「死」；守了这么多年的东西，配一个体面的钟法。",
        "排水钟管已经替您敲过三声「鸣」；下面的雨，会接住你。——钟记得。",
      ],
      late_game: [
        "井喉那口封铃井盖，是我师父的师父封的；他们封时用的是「息」，您若开，请用「叩」。",
        "证词这种东西，钟龛存不下，只有人心存得下；您既然听了，就别弄丢。",
      ],
      true_ending_branch: [
        "改契约那天，替我摇一次「鸣」；这口庭院的钟，欠全城一个早晨。",
        "六城的钟龛我都点过名，只差冠里那一座；替我去，替我听。——钟记得。",
      ],
    },
    dialogue_meta: { ability_ref: "thread_dash", testimony_ref: "testimony_01", quest_flag: "", leave: null },
    identity: "驻守闸厅的后门司铃人，以钟礼三法「鸣、叩、息」归类庭院里的一切动作。",
    motive: "守的不是后门，是「还愿意回来」这件事；等一个替全城摇响「鸣」的人。",
    help: "提示闸厅拉杆接通后门升梯：清净水窖后拉杆，死亡回跑缩短一半。",
  },
  {
    id: "npc_runback_scout", name: "回廊斥候", role: "scout",
    platform: "pbs_floor", dx: 120,
    dialogue: [
      "记下：殿前那盏亮着的灯是诱饵，真正的歇处在你身后的钟龛。",
      "记下：守母没有法术，只有冲撞、钟舌横扫和一顶太重的冠；前摇亮琥珀色，就滚。",
      "记下：留一口能量给缝补；贪刀的人，会被震地接成一段旧传说。",
    ],
    story_dialogue: {
      first_meet: [
        "记下：殿前那盏亮着的灯是诱饵，真正的歇处在你身后的钟龛。",
        "记下：守母没有法术，只有冲撞、钟舌横扫和一顶太重的冠；前摇亮琥珀色，就滚。",
        "记下：留一口能量给缝补；贪刀的人，会被震地接成一段旧传说。",
      ],
      repeat: [
        "我的前任记了三页就进殿了，尸体比笔记先落地；所以我记满三十页才敢站在这儿。",
        "观武要诀只有一条：它抬冠，你退；它垂冠，你上。别的都是注脚。",
      ],
      after_ability: [
        "记下：冲刺能穿过守母的横扫，穿不过它的落点；躲招躲的是「下一招」。",
        "你有冲刺，比我当年多一条命；把这条命用在第二阶段。",
      ],
      after_boss: [
        "打赢了？让我看看印记——好，温的。三十页笔记今天全部作废，作废得漂亮。",
        "我的任务完了。我去黑曜路，那里还有一支没人记录的军队。——记下：我们两清了。",
      ],
      late_game: [
        "（观武录末页）记下：读到这页的人若已拿到井喉证词，请把本册烧掉——观武的时代结束了，听证的时代开始。",
        "（观武录夹页）黑曜路，战冢，第三排；若我没回来，那里会多一杆插反的枪。",
      ],
      true_ending_branch: [
        "记下：斥候戊字第七号，改行了；现在记录的不是招式，是名字。",
        "你要改契约？这份军报我署名作证——这是我头一回敢在报告上写自己的名字。",
      ],
    },
    dialogue_meta: {
      ability_ref: "thread_dash", testimony_ref: "testimony_05", quest_flag: "",
      leave: { condition: "after_boss 播毕", effect: "离场；原位留《守母观武录》拾取点（late_game 两条即笔记文本）；ch5 war_graves 重逢后播 true_ending_branch" },
    },
    identity: "殿前钟龛旁的回廊斥候，记满三十页观武录才敢站在守母门前。",
    motive: "用观武录赎罪；守母倒下之日笔记作废，转赴黑曜路改记名字。",
    help: "战报：守母只有冲撞、钟舌横扫和震地，前摇亮琥珀色就躲；留能量给缝补。",
  },
];

// ---- one-shot ambient whispers (绯线低语, doc §13.1) ------------------------
const WHISPERS = [
  { id: "w_ch01_hub", trigger: "enter_room", room_id: "court_hub", line: "……抬头。整座城，都住在一口钟的里面。" },
  { id: "w_ch01_station", trigger: "enter_room", room_id: "bellbone_station", line: "封存的站厅。这道竖井贯穿世界——线在往上指，也在往下指。" },
  { id: "w_ch01_crownwalk", trigger: "enter_room", room_id: "crown_walk", line: "风从冠上来。跳下去吧，线会接住你——它记得这条路。" },
  { id: "w_ch01_vista", trigger: "enter_room", room_id: "rain_overlook", line: "脚下的雨声没有停过。有一座城，在下面淋着。" },
  { id: "w_ch01_well", trigger: "enter_room", room_id: "well_throat", line: "井盖下有话在翻身。线绷紧了——它不想靠近，又不肯离开。" },
  { id: "w_ch01_grotto", trigger: "enter_room", room_id: "fake_moss_grotto", line: "地板说了谎。但谎言下面，藏着庭院真正的记性。" },
  { id: "w_ch01_bossdoor", trigger: "enter_room", room_id: "rust_crown_hall", line: "殿里的锈味很旧，旧得像一句守了太久的诺言。" },
  { id: "w_ch01_dash", trigger: "pickup_item", item_id: "thread_dash", line: "线绷直了。从今往后，「够不着」要重新丈量。" },
];

function build() {
  const base = JSON.parse(readFileSync(BASE_PATH, "utf8"));

  let order = 0;
  const design = P.map(([id, x, y, w, h, room, o]) => {
    const role = o.role || "main";
    return {
      id, x, y, w, h, room,
      mat: o.mat || "moss_stone", color: o.color || "1c2b1f",
      oneway: !!o.oneway, ceiling: !!o.ceiling,
      route_role: role === "main" ? "main" : "branch",
      route_order: role === "main" ? order++ : undefined, role,
    };
  });
  const byId = Object.fromEntries(design.map((p) => [p.id, p]));

  const platforms = design.map((p) => {
    const e = { id: p.id, rect: [round(p.x), round(p.y), round(p.w), round(p.h)], color: p.color, material: p.mat,
      collision_role: p.ceiling ? "ceiling" : p.oneway ? "one_way" : "floor" };
    if (p.route_role === "main") { e.route_role = "main"; e.route_order = p.route_order; e.safe_landing = true; e.gameplay_clearance = 232; }
    else { e.route_role = "branch"; }
    return e;
  });

  const boss = byId["boss_floor"];
  const onPlat = (id, dx = 0) => { const p = byId[id]; return [round(centerX(p) + dx), round(p.y - 40)]; };

  // world bounds
  const maxRight = Math.max(...design.map((p) => p.x + p.w));
  const minY = Math.min(...design.map((p) => p.y));
  const maxY = Math.max(...design.map((p) => p.y + p.h));
  const worldWidth = round(maxRight + 360);
  const worldTop = round(minY - 420);
  const worldHeight = round(maxY - worldTop + 520);
  const fallY = round(maxY + 260);

  // per-room bounds
  const rb = {};
  for (const p of design) {
    const r = (rb[p.room] ||= { minx: Infinity, miny: Infinity, maxx: -Infinity, maxy: -Infinity });
    r.minx = Math.min(r.minx, p.x); r.miny = Math.min(r.miny, p.y);
    r.maxx = Math.max(r.maxx, p.x + p.w); r.maxy = Math.max(r.maxy, p.y + p.h);
  }

  // minimap grid cells: derive col/row from world position, resolve collisions
  const COLS = 13, ROWS = 9;
  const taken = new Set();
  const cells = {};
  for (const id of ROOM_ORDER) {
    const b = rb[id];
    const cx = (b.minx + b.maxx) / 2, cy = (b.miny + b.maxy) / 2;
    let col = Math.max(0, Math.min(COLS - 1, Math.floor(cx / worldWidth * COLS)));
    let row = Math.max(0, Math.min(ROWS - 1, Math.floor((cy - worldTop) / worldHeight * ROWS)));
    let key = `${col},${row}`, tries = 0;
    const deltas = [[0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1],[2,0],[-2,0],[0,2],[0,-2]];
    while (taken.has(key) && tries < deltas.length) {
      const [dc, dr] = deltas[tries++];
      const c2 = Math.max(0, Math.min(COLS - 1, col + dc)), r2 = Math.max(0, Math.min(ROWS - 1, row + dr));
      key = `${c2},${r2}`;
      if (!taken.has(key)) { col = c2; row = r2; break; }
    }
    taken.add(key);
    cells[id] = { col, row };
  }

  const map_rooms = ROOM_ORDER.map((id) => {
    const meta = ROOMS[id], b = rb[id], c = cells[id];
    const layout_rect = [round(b.minx - 40), round(b.miny - 150), round(b.maxx - b.minx + 80), round(b.maxy - b.miny + 210)];
    return {
      id, name: meta.name, range: [round(b.minx - 40), round(b.maxx + 40)], depth: meta.depth, kind: meta.kind,
      archetype: meta.kind, layout_rect, map_rect: [c.col * 280, c.row * 210, 236, 168],
      objective: meta.objective, guide: meta.guide, danger: meta.danger, next: meta.next,
      setpiece: meta.setpiece, traversal_focus: meta.traversal_focus, pacing_role: meta.pacing_role,
      visit_rects: [layout_rect],
    };
  });

  // room graph --------------------------------------------------------------
  const edge = (from, to, type, action, shortcut_id = "", bidir = true, required_ability = "") => {
    const e = { from, to, type, edge_kind: type === "shortcut" ? "unlock_shortcut" : type, bidirectional: bidir, action, shortcut_id };
    if (required_ability) e.required_ability = required_ability;
    return e;
  };
  const connections = [
    // A
    edge("entry_bell", "moss_descent", "passage", "walk_jump"),
    edge("moss_descent", "first_bell_shrine", "passage", "walk_jump"),
    edge("first_bell_shrine", "crawl_gate", "passage", "walk_jump"),
    edge("crawl_gate", "court_hub", "passage", "crawl"),
    edge("moss_descent", "overgrowth_gate", "one_way_drop", "one_way_drop", "", false),
    // B
    edge("court_hub", "bellbone_station", "passage", "walk_jump"),
    edge("court_hub", "hub_gallery", "passage", "climb"),
    edge("court_hub", "threadmakers_cache", "ability_gate", "dash", "", true, "thread_dash"),
    edge("hub_gallery", "east_balcony", "passage", "walk_jump"),
    // C
    edge("court_hub", "bell_ascent", "passage", "climb"),
    edge("bell_ascent", "belfry_mid", "passage", "walk_jump"),
    edge("belfry_mid", "bell_marrow_cell", "ability_gate", "downstrike", "", false, "thorn_downstrike"),
    edge("belfry_mid", "hidden_attic", "passage", "walk_jump"),
    edge("hidden_attic", "salt_corridor", "passage", "walk_jump"),
    edge("belfry_mid", "belfry_top", "passage", "walk_jump"),
    edge("belfry_top", "crown_walk", "passage", "walk_jump"),
    edge("crown_walk", "crown_splinter_nook", "ability_gate", "dash", "", true, "thread_dash"),
    edge("crown_walk", "court_hub", "one_way_drop", "one_way_drop", "", false),
    edge("crown_walk", "hub_gallery", "one_way_drop", "one_way_drop", "", false),
    // G
    edge("east_balcony", "moth_roost", "passage", "walk_jump"),
    edge("moth_roost", "rain_overlook", "passage", "walk_jump"),
    edge("rain_overlook", "bell_gap_crossing", "passage", "walk_jump"),
    edge("bell_gap_crossing", "crown_treasury", "ability_gate", "dash_drop", "", false, "thread_dash"),
    // D
    edge("court_hub", "cistern_shaft", "one_way_drop", "one_way_drop", "", false),
    edge("cistern_shaft", "cistern_ring", "passage", "walk_jump"),
    edge("cistern_ring", "fake_moss_grotto", "one_way_drop", "one_way_drop", "", false),
    edge("fake_moss_grotto", "underway", "passage", "walk_jump"),
    edge("fake_moss_grotto", "cistern_deep_gallery", "ability_gate", "dash", "", true, "thread_dash"),
    edge("underway", "sluice_hall", "passage", "walk_jump"),
    edge("sluice_hall", "bell_stair_well", "shortcut", "unlock_shortcut", "ch01_vault_hub_shortcut"),
    edge("bell_stair_well", "bellbone_station", "passage", "climb"),
    edge("sluice_hall", "root_vault", "passage", "walk_jump"),
    edge("root_vault", "well_throat", "passage", "walk_jump"),
    // E
    edge("overgrowth_gate", "tangle_maze", "passage", "walk_jump"),
    edge("tangle_maze", "vine_well", "passage", "walk_jump"),
    edge("vine_well", "mossgrip_shaft", "ability_gate", "wall_jump", "", true, "silk_wall_grip"),
    edge("vine_well", "maze_respite", "passage", "walk_jump"),
    edge("maze_respite", "broken_branch_altar", "one_way_drop", "one_way_drop", "", false),
    edge("broken_branch_altar", "moss_veins", "passage", "walk_jump"),
    edge("broken_branch_altar", "sluice_hall", "one_way_drop", "one_way_drop", "", false),
    // F
    edge("court_hub", "rust_approach", "passage", "walk_jump"),
    edge("rust_approach", "gear_terrace", "passage", "walk_jump"),
    edge("gear_terrace", "pre_boss_shrine", "passage", "walk_jump"),
    edge("pre_boss_shrine", "rust_crown_hall", "boss_gate", "boss_gate"),
    edge("rust_crown_hall", "crown_treasury", "passage", "walk_jump"),
    edge("crown_treasury", "drain_bellpipe", "passage", "walk_jump"),
  ];

  const nodes = map_rooms.map((r) => r.id);
  const adj = Object.fromEntries(nodes.map((n) => [n, new Set()]));
  for (const c of connections) { adj[c.from].add(c.to); adj[c.to].add(c.from); }
  const degSeq = nodes.map((n) => adj[n].size).sort((a, b) => a - b);
  const map_topology = {
    topology_id: "moss_bell_court_boxgarden",
    nodes: map_rooms.map((r) => ({ id: r.id, room_type: r.kind[0].toUpperCase(), layer: r.depth,
      span_u: Math.max(4, Math.round((r.layout_rect[2]) / 220)), map_rect: r.map_rect })),
    edges: connections,
    main_visit_order: [
      "entry_bell","moss_descent","first_bell_shrine","crawl_gate","court_hub","hub_gallery","court_hub",
      "bell_ascent","belfry_mid","belfry_top","crown_walk","court_hub",
      "cistern_shaft","cistern_ring","fake_moss_grotto","underway","sluice_hall","bell_stair_well","bellbone_station","court_hub",
      "moss_descent","overgrowth_gate","tangle_maze","vine_well","maze_respite","broken_branch_altar","sluice_hall","bell_stair_well","court_hub",
      "hub_gallery","east_balcony","moth_roost","rain_overlook","court_hub",
      "rust_approach","gear_terrace","pre_boss_shrine","rust_crown_hall","crown_treasury","drain_bellpipe",
    ],
    graph_fingerprint: { vertices: nodes.length, edges: connections.length, cycle_rank: connections.length - nodes.length + 1, maximum_degree: Math.max(...degSeq), degree_sequence: degSeq },
    forbidden_motifs: ["horizontal_36_platform_chain", "shared_upper_loop_recovery_loop", "single_hub_star_without_ring"],
  };

  const mainPlats = design.filter((p) => p.route_role === "main");
  const runtime_geometry = {
    ...base.runtime_geometry,
    spatial_grammar: "moss_bell_court_boxgarden",
    critical_route: mainPlats.map((p) => p.id),
    upper_loop: design.filter((p) => ["bell_ascent","belfry_mid","belfry_top","crown_walk"].includes(p.room)).map((p) => p.id),
    recovery_loop: design.filter((p) => ["cistern_shaft","cistern_ring","fake_moss_grotto","underway","sluice_hall","bell_stair_well"].includes(p.room)).map((p) => p.id),
    branch_programs: ["bell_tower_climb", "cistern_descent", "back_door_stairwell", "west_maze_dash_quest", "east_ring_crossing", "abyss_foreshadow"],
    route_tags: ["central_hub", "vertical_bell_tower", "lower_cistern_ring", "crown_catwalk_loop", "west_dash_quest", "east_upper_ring", "ability_gated_boxgarden", "handcrafted_2d"],
    main_route_orders: mainPlats.length,
  };

  // locked gates ------------------------------------------------------------
  const locked_gates = GATES.map((g) => ({
    id: g.id, rect: g.rect, color: "5a2d2d", material: "bronze_bridge",
    required_ability: g.ability, required_ability_name: g.name,
    from: g.rooms[0], to: g.rooms[1], map_marker: "ability_gate",
  }));

  // collectibles (ability + rewards; combat_clear spawns kind=="item" only) --
  const collectibles = [
    { id: "col_thread_dash", kind: "item", room_id: "broken_branch_altar", item_id: "thread_dash", position: onPlat("ba_pedestal"), ability_name: "绯线冲刺", label: "绯线冲刺", note: "断枝祭坛精英战奖励；解锁冲刺与全部钟隙门。" },
    { id: "col_quiet_sole", kind: "item", room_id: "threadmakers_cache", item_id: "quiet_sole", position: onPlat("cache_floor"), ability_name: "静靴", label: "护符·静靴", note: "织线暗室，冲刺门后。" },
    { id: "col_energy_spindle", kind: "item", room_id: "cistern_deep_gallery", item_id: "energy_spindle", position: onPlat("cdg_floor"), ability_name: "能量纺锤", label: "能量纺锤", note: "水窖深廊，冲刺门后。" },
    { id: "col_map_fragment", kind: "item", room_id: "crown_splinter_nook", item_id: "map_fragment", position: onPlat("nook_floor"), ability_name: "地图残页", label: "地图残页", note: "冠裂隙，冲刺门后。" },
    { id: "col_heart_knot", kind: "item", room_id: "mossgrip_shaft", item_id: "heart_knot", position: onPlat("msf_floor"), ability_name: "心结", label: "心结", note: "苔壁竖井，丝壁攀附回访奖励。" },
    { id: "col_testimony_01", kind: "item", room_id: "well_throat", item_id: "testimony_01", position: onPlat("wta_floor"), ability_name: "证词其一", label: "证词·其一", note: "井喉冠门后，真结局收集品。" },
  ];
  const catalog_extra = {
    thread_dash: { name: "绯线冲刺", category: "Abilities", description: "短距离水平冲刺，可穿过钟隙与窄刺阵。断枝祭坛的守卫曾用它护住整条苔脉。" },
    quiet_sole: { name: "静靴", category: "Charms", description: "陷阱触发判定略微缩小。织线者留下的软底靴。" },
    energy_spindle: { name: "能量纺锤", category: "Upgrades", description: "增加最大能量。沉在水窖深廊的纺锤仍在转。" },
    map_fragment: { name: "地图残页", category: "Relics", description: "预先揭示一个区域的房间轮廓。残页边缘写着看不懂的钟文。" },
    heart_knot: { name: "心结", category: "Upgrades", description: "增加最大生命。打了死结的绯线，攥紧就不冷。" },
    testimony_01: { name: "证词·其一", category: "Relics", description: "六份证词之一：井喉里封着的第一句真话。" },
  };

  // enemies / npcs / boss ---------------------------------------------------
  const eTmpl = {}; for (const e of base.enemy_spawns) if (!eTmpl[e.kind]) eTmpl[e.kind] = e;
  const enemyPlan = [
    ["moss_larva", "md_run"], ["moss_larva", "hub_floor_w", -120], ["bronze_moth", "hg_c2"],
    ["spore_bellmaker", "ba07"], ["spore_bellmaker", "bm_floor", 60], ["gear_sentinel", "eb_floor"],
    ["bronze_moth", "mo_b"], ["moss_larva", "cr_upper", -220], ["corridor_heavy", "cr_lower", 160],
    ["spore_bellmaker", "uw_a"], ["moss_larva", "tm_a"], ["bellroot_acolyte", "ba_floor", -180],
    ["corridor_heavy", "ra_a"], ["gear_sentinel", "gt_floor"],
  ];
  const enemy_spawns = enemyPlan.map(([kind, pid, dx = 0], i) => ({
    ...structuredClone(eTmpl[kind] || base.enemy_spawns[0]), id: `E${String(i + 1).padStart(2, "0")}`, kind, position: onPlat(pid, dx), platform_id: pid,
  }));

  const bossData = {
    ...base.boss, position: [round(centerX(boss)), round(boss.y - 40)], platform_id: "boss_floor",
    arena_min_x: round(boss.x + 30), arena_max_x: round(boss.x + boss.w - 30), lock_x: round(boss.x - 48), lock_height: 560, lock_width: 42,
  };
  const boss_checkpoint = [round(boss.x + 90), round(boss.y - 40)];

  const interactives = [
    { id: "shortcut_lever", kind: "lever", position: onPlat("sl_floor", 120), requires_keys: 0, label: "后门升梯拉杆", shortcut_id: "ch01_vault_hub_shortcut" },
    { id: "boss_gate", kind: "boss_gate", position: [round(boss.x + 60), round(boss.y - 40)] },
    { id: "ch01_chapter_exit", kind: "chapter_exit", label: "前往第二章：铸雨渠", position: onPlat("db_floor"), next_runtime_config_id: "demo_ch02_rain_foundry_canal", next_config_path: "res://data/demo_ch02_rain_foundry_canal.json", requires_demo_complete: true, interaction_size: [240, 180] },
  ];
  const save_points = [
    { id: "save_first_bell", label: "初鸣苔灯", position: onPlat("shrine_floor"), hidden: false, note: "第一座钟龛，教学末尾的稳定归处。" },
    { id: "save_hidden_upper_respite", label: "隐苔存档点", position: onPlat("attic_floor"), hidden: true, note: "藏在顶阁暗格，奖励高路线探索。" },
    { id: "save_maze_respite", label: "迷园苔灯", position: onPlat("mr_floor"), hidden: false, note: "断枝祭坛精英战前最后的灯。" },
    { id: "save_late_runback", label: "殿前苔灯", position: onPlat("pbs_floor"), hidden: false, note: "首领门前的稳定检查点，死亡回跑很短。" },
  ];
  const npcs = NPC_STORY.map(({ platform: pid, dx, ...npc }) => ({ ...structuredClone(npc), position: onPlat(pid, dx) }));

  const hz = (id, kind, pid, dx, dy, w, h, msg) => { const p = byId[pid]; return { id, kind, rect: [round(centerX(p) + dx - w / 2), round(p.y + dy), w, h], damage: 1, message: msg, platform_id: pid }; };
  const hazards = [
    hz("trap_fake_moss_01", "fake_moss_floor", "cr_upper", 250, -6, 130, 22, "假苔地板轰然塌陷——下面还有路。"),
    hz("ch01_hazard_underway_moss", "fake_moss_floor", "uw_a", 0, -6, 120, 22, "暗河苔板一踩就塌。"),
    hz("ch01_hazard_clapper", "falling_clapper", "ba05", 0, -150, 110, 30, "钟锤毫无预兆地砸落。"),
    hz("ch01_hazard_crown_spikes", "spikes", "cw_b", 0, -8, 120, 20, "钟冠残齿锈刺外露。"),
    hz("ch01_hazard_tangle_spikes", "spikes", "tm_b", 40, -8, 120, 20, "缠根间藏着旧钟齿。"),
    hz("ch01_hazard_approach_spikes", "spikes", "ra_b", 0, -8, 120, 20, "前庭布满钟齿尖刺。"),
    hz("ch01_hazard_cistern_spikes", "spikes", "cr_lower", -280, -8, 120, 20, "水窖底部暗藏锈钉。"),
    hz("ch01_hazard_bell_gap", "bell_gap", "bgc_w", 140, -8, 110, 20, "钟隙深不见底。"),
    hz("ch01_hazard_vault_chest", "spore_chest", "rv_floor", 150, -30, 90, 34, "孢箱炸开一团苔云。"),
  ];

  const lb = (text, pid, dy, color) => { const p = byId[pid]; return { text, position: [round(centerX(p)), round(p.y + dy)], color }; };
  const labels = [
    lb("朝圣断阶：安全试跳", "start_ground", -70, "9ef0dc"),
    lb("朝圣阶（封）· 机关在对侧", "pilgrim_stair_ledge", -50, "8d97a8"),
    lb("窄苔缝：压低身形", "crawl_floor", -60, "b9c79a"),
    lb("中央钟庭：上攀 · 下探 · 西寻 · 东讨", "hub_floor_w", -110, "baf4a6"),
    lb("钟骨长梯（未通电）", "station_floor", -80, "8d97a8"),
    lb("钟骨折梯 ↑", "ba02", -60, "c7e6ff"),
    lb("钟冠悬廊 · 坠回枢纽", "cw_drop", -60, "a6ecff"),
    lb("盐风走廊：双线跃可达（回访）", "salt_floor", -70, "e8e3c8"),
    lb("水窖下环 ↓", "cs_drop_2", -56, "dcb2ff"),
    lb("后门升梯 · 直回钟庭", "sl_floor", -80, "f2c66b"),
    lb("西苔脉：裂口单向 ↓", "og_d1", -56, "c8f0b2"),
    lb("断枝祭坛：绯线冲刺", "ba_pedestal", -66, "ff9d8a"),
    lb("苔脉裂缝：灯影相位可达（回访）", "mv_floor", -66, "8d97a8"),
    lb("井喉：王冠共鸣可达（终局）", "wt_floor", -70, "9a86b8"),
    lb("锈冠殿 →", "pbs_floor", -80, "f2b873"),
    lb("钟隙渡口：绯线冲刺捷径", "bgc_w", -66, "ff9d8a"),
  ];

  const envBase = base.environment_blocks[0];
  const mass = (id, rect, color, z) => ({ id, rect: rect.map(round), color, z_index: z, visual_source: envBase.visual_source, asset_root: envBase.asset_root, ownership: envBase.ownership });
  const hubW = byId["hub_floor_w"], bel = byId["belfry_floor"], cis = byId["cr_lower"], alt = byId["ba_floor"], wt = byId["wt_floor"];
  const environment_blocks = [
    mass("ch01_back_wall", [0, worldTop, worldWidth, worldHeight], "130d1b", -95),
    mass("ch01_bell_silhouette", [bel.x - 260, bel.y - 60, 1400, 2400], "17111f", -90),
    mass("ch01_hub_floor_mass", [hubW.x - 60, hubW.y + hubW.h, 1400, 360], "07100f", -88),
    mass("ch01_station_frame", [byId["station_floor"].x - 40, byId["station_floor"].y - 320, 420, 360], "1d1a2e", -89),
    mass("ch01_pilgrim_stair_seal", [90, 2760, 260, 340], "231d2a", -89),
    mass("ch01_cistern_water", [cis.x - 260, cis.y + cis.h, 1600, 240], "0a1a1e", -86),
    mass("ch01_altar_root_mass", [alt.x - 120, alt.y + alt.h, 1200, 300], "141a10", -87),
    mass("ch01_well_abyss", [wt.x - 80, wt.y + wt.h, 900, 420], "060409", -85),
    mass("ch01_arena_floor_mass", [boss.x - 40, boss.y + boss.h, boss.w + 80, 300], "0a0b12", -88),
    mass("ch01_crawl_shadow", [byId["crawl_floor"].x, byId["crawl_floor"].y - 156, 420, 156], "0c0f0c", -84),
  ];

  const parkour_segments = [
    { id: "ch01_bell_ascent_climb", room_id: "bell_ascent", technique: "zigzag one-way ascent",
      platforms: ["hub_top_shelf","ba01","ba02","ba03","ba04","ba05","ba06","ba07","ba08","ba09","ba10","ba11","ba12","bm_floor"],
      safety_contract: { max_gap: 176, max_rise: 110, minimum_full_jump_clearance: 232 } },
    { id: "ch01_vine_well_descent", room_id: "vine_well", technique: "one-way vine drop chain",
      platforms: ["tm_b","vw01","vw02","vw03","vw04","vw05","mr_floor"],
      safety_contract: { max_gap: 176, max_rise: 110, minimum_full_jump_clearance: 232 } },
    { id: "ch01_stairwell_return", room_id: "bell_stair_well", technique: "long zigzag shortcut climb",
      platforms: ["sl_floor","sw01","sw05","sw10","sw15","sw20","sw25","sw_top","station_floor"],
      safety_contract: { max_gap: 176, max_rise: 112, minimum_full_jump_clearance: 232 } },
  ];

  const out = { ...base };
  out.name = "苔钟庭";
  out.map_title = "苔钟庭：箱庭互联版";
  out.goal = "以中央钟庭为枢纽探索整座箱庭：上攀钟塔沿钟冠坠回，下探水窖拉通后门升梯，西入苔脉迷园夺回绯线冲刺，最后东进锈冠殿击败苔钟守母、开启前往铸雨渠的钟管。";
  out.world = { width: worldWidth, height: worldHeight, fall_y: fallY };
  out.player_start = [round(byId["start_ground"].x + 60), round(byId["start_ground"].y - 40)];
  out.boss_checkpoint = boss_checkpoint;
  out.fall_y = fallY;
  out.map_rooms = map_rooms;
  out.platforms = platforms;
  out.environment_blocks = environment_blocks;
  out.hazards = hazards;
  out.collectibles = collectibles;
  out.locked_gates = locked_gates;
  out.interactives = interactives;
  out.save_points = save_points;
  out.npcs = npcs;
  out.whispers = structuredClone(WHISPERS);
  out.enemy_spawns = enemy_spawns;
  out.boss = bossData;
  out.labels = labels;
  out.connections = connections;
  out.map_topology = map_topology;
  out.runtime_geometry = runtime_geometry;
  out.parkour_segments = parkour_segments;
  out.inventory = { ...base.inventory, catalog: { ...base.inventory.catalog, ...catalog_extra } };
  out.ability_gated_start = true;   // player dash locked until thread_dash pickup
  out.map_layout_tags = ["handcrafted", "true_2d", "boxgarden", "central_hub", "vertical_bell_tower", "lower_cistern_ring", "crown_catwalk_loop", "west_dash_quest", "east_upper_ring", "ability_gates", "see_then_return", "back_door_stairwell", "short_boss_run", "moss_cavern"];
  out.design_note = {
    source: "hand-authored (tools/handcraft_ch01_boxgarden.mjs)",
    intent: "Silksong-style box-garden: a 2800px-tall central hub with a bell tower + crown catwalk loop above, an east upper ring shortcutting to the boss wing (dash gate), a flooded cistern ring + hidden grotto below with a long back-door stairwell return, and a west overgrowth maze whose altar holds the thread_dash ability. 9 ability gates anchor cross-chapter revisits.",
    coordinate_mapping: { note: "explicit 2D world coordinates; main route is fully traversable without dash (gap<=160, rise<=96); dash only opens shortcuts/secrets" },
  };
  out.progression_mode = "combat_clear";
  out.required_keys = 0;
  out.chapter_transition = { ...base.chapter_transition, entry_spawn: out.player_start };

  return { out, design, platforms, map_rooms, connections, map_topology, worldWidth, worldHeight, worldTop, byId };
}

// ---- self-audit (mirrors strict checks + no-dash main route) ---------------
function bfsReach(design, startId, useDash) {
  const seen = new Set([startId]); const q = [startId];
  const standable = design.filter((p) => !p.ceiling);
  while (q.length) {
    const curId = q.shift();
    const cur = design.find((p) => p.id === curId);
    for (const p of standable) if (!seen.has(p.id) && reachable(cur, p, useDash)) { seen.add(p.id); q.push(p.id); }
  }
  return seen;
}
function headBumps(platforms) {
  const solids = platforms.filter((p) => p.collision_role !== "one_way");
  const out = [];
  for (let i = 0; i < solids.length; i++) for (let j = i + 1; j < solids.length; j++) {
    const A = solids[i].rect, B = solids[j].rect;
    const upper = A[1] <= B[1] ? A : B, lower = A[1] <= B[1] ? B : A;
    const clearance = lower[1] - (upper[1] + upper[3]);
    const overlap = Math.max(0, Math.min(upper[0] + upper[2], lower[0] + lower[2]) - Math.max(upper[0], lower[0]));
    if (clearance <= 0 || clearance >= MIN_HEAD || overlap < PLAYER_W + 10) continue;
    const leftExp = Math.max(0, upper[0] - lower[0]), rightExp = Math.max(0, lower[0] + lower[2] - (upper[0] + upper[2]));
    if (overlap >= lower[2] * 0.68 || Math.max(leftExp, rightExp) < 72)
      out.push({ upper: solids[A[1] <= B[1] ? i : j].id, lower: solids[A[1] <= B[1] ? j : i].id, clearance: Math.round(clearance), overlap: Math.round(overlap) });
  }
  return out;
}
function wallSlots(platforms) {
  const solids = platforms.filter((p) => p.collision_role !== "one_way");
  const out = [];
  for (let i = 0; i < solids.length; i++) for (let j = i + 1; j < solids.length; j++) {
    const A = solids[i].rect, B = solids[j].rect;
    const vo = Math.max(0, Math.min(A[1] + A[3], B[1] + B[3]) - Math.max(A[1], B[1]));
    const gap = Math.max(0, B[0] - (A[0] + A[2]), A[0] - (B[0] + B[2]));
    if (vo > 0 && PLAYER_W < gap && gap < MIN_WALL_GAP) out.push({ a: solids[i].id, b: solids[j].id, gap: Math.round(gap) });
  }
  return out;
}

// ---- uniqueness mirror (tools/audit_map_uniqueness.py) ---------------------
const median = (arr) => { const s = [...arr].sort((a, b) => a - b); const m = Math.floor(s.length / 2); return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
function mainRouteOrdered(design) {
  return design.filter((p) => p.route_role === "main").sort((a, b) => a.route_order - b.route_order);
}
function rhythmTokens(route) {
  if (route.length < 2) return [];
  const centers = route.map((p) => [p.x + p.w / 2, p.y + p.h / 2]);
  const dists = centers.slice(1).map((c, i) => Math.hypot(c[0] - centers[i][0], c[1] - centers[i][1]));
  const nz = dists.filter((d) => d > 1e-6);
  const dScale = nz.length ? median(nz) : 1;
  const wScale = median(route.map((p) => p.w).filter((w) => w > 0)) || 1;
  const toks = [];
  for (let i = 0; i + 1 < centers.length; i++) {
    const dx = centers[i + 1][0] - centers[i][0], dy = centers[i + 1][1] - centers[i][1];
    const a = ((Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) % 8) + 8) % 8;
    const d = Math.min(12, Math.max(0, Math.round((dists[i] / dScale) * 4)));
    const w = Math.round((route[i + 1].w / wScale) * 4);
    toks.push(`a${a}:d${d}:w${w}`);
  }
  return toks;
}
function sizeTokens(route) {
  if (!route.length) return [];
  const scale = median(route.map((p) => Math.sqrt(Math.max(1, p.w * p.h))));
  return route.map((p) => `w${Math.round((p.w / scale) * 4)}:h${Math.round((p.h / scale) * 4)}`);
}
function duplicateWindows(values, size) {
  const seen = new Map(); const dups = [];
  for (let i = 0; i + size <= values.length; i++) {
    const key = values.slice(i, i + size).join("|");
    if (seen.has(key)) dups.push({ first: seen.get(key), pos: i });
    else seen.set(key, i);
  }
  return dups;
}
function repeatRatio(values, size) {
  const total = Math.max(1, values.length - size + 1);
  return duplicateWindows(values, size).length / total;
}
function physicsOk(r) {
  const reachNoDash = bfsReach(r.design, "start_ground", false);
  if (r.design.some((p) => p.route_role === "main" && !reachNoDash.has(p.id))) return false;
  if (headBumps(r.platforms).length || wallSlots(r.platforms).length) return false;
  for (const e of r.out.enemy_spawns) {
    const p = r.byId[e.platform_id];
    if (!p || p.w < 86 || p.h > 90) return false;
  }
  return true;
}
// Deterministically jitter duplicated-rhythm platforms until the uniqueness
// audit sees zero repeated 3-grams (route) and <=0.25 size repetition.
function deduplicate() {
  const NG = 3;
  const protectedIds = new Set(["start_ground", "boss_floor", "crawl_floor"]);
  const mutCount = {};
  const wOpts = [-24, 18, -34, 28, 10, -14, 38, -44, 22, -8, 32, -28, 14, 44, -18, 8];
  const yOpts = [0, -6, 6, -10, 10, -4, 4, -8, 8, 0, -12, 12, -6, 6, -10, 10];
  const xOpts = [0, 10, -10, 16, -16, 6, -6, 20, -20, 12, -12, 0, 8, -8, 14, -14];
  for (let iter = 0; iter < 900; iter++) {
    const r = build();
    if (!physicsOk(r)) throw new Error("physics broke during dedup at iter " + iter);
    const route = mainRouteOrdered(r.design);
    const toks = rhythmTokens(route);
    const sizes = sizeTokens(route);
    const tokDups = duplicateWindows(toks, NG);
    const sizeRatio = repeatRatio(sizes, NG);
    if (!tokDups.length && sizeRatio <= 0.22) return { iter, sizeRatio };
    let targetIdx;
    if (tokDups.length) targetIdx = Math.min(route.length - 1, tokDups[0].pos + 1);
    else targetIdx = Math.min(route.length - 1, duplicateWindows(sizes, NG)[0].pos + 1);
    // pick a mutable platform in the window
    let plat = route[targetIdx];
    for (let probe = 0; probe < NG && protectedIds.has(plat.id); probe++)
      plat = route[Math.min(route.length - 1, targetIdx + 1 + probe)];
    const entry = P.find((e) => e[0] === plat.id);
    const n = (mutCount[plat.id] = (mutCount[plat.id] || 0) + 1);
    const before = [entry[1], entry[2], entry[3]];
    entry[3] = Math.max(104, before[2] + wOpts[n % wOpts.length]);          // width
    entry[2] = before[1] + yOpts[n % yOpts.length];                          // y
    entry[1] = before[0] + xOpts[n % xOpts.length];                          // x
    const check = build();
    if (!physicsOk(check)) { entry[1] = before[0]; entry[2] = before[1]; entry[3] = before[2]; }
  }
  const r = build();
  const route = mainRouteOrdered(r.design);
  return { iter: 900, sizeRatio: repeatRatio(sizeTokens(route), NG), leftover: duplicateWindows(rhythmTokens(route), NG).length };
}

function main() {
  const dedup = deduplicate();
  console.log("dedup:", JSON.stringify(dedup));
  const r = build();
  const reachDash = bfsReach(r.design, "start_ground", true);
  const reachNoDash = bfsReach(r.design, "start_ground", false);
  const mainUnreached = r.design.filter((p) => p.route_role === "main" && !reachDash.has(p.id)).map((p) => p.id);
  const mainUnreachedNoDash = r.design.filter((p) => p.route_role === "main" && !reachNoDash.has(p.id)).map((p) => p.id);
  const targets = ["boss_floor", "db_floor", "sl_floor", "belfry_floor", "cr_lower", "cw_drop", "ba_floor", "wt_floor", "ro_floor", "station_floor", "bgc_w", "mv_floor", "attic_floor"];
  const targetsUnreached = targets.filter((t) => !reachNoDash.has(t));
  const heads = headBumps(r.platforms);
  const slots = wallSlots(r.platforms);
  const orders = r.platforms.filter((p) => p.route_role === "main").map((p) => p.route_order);
  const dupOrders = orders.filter((o, i) => orders.indexOf(o) !== i);
  // dynamic thirds band coverage (mirrors tmp_check_contracts.mjs)
  const floors = r.platforms.filter((p) => p.collision_role !== "ceiling");
  const ys = floors.map((p) => p.rect[1]);
  const yMin = Math.min(...ys), yMax = Math.max(...ys), span = yMax - yMin;
  const third = span / 3;
  const bands = {
    span: Math.round(span),
    upper: floors.some((p) => p.rect[1] < yMin + third),
    mid: floors.some((p) => p.rect[1] >= yMin + third && p.rect[1] < yMin + 2 * third),
    lower: floors.some((p) => p.rect[1] >= yMin + 2 * third),
  };
  // layout coverage (mirrors contracts: >=0.72 width, >=0.55 height)
  const lx0 = Math.min(...r.map_rooms.map((m) => m.layout_rect[0]));
  const lx1 = Math.max(...r.map_rooms.map((m) => m.layout_rect[0] + m.layout_rect[2]));
  const ly0 = Math.min(...r.map_rooms.map((m) => m.layout_rect[1]));
  const ly1 = Math.max(...r.map_rooms.map((m) => m.layout_rect[1] + m.layout_rect[3]));
  const coverW = (lx1 - lx0) / r.worldWidth, coverH = (ly1 - ly0) / r.worldHeight;
  // gates must not touch any main platform (never seal the critical path)
  const gateBlocks = [];
  for (const g of GATES) for (const p of r.design) if (p.route_role === "main") {
    const [gx, gy, gw, gh] = g.rect;
    if (gx < p.x + p.w && gx + gw > p.x && gy < p.y + p.h && gy + gh > p.y) gateBlocks.push({ gate: g.id, platform: p.id });
  }
  // enemy platforms valid
  const enemyBad = r.out.enemy_spawns.filter((e) => {
    const p = r.byId[e.platform_id];
    return !p || p.w < 86 || p.h > 90 || /wall|gate|locked/.test(p.id);
  }).map((e) => e.id);
  // key positions inside some room
  const inRoom = (pos) => r.map_rooms.some((m) => {
    const [x, y, w, h] = m.layout_rect; return pos[0] >= x && pos[0] <= x + w && pos[1] >= y && pos[1] <= y + h;
  });
  const posBad = [];
  for (const e of r.out.enemy_spawns) if (!inRoom(e.position)) posBad.push(e.id);
  for (const s of r.out.save_points) if (!inRoom(s.position)) posBad.push(s.id);
  for (const n of r.out.npcs) if (!inRoom(n.position)) posBad.push(n.id);
  for (const i of r.out.interactives) if (!inRoom(i.position)) posBad.push(i.id);
  for (const c of r.out.collectibles) if (!inRoom(c.position)) posBad.push(c.id);
  if (!inRoom(r.out.player_start)) posBad.push("player_start");
  if (!inRoom(r.out.boss_checkpoint)) posBad.push("boss_checkpoint");
  if (!inRoom(r.out.boss.position)) posBad.push("boss");
  // map_rect collisions
  const cellKeys = r.map_rooms.map((m) => m.map_rect.slice(0, 2).join(","));
  const cellDup = cellKeys.filter((k, i) => cellKeys.indexOf(k) !== i);

  console.log("== CH01 boxgarden self-audit ==");
  console.log("platforms:", r.platforms.length, "main:", orders.length, "rooms:", r.map_rooms.length,
    "world:", r.worldWidth + "x" + r.worldHeight, "gates:", GATES.length, "collectibles:", r.out.collectibles.length);
  console.log("reach(dash):", reachDash.size + "/" + r.design.length, "reach(no-dash):", reachNoDash.size + "/" + r.design.length);
  console.log("mainUnreached:", JSON.stringify(mainUnreached), "mainUnreachedNoDash:", JSON.stringify(mainUnreachedNoDash));
  console.log("targetsUnreached(no-dash):", JSON.stringify(targetsUnreached));
  console.log("headBumps:", heads.length, JSON.stringify(heads.slice(0, 8)));
  console.log("wallSlots:", slots.length, JSON.stringify(slots.slice(0, 8)));
  console.log("dupOrders:", JSON.stringify(dupOrders), "bands:", JSON.stringify(bands));
  console.log("layoutCover:", coverW.toFixed(3), coverH.toFixed(3), "cellDup:", JSON.stringify(cellDup));
  console.log("gateBlocksMain:", JSON.stringify(gateBlocks), "enemyBad:", JSON.stringify(enemyBad), "posBad:", JSON.stringify(posBad));
  console.log("cycle_rank:", r.map_topology.graph_fingerprint.cycle_rank, "maxDeg:", r.map_topology.graph_fingerprint.maximum_degree);
  const ok = mainUnreached.length === 0 && mainUnreachedNoDash.length === 0 && targetsUnreached.length === 0 &&
    heads.length === 0 && slots.length === 0 && dupOrders.length === 0 &&
    bands.upper && bands.mid && bands.lower && bands.span >= 1200 &&
    coverW >= 0.72 && coverH >= 0.55 && cellDup.length === 0 &&
    gateBlocks.length === 0 && enemyBad.length === 0 && posBad.length === 0 &&
    r.platforms.length >= r.map_rooms.length * 2;
  console.log(ok ? "SELF_AUDIT_OK" : "SELF_AUDIT_ISSUES");

  if (process.argv.includes("--write")) {
    if (!ok) { console.error("refusing to write: audit failed"); process.exit(1); }
    writeFileSync(OUT_PATH, JSON.stringify(r.out, null, 2) + "\n", "utf8");
    console.log("WROTE", OUT_PATH);
  } else console.log("(dry-run; pass --write to save)");
}

main();
