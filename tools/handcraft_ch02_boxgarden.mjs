// Hand-authored Chapter 2 "铸雨渠" — Silksong-style "three-well cascade" box-garden rebuild (38 rooms).
//
// World cross-section (docs/report/20260726160000000 §5.1 三井叠瀑方案):
//
//   top    [high_water_tower(ch3 door)]      [gutter secret]   [hook_gallery / pendulum works+vault]
//          [riser_shrine]  [A aqueduct band: sluice -> deck -> locks -> shrine -> flume crawl]
//   mid    [standpipe shaft (WALL GRIP gates)]  [ PUMP ATRIUM HUB 1700..3320 ]  [gauge band -> valve overlook]
//          [well_a -> grip_trial_cell (SILK WALL GRIP)]   [bellbone waterline station (sealed)]
//   low    [well_b drops -> overflow court -> undercanal -> tide cell (hidden bench)]
//          [rain-curtain gallery climbs back to the grip cell]
//          [silt vault -> (dash) drowned archive pod = testimony_02]
//          [wheel shaft -> (dash) wheel interior -> counterweight niche]
//          [furnace floor = sealed slag chute to ch5]   [spillway ladder shortcut back to hub]
//   east   [causeway -> forge shrine -> SMITH ARENA (boss) -> echo outfall -> pendulum climb (ECHO HOOK)]
//
// Main route is fully traversable with no abilities (gap<=160, rise<=96); thread_dash
// (starting tool, ch1 back-compat) plus the two new pickups only open shortcuts,
// secrets and cross-chapter revisit doors.

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BASE_PATH = join(ROOT, "godot/data/demo_ch02_rain_foundry_canal.json");
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
// zoneA aqueduct band / zoneB pendulum works / zoneC pump atrium hub /
// zoneD standpipe well / zoneE sunken canal layer / zoneF hammer-forge boss wing
const ROOMS = {
  // A ------------------------------------------------------------------------
  upper_sluice: { name: "上闸口", kind: "entry", depth: 2,
    objective: "从苔钟庭的排水钟管落进上闸口，跟着水走。", guide: "雨从这里入渠；整章的路就是水的路。",
    danger: "落点干净，湿石打滑。", next: "渡槽闸口", setpiece: "排水钟管的出口铁唇",
    traversal_focus: "跨章入口", pacing_role: "explore_and_loop" },
  aqueduct_gate: { name: "渡槽闸口", kind: "corridor", depth: 2,
    objective: "沿渡槽东行，读懂闸口的水位刻度。", guide: "上方夹层有一间不下雨的房间。",
    danger: "闸齿间歇开合。", next: "雨栅长堤", setpiece: "锈闸雨幕",
    traversal_focus: "安全试跳", pacing_role: "explore_and_loop" },
  rain_deck: { name: "雨栅长堤", kind: "corridor", depth: 2,
    objective: "顶着雨幕横越长堤。", guide: "管渠童子会替你数水滴的拍子。",
    danger: "钟坠从渠顶松脱。", next: "闸锁台阶", setpiece: "雨栅与吊钟坠",
    traversal_focus: "横越教学", pacing_role: "explore_and_loop" },
  gutter_interstice: { name: "渡槽夹层", kind: "secret", depth: 1,
    objective: "找到那间不下雨的房间。", guide: "闸口上沿的检修缝可以跳进去。",
    danger: "夹层安静得反常。", next: "渡槽闸口", setpiece: "干燥的检修暗格",
    traversal_focus: "隐藏探索", pacing_role: "reward" },
  sluice_locks: { name: "闸锁台阶", kind: "corridor", depth: 2,
    objective: "顺闸锁逐级下行。", guide: "台阶尽头是钟龛的灯。",
    danger: "闸齿锈刺外露。", next: "渡槽钟龛", setpiece: "成排的青铜闸锁",
    traversal_focus: "下行节奏", pacing_role: "tension" },
  aqueduct_shrine: { name: "渡槽钟龛", kind: "save", depth: 2,
    objective: "点亮入渠后的第一座钟龛。", guide: "钟龛会记录你的归处。",
    danger: "安全屋。", next: "检修匍匐缝", setpiece: "渡槽下的苔灯",
    traversal_focus: "存档教学", pacing_role: "respite" },
  flume_crawl: { name: "检修匍匐缝", kind: "corridor", depth: 2,
    objective: "贴顶匍匐挤过渡槽底部的检修缝。", guide: "雨水从格栅缝里砸头顶——忍住，前方有光。",
    danger: "低顶通道，无法起跳。", next: "泵房中庭", setpiece: "格栅漏雨的一线缝",
    traversal_focus: "压缩通道", pacing_role: "tension" },
  // C ------------------------------------------------------------------------
  pump_atrium: { name: "泵房中庭", kind: "hub", depth: 3,
    objective: "以泵房中庭为枢纽：上读水表、西攀立管、下探沉渠、东讨锤炉。", guide: "记住这里；所有水最终都绕回泵房。",
    danger: "巨型水轮的剪影在腔底转动。", next: "四方", setpiece: "1600px 泵房竖腔",
    traversal_focus: "垂直枢纽分流", pacing_role: "hub" },
  wish_board_landing: { name: "愿板平台", kind: "vista", depth: 2,
    objective: "查看巡礼愿板上钉着的求助。", guide: "工头在找三枚工牌。",
    danger: "平台悬在中庭高处。", next: "水表回廊", setpiece: "钉满湿纸的愿板",
    traversal_focus: "支线锚定", pacing_role: "respite" },
  gauge_gallery: { name: "水表回廊", kind: "corridor", depth: 3,
    objective: "沿水表回廊横越中庭上层。", guide: "东端通向阀顶眺台。",
    danger: "回廊悬空，钟蛾游弋。", next: "阀顶眺台", setpiece: "成排的黄铜水表",
    traversal_focus: "高空横越", pacing_role: "explore_and_loop" },
  valve_overlook: { name: "阀顶眺台", kind: "corridor", depth: 3,
    objective: "俯瞰整条锤炉长堤，找到俯冲的落点。", guide: "尽头一跃可直落炉前钟龛。",
    danger: "俯冲无回头路。", next: "炉前钟龛", setpiece: "红阀阵列与雨中长堤",
    traversal_focus: "单向俯冲", pacing_role: "explore_and_loop" },
  bellbone_wl_station: { name: "钟骨长梯·水线站", kind: "transit", depth: 4,
    objective: "参观封存的水线层站厅。", guide: "贯穿世界的长梯尚未通电，记住它的位置。",
    danger: "站厅只有滴水声。", next: "泵房中庭", setpiece: "青铜长梯与水线刻度",
    traversal_focus: "世界纵轴锚点", pacing_role: "respite" },
  atrium_west_vault: { name: "西高台暗室", kind: "secret", depth: 3,
    objective: "破开湿墙封条，取回暗室里的纺锤。", guide: "需要丝壁攀附。",
    danger: "暗室里的水声不对劲。", next: "泵房中庭", setpiece: "半沉的能量纺锤",
    traversal_focus: "回访门", pacing_role: "reward" },
  // D ------------------------------------------------------------------------
  well_a: { name: "立管井口", kind: "corridor", depth: 4,
    objective: "从中庭西沿下探立管井口。", guide: "失聪铁匠柳守在井沿。",
    danger: "落下去就没有原路。", next: "湿墙试炼间", setpiece: "锈死的立管井盖",
    traversal_focus: "单向下探", pacing_role: "explore_and_loop" },
  grip_trial_cell: { name: "湿墙试炼间", kind: "arena", depth: 5,
    objective: "击败井底守卫，取回丝壁攀附。", guide: "贴住青铜湿墙，绯线会替你抓住一瞬。",
    danger: "守卫的巢就在井底正中。", next: "立管井", setpiece: "两面对峙的青铜湿墙",
    traversal_focus: "精英战与能力获取", pacing_role: "climax" },
  standpipe_shaft: { name: "立管井", kind: "shaft", depth: 3,
    objective: "沿湿墙一路蹬墙攀上立管井。", guide: "需要丝壁攀附；井顶通向水塔。",
    danger: "1800px 落差，别在中途松手。", next: "立管钟龛", setpiece: "垂直立管与检修蹬位",
    traversal_focus: "攀墙竖井", pacing_role: "explore_and_loop" },
  riser_shrine: { name: "立管钟龛", kind: "save", depth: 1,
    objective: "在立管井顶点灯。", guide: "东沿可以一路坠回水线站厅。",
    danger: "安全屋，风雨在外。", next: "高位水塔", setpiece: "井顶的苔灯",
    traversal_focus: "高位存档", pacing_role: "respite" },
  high_water_tower: { name: "高位水塔", kind: "gate", depth: 0,
    objective: "攀上水塔，仰望通往盐白档案馆的雨溢立管。", guide: "立管口封存；需要丝壁攀附与回声钩索才能回访。",
    danger: "塔顶风大。", next: "盐白档案馆（回访）", setpiece: "封存的雨溢立管口",
    traversal_focus: "跨章回访门", pacing_role: "foreshadow" },
  // E ------------------------------------------------------------------------
  well_b: { name: "泵井坠道", kind: "shaft", depth: 5,
    objective: "从中庭地缝坠入泵井。", guide: "这是单向坠道——回程走水轮泄洪梯。",
    danger: "井壁湿滑，无法攀回。", next: "溢流庭", setpiece: "垂直泵井",
    traversal_focus: "纵向下探", pacing_role: "explore_and_loop" },
  overflow_court: { name: "溢流庭", kind: "corridor", depth: 6,
    objective: "沿双层溢流庭探索沉渠。", guide: "上层有一段湿苔颜色不对。",
    danger: "假苔地板一踩就塌。", next: "暗渠走道", setpiece: "绕柱双层溢流廊",
    traversal_focus: "环形探索", pacing_role: "explore_and_loop" },
  undercanal: { name: "暗渠走道", kind: "corridor", depth: 7,
    objective: "沿暗渠西行到最深处。", guide: "井底有人敲三下，不要回答第四下。",
    danger: "低照度，水面下有影子。", next: "沉渠尽头", setpiece: "半沉的暗渠栈道",
    traversal_focus: "低视野推进", pacing_role: "pressure" },
  tide_listening_cell: { name: "听潮暗室", kind: "secret", depth: 8,
    objective: "从塌落的湿苔板坠入听潮暗室。", guide: "黑潮在这里学人敲击；隐藏钟龛也在这里。",
    danger: "敲击声从墙那边来。", next: "暗渠走道", setpiece: "黑潮水面与隐苔龛",
    traversal_focus: "陷阱即通路", pacing_role: "reward" },
  rain_curtain_gallery: { name: "水幕暗渠", kind: "secret", depth: 5,
    objective: "从暗渠尽头穿过水幕，沿暗壁攀回立管井底。", guide: "水幕后面不是墙。",
    danger: "水声盖过一切脚步。", next: "湿墙试炼间", setpiece: "整面下坠的水幕",
    traversal_focus: "隐藏回环", pacing_role: "reward" },
  silt_vault: { name: "淤金库", kind: "treasure", depth: 6,
    objective: "搜刮沉在淤泥里的库房。", guide: "半沉工头想找回三枚工牌。",
    danger: "孢箱会炸。", next: "水轮竖井", setpiece: "半埋的货箱阵",
    traversal_focus: "奖励与叙事", pacing_role: "respite" },
  drowned_archive_pod: { name: "沉没档案舱", kind: "gate", depth: 7,
    objective: "冲过淤水间隙，读取沉没档案舱里的证词。", guide: "需要绯线冲刺。",
    danger: "舱里的名单不愿被读。", next: "淤金库", setpiece: "灌满水的青铜档案舱",
    traversal_focus: "回访门", pacing_role: "reward" },
  wheel_shaft: { name: "水轮竖井", kind: "shaft", depth: 6,
    objective: "抵达巨型水轮的底座，拉下捷径控制器。", guide: "泄洪梯打通后长期有效。",
    danger: "水轮齿隙深不见底。", next: "泄洪栈梯", setpiece: "全章最大的水轮",
    traversal_focus: "捷径解锁", pacing_role: "reward" },
  wheel_interior: { name: "水轮内部", kind: "gate", depth: 6,
    objective: "等辐条转到位，冲进水轮内部。", guide: "需要绯线冲刺；机械本身是路。",
    danger: "轮毂随时会转。", next: "配重暗格", setpiece: "转动的轮毂内腔",
    traversal_focus: "冲刺门", pacing_role: "reward" },
  counterweight_niche: { name: "配重暗格", kind: "secret", depth: 5,
    objective: "在配重块后找到藏起的地图残页。", guide: "从水轮内部向上爬。",
    danger: "配重随水位起落。", next: "水轮内部", setpiece: "嵌着残页的配重块",
    traversal_focus: "隐藏探索", pacing_role: "reward" },
  furnace_floor: { name: "炉底", kind: "gate", depth: 7,
    objective: "抵达锤炉的炉底，查看被铸渣封住的滑道口。", guide: "铸渣滑道通向黑曜巡礼路——现在还封着。",
    danger: "炉渣余温未散。", next: "黑曜巡礼路（单向）", setpiece: "封存的铸渣滑道口",
    traversal_focus: "跨章捷径锚点", pacing_role: "foreshadow" },
  spillway_ladder: { name: "泄洪栈梯", kind: "shaft", depth: 4,
    objective: "沿泄洪栈梯一路爬回泵房中庭。", guide: "这是沉渠唯一的回程。",
    danger: "栈梯上有伏兵。", next: "泵房中庭", setpiece: "贯穿三层的泄洪栈梯",
    traversal_focus: "纵向回环", pacing_role: "explore_and_loop" },
  // F ------------------------------------------------------------------------
  preboss_causeway: { name: "锤炉长堤", kind: "corridor", depth: 4,
    objective: "突破重怪把守的炉前长堤。", guide: "长堤重怪硬吃不亏——绕背打。",
    danger: "吊锤毫无预兆地砸落。", next: "炉前钟龛", setpiece: "锤炉仪仗残骸",
    traversal_focus: "重压走廊", pacing_role: "pressure" },
  forge_shrine: { name: "炉前钟龛", kind: "save", depth: 4,
    objective: "点亮炉前苔灯，准备面对执剪者。", guide: "死亡回跑很短。",
    danger: "门后就是执剪者的领域。", next: "沉炉大厅", setpiece: "炉前苔灯",
    traversal_focus: "战前存档", pacing_role: "tension" },
  smith_arena: { name: "沉炉大厅", kind: "boss", depth: 4,
    objective: "击败绯线执剪者，取回铁匠誓牌。", guide: "入口会在战斗时封闭。",
    danger: "执剪者的剪线覆盖全场。", next: "回声出水口", setpiece: "沉锤铁匠的旧炉",
    traversal_focus: "首领战", pacing_role: "boss" },
  echo_outfall: { name: "回声出水口", kind: "exit", depth: 4,
    objective: "顺出水口东行，前往盐白书库。", guide: "头顶的钟摆车间在锤声停后开启。",
    danger: "出水口铁声隆隆。", next: "第三章：盐白书库", setpiece: "巨大的出水铁口",
    traversal_focus: "章节收束", pacing_role: "denouement" },
  // B ------------------------------------------------------------------------
  pendulum_gantry: { name: "钟摆吊架", kind: "shaft", depth: 2,
    objective: "沿吊架蹬位攀上钟摆车间。", guide: "锤声停了，吊架才肯静止。",
    danger: "攀升很长，别在中途松手。", next: "钟摆车间", setpiece: "静止的巨型钟摆",
    traversal_focus: "纵向攀爬", pacing_role: "explore_and_loop" },
  pendulum_works: { name: "钟摆车间", kind: "treasure", depth: 1,
    objective: "在停摆的车间取回回声钩索。", guide: "执剪者的战利品；钩环门从此为你打开。",
    danger: "钟摆随时可能复摆。", next: "钩环回廊", setpiece: "悬满钩环的车间",
    traversal_focus: "能力获取", pacing_role: "climax" },
  pendulum_vault: { name: "钩环链暗室", kind: "treasure", depth: 1,
    objective: "钩过链隙取回工牌。", guide: "需要回声钩索。",
    danger: "链隙下就是深渊。", next: "钟摆车间", setpiece: "垂链与卡住的工牌",
    traversal_focus: "钩索门", pacing_role: "reward" },
  hook_gallery: { name: "钩环回廊", kind: "arena", depth: 0,
    objective: "清理钩环回廊的伏击，再从西沿坠回阀顶眺台。", guide: "天窗后还有一间暗室。",
    danger: "回廊脚下是空的。", next: "阀顶眺台", setpiece: "成排的青铜钩环",
    traversal_focus: "立体战斗", pacing_role: "pressure" },
};
const ROOM_ORDER = Object.keys(ROOMS);

// ---- platform layout -------------------------------------------------------
// [id, x, y, w, h, room, {oneway,mat,color,role,ceiling}]
const P = [];
const add = (id, x, y, w, h, room, o = {}) => P.push([id, x, y, w, h, room, o]);
const zig = (prefix, room, x1, x2, y0, dy, n, opts = {}) => {
  const w = opts.w || 150, h = opts.h || 24;
  for (let i = 0; i < n; i++)
    add(`${prefix}${String(i + 1).padStart(2, "0")}`, i % 2 === 0 ? x1 : x2, y0 + dy * (i + 1), w, h, room,
      { oneway: true, mat: opts.mat || "sluice_bridge", color: opts.color || "3f4a55", role: opts.role });
};

// A ─ aqueduct band (upper) --------------------------------------------------
add("start_ground",    140,  760, 340, 44, "upper_sluice", {});
add("us_step_a",       560,  812, 150, 26, "upper_sluice", { oneway: true });
add("aq_deck",         800,  880, 360, 40, "aqueduct_gate", {});
add("aq_lip",         1250,  836, 170, 26, "aqueduct_gate", { oneway: true });
add("gi_floor",       1620,  740, 260, 32, "gutter_interstice", { role: "branch", color: "1c2126" });
add("rd_run",         1540,  920, 320, 36, "rain_deck", {});
add("rd_step",        1950, 1000, 160, 26, "rain_deck", { oneway: true });
add("sl_lock_a",      2200, 1080, 240, 34, "sluice_locks", {});
add("sl_lock_b",      2530, 1160, 220, 32, "sluice_locks", {});
add("shrine_floor_a", 2840, 1240, 300, 40, "aqueduct_shrine", {});
add("cf",             3240, 1320, 420, 36, "flume_crawl", {});
add("cf_roof",        3240, 1180, 420, 32, "flume_crawl", { ceiling: true, role: "branch", color: "10141a" });
add("fc_d1",          3750, 1480, 150, 26, "flume_crawl", { oneway: true });
add("fc_d2",          3600, 1620, 140, 26, "flume_crawl", { oneway: true });

// C ─ pump atrium hub (1700..3320 tall chamber) ------------------------------
add("hub_top_shelf",  3440, 1700, 320, 36, "pump_atrium", {});
add("wb_floor",       3040, 1740, 280, 34, "wish_board_landing", {});
zig("pt", "pump_atrium", 3250, 3030, 1700, 94, 5);               // shelf -> gauge band (drop steps)
add("gg_w",           2960, 2244, 190, 28, "gauge_gallery", { oneway: true });
add("gg_c1",          3260, 2208, 170, 26, "gauge_gallery", { oneway: true });
add("gg_c2",          3550, 2244, 170, 26, "gauge_gallery", { oneway: true });
add("hub_balcony_e",  3830, 2296, 240, 30, "gauge_gallery", { oneway: true });
add("vo_floor",       4140, 2260, 300, 36, "valve_overlook", {});
add("vo_edge",        4530, 2216, 170, 26, "valve_overlook", { oneway: true });
add("vd1",            4760, 2470, 150, 26, "valve_overlook", { oneway: true });
add("vd2",            4620, 2760, 140, 26, "valve_overlook", { oneway: true });
add("vd3",            4780, 3040, 150, 26, "valve_overlook", { oneway: true });
add("vd4",            4640, 3320, 140, 26, "valve_overlook", { oneway: true });
add("vd5",            4800, 3560, 150, 26, "valve_overlook", { oneway: true });
add("hub_floor_w",    2470, 3320, 560, 50, "pump_atrium", {});
add("hub_floor_e",    3200, 3320, 540, 50, "pump_atrium", {});   // 170px pit between = well_b drop
zig("pw", "pump_atrium", 2530, 2770, 3320, -92, 7);              // west wall ladder up to station
add("station_floor",  2080, 2620, 340, 40, "bellbone_wl_station", {});
add("vault_floor",    1980, 2160, 260, 34, "atrium_west_vault", { role: "branch", color: "24303c" });
add("rr1",            1800, 1840, 150, 26, "riser_shrine", { oneway: true, role: "branch", color: "3f4a55" });
add("rr2",            1640, 2140, 150, 26, "riser_shrine", { oneway: true, role: "branch", color: "3f4a55" });
add("rr3",            1820, 2440, 150, 26, "riser_shrine", { oneway: true, role: "branch", color: "3f4a55" });

// D ─ standpipe well (west) --------------------------------------------------
add("wa_lip1",        2280, 3400, 150, 26, "well_a", { oneway: true });
add("wa_lip2",        2060, 3400, 150, 26, "well_a", { oneway: true });
add("wa_floor",       1560, 3380, 360, 40, "well_a", {});
add("wa_step",        1290, 3520, 150, 26, "well_a", { oneway: true });
add("gtc_floor",       960, 3660, 420, 44, "grip_trial_cell", {});
zig("sp", "standpipe_shaft", 980, 1200, 3660, -94, 22, { role: "branch", color: "2b3a45" });
add("rs_floor",       1400, 1540, 280, 36, "riser_shrine", { role: "branch", color: "2b3a45" });
add("tw_base",         960, 1500, 240, 32, "high_water_tower", { role: "branch", color: "26333f" });
zig("tw", "high_water_tower", 620, 860, 1500, -94, 7, { role: "branch", color: "26333f" });
add("twr_top",         600,  780, 300, 36, "high_water_tower", { role: "branch", color: "26333f" });

// E ─ sunken canal layer -----------------------------------------------------
add("wbd1",           3060, 3560, 140, 26, "well_b", { oneway: true });
add("wbd2",           2870, 3800, 150, 26, "well_b", { oneway: true });
add("wbd3",           3080, 4040, 150, 26, "well_b", { oneway: true });
add("oc_upper",       2980, 4260, 780, 40, "overflow_court", {});
add("oc_w_step",      2800, 4410, 150, 26, "overflow_court", { oneway: true });
add("oc_lower",       2850, 4550, 820, 46, "overflow_court", {});
add("uw_a",           2450, 4630, 300, 38, "undercanal", {});
add("uw_b",           2080, 4700, 260, 36, "undercanal", {});
add("uc_end",         1700, 4760, 290, 38, "undercanal", {});
add("tide_floor",     1620, 4950, 340, 42, "tide_listening_cell", { role: "branch", color: "121a24" });
add("td_out",         1400, 4860, 140, 26, "tide_listening_cell", { oneway: true, role: "branch", color: "121a24" });
zig("rc", "rain_curtain_gallery", 1420, 1180, 4760, -110, 9, { role: "branch", color: "1b2833" });
add("sv_floor",       3900, 4470, 380, 42, "silt_vault", {});
add("sv_lip",         3800, 4360, 140, 26, "silt_vault", { oneway: true, role: "branch" });
add("sv_e",           4370, 4530, 300, 38, "silt_vault", {});
add("dp_step",        3560, 4640, 150, 26, "drowned_archive_pod", { oneway: true, role: "branch", color: "1a2430" });
add("dap_lip",        3660, 4530, 140, 26, "drowned_archive_pod", { oneway: true, role: "branch", color: "1a2430" });
add("dap_floor",      3200, 4760, 380, 44, "drowned_archive_pod", { role: "branch", color: "1a2430" });
add("ws_base",        4790, 4570, 340, 44, "wheel_shaft", {});
add("ws_up1",         5170, 4460, 140, 26, "wheel_shaft", { oneway: true, role: "branch" });
add("ws_up2",         5000, 4350, 140, 26, "wheel_shaft", { oneway: true, role: "branch" });
add("ws_up3",         5150, 4240, 140, 26, "wheel_shaft", { oneway: true, role: "branch" });
add("wi_floor",       5500, 4330, 300, 36, "wheel_interior", { role: "branch", color: "202c38" });
add("wi_up",          5720, 4230, 140, 26, "wheel_interior", { oneway: true, role: "branch", color: "202c38" });
add("wi_out",         5450, 4560, 150, 26, "wheel_interior", { oneway: true, role: "branch", color: "202c38" });
add("cw_niche",       5470, 4140, 240, 32, "counterweight_niche", { role: "branch", color: "232f3b" });
add("ff_s1",          5250, 4640, 150, 26, "furnace_floor", { oneway: true });
add("ff_s2",          5540, 4690, 150, 26, "furnace_floor", { oneway: true });
add("ff_floor",       5830, 4730, 420, 46, "furnace_floor", {});
zig("sw2", "spillway_ladder", 4500, 4660, 4570, -92, 12, { role: "shortcut" });
add("sw_top",         4400, 3396, 150, 26, "spillway_ladder", { oneway: true, role: "shortcut", color: "3f4a55" });
add("sw_bridge",      4120, 3380, 160, 26, "spillway_ladder", { oneway: true, role: "shortcut", color: "3f4a55" });
add("sw_bridge2",     3880, 3350, 150, 26, "spillway_ladder", { oneway: true, role: "shortcut", color: "3f4a55" });

// F ─ hammer-forge boss wing -------------------------------------------------
add("pr_lip",         3830, 3400, 140, 26, "preboss_causeway", { oneway: true });
add("pc_step1",       3960, 3500, 150, 26, "preboss_causeway", { oneway: true });
add("pc_step2",       4180, 3620, 150, 26, "preboss_causeway", { oneway: true });
add("ra_a",           4060, 3760, 340, 42, "preboss_causeway", {});
add("ra_b",           4500, 3800, 260, 38, "preboss_causeway", {});
add("fs_floor",       4820, 3760, 320, 40, "forge_shrine", {});
add("boss_floor",     5260, 3820, 700, 52, "smith_arena", { mat: "foundry_boss", color: "241a16" });
add("eo_floor",       6080, 3780, 320, 44, "echo_outfall", {});
add("exit_floor",     6520, 3820, 300, 42, "echo_outfall", {});

// B ─ pendulum works (upper east, opens after the boss wing) -----------------
zig("pg", "pendulum_gantry", 6180, 6400, 3780, -94, 20, { role: "branch", color: "2c3540" });
add("pw_floor",       6040, 1840, 380, 40, "pendulum_works", { role: "branch", color: "2c3540" });
add("pv_floor",       6600, 1780, 240, 32, "pendulum_vault", { role: "branch", color: "222b35" });
add("hg_a",           5760, 1740, 160, 26, "hook_gallery", { oneway: true, role: "branch", color: "2c3540" });
add("hg_floor",       5470, 1640, 300, 36, "hook_gallery", { role: "branch", color: "2c3540" });
add("sky_ledge",      5230, 1540, 240, 30, "hook_gallery", { role: "branch", color: "222b35" });
add("hd1",            5260, 1820, 140, 26, "hook_gallery", { oneway: true, role: "branch", color: "2c3540" });
add("hd2",            4980, 2060, 150, 26, "hook_gallery", { oneway: true, role: "branch", color: "2c3540" });
add("hd3",            4740, 2190, 150, 26, "hook_gallery", { oneway: true, role: "branch", color: "2c3540" });

// ---- ability gates (physical sealed walls, removed on unlock) --------------
// Matrix (topology §4): dash_gap x2, wallshaft x3, hook_ring x2.
const GATES = [
  { id: "gate_dash_wheel",     rect: [5400, 4180, 42, 340], ability: "thread_dash",    name: "绯线冲刺", rooms: ["wheel_shaft", "wheel_interior"] },
  { id: "gate_dash_archive",   rect: [3820, 4300, 42, 340], ability: "thread_dash",    name: "绯线冲刺", rooms: ["silt_vault", "drowned_archive_pod"] },
  { id: "gate_wall_standpipe", rect: [ 950, 3510, 290, 30], ability: "silk_wall_grip", name: "丝壁攀附", rooms: ["grip_trial_cell", "standpipe_shaft"] },
  { id: "gate_wall_tower",     rect: [ 900, 1240, 42, 330], ability: "silk_wall_grip", name: "丝壁攀附", rooms: ["riser_shrine", "high_water_tower"] },
  { id: "gate_wall_vault",     rect: [1900, 2020, 42, 300], ability: "silk_wall_grip", name: "丝壁攀附", rooms: ["pump_atrium", "atrium_west_vault"] },
  { id: "gate_hook_chain",     rect: [6520, 1600, 42, 300], ability: "echo_hook",      name: "回声钩索", rooms: ["pendulum_works", "pendulum_vault"] },
  { id: "gate_hook_skylight",  rect: [5440, 1380, 42, 280], ability: "echo_hook",      name: "回声钩索", rooms: ["hook_gallery", "hook_gallery"] },
];

const round = (v) => Math.round(v);
const centerX = (p) => p.x + p.w / 2;

function build() {
  const base = JSON.parse(readFileSync(BASE_PATH, "utf8"));

  let order = 0;
  const design = P.map(([id, x, y, w, h, room, o]) => {
    const role = o.role || "main";
    return {
      id, x, y, w, h, room,
      mat: o.mat || "wet_metal", color: o.color || "17262b",
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

  // minimap grid cells
  const COLS = 13, ROWS = 9;
  const taken = new Set();
  const cells = {};
  for (const id of ROOM_ORDER) {
    const b = rb[id];
    const cx = (b.minx + b.maxx) / 2, cy = (b.miny + b.maxy) / 2;
    let col = Math.max(0, Math.min(COLS - 1, Math.floor(cx / worldWidth * COLS)));
    let row = Math.max(0, Math.min(ROWS - 1, Math.floor((cy - worldTop) / worldHeight * ROWS)));
    let key = `${col},${row}`, tries = 0;
    const deltas = [[0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,1],[1,-1],[-1,-1],[2,0],[-2,0],[0,2],[0,-2],[2,1],[-2,1],[2,-1],[-2,-1]];
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
    edge("upper_sluice", "aqueduct_gate", "passage", "walk_jump"),
    edge("aqueduct_gate", "rain_deck", "passage", "walk_jump"),
    edge("aqueduct_gate", "gutter_interstice", "passage", "hidden_jump"),
    edge("rain_deck", "sluice_locks", "passage", "walk_jump"),
    edge("sluice_locks", "aqueduct_shrine", "passage", "walk_jump"),
    edge("aqueduct_shrine", "flume_crawl", "passage", "crawl"),
    edge("flume_crawl", "pump_atrium", "one_way_drop", "one_way_drop", "", false),
    // C
    edge("pump_atrium", "wish_board_landing", "passage", "walk_jump"),
    edge("pump_atrium", "gauge_gallery", "passage", "climb"),
    edge("gauge_gallery", "valve_overlook", "passage", "walk_jump"),
    edge("valve_overlook", "forge_shrine", "one_way_drop", "one_way_drop", "", false),
    edge("pump_atrium", "bellbone_wl_station", "passage", "walk_jump"),
    edge("pump_atrium", "atrium_west_vault", "ability_gate", "wall_jump", "", true, "silk_wall_grip"),
    edge("pump_atrium", "preboss_causeway", "passage", "walk_jump"),
    // D
    edge("pump_atrium", "well_a", "passage", "walk_jump"),
    edge("well_a", "grip_trial_cell", "one_way_drop", "one_way_drop", "", false),
    edge("grip_trial_cell", "standpipe_shaft", "ability_gate", "wall_jump", "", true, "silk_wall_grip"),
    edge("standpipe_shaft", "riser_shrine", "passage", "wall_jump"),
    edge("riser_shrine", "high_water_tower", "ability_gate", "wall_jump", "", true, "silk_wall_grip"),
    edge("riser_shrine", "bellbone_wl_station", "one_way_drop", "one_way_drop", "", false),
    // E
    edge("pump_atrium", "well_b", "one_way_drop", "one_way_drop", "", false),
    edge("well_b", "overflow_court", "passage", "walk_jump"),
    edge("overflow_court", "undercanal", "passage", "walk_jump"),
    edge("undercanal", "tide_listening_cell", "one_way_drop", "one_way_drop", "", false),
    edge("undercanal", "rain_curtain_gallery", "passage", "hidden_climb"),
    edge("rain_curtain_gallery", "grip_trial_cell", "passage", "walk_jump"),
    edge("overflow_court", "silt_vault", "passage", "walk_jump"),
    edge("silt_vault", "wheel_shaft", "passage", "walk_jump"),
    edge("silt_vault", "drowned_archive_pod", "ability_gate", "dash", "", true, "thread_dash"),
    edge("wheel_shaft", "wheel_interior", "ability_gate", "dash", "", true, "thread_dash"),
    edge("wheel_interior", "counterweight_niche", "passage", "climb"),
    edge("wheel_interior", "wheel_shaft", "one_way_drop", "one_way_drop", "", false),
    edge("wheel_shaft", "furnace_floor", "passage", "walk_jump"),
    edge("wheel_shaft", "spillway_ladder", "shortcut", "unlock_shortcut", "ch02_wheel_hub_shortcut"),
    edge("spillway_ladder", "pump_atrium", "passage", "climb"),
    // F
    edge("preboss_causeway", "forge_shrine", "passage", "walk_jump"),
    edge("forge_shrine", "smith_arena", "boss_gate", "boss_gate"),
    edge("smith_arena", "echo_outfall", "passage", "walk_jump"),
    // B
    edge("echo_outfall", "pendulum_gantry", "passage", "climb"),
    edge("pendulum_gantry", "pendulum_works", "passage", "walk_jump"),
    edge("pendulum_works", "pendulum_vault", "ability_gate", "hook", "", true, "echo_hook"),
    edge("pendulum_works", "hook_gallery", "passage", "walk_jump"),
    edge("hook_gallery", "hook_gallery", "ability_gate", "hook", "", true, "echo_hook"),
    edge("hook_gallery", "valve_overlook", "one_way_drop", "one_way_drop", "", false),
  ];

  const nodes = map_rooms.map((r) => r.id);
  const adj = Object.fromEntries(nodes.map((n) => [n, new Set()]));
  for (const c of connections) { if (c.from !== c.to) { adj[c.from].add(c.to); adj[c.to].add(c.from); } }
  const degSeq = nodes.map((n) => adj[n].size).sort((a, b) => a - b);
  const map_topology = {
    topology_id: "rain_foundry_canal_boxgarden",
    nodes: map_rooms.map((r) => ({ id: r.id, room_type: r.kind[0].toUpperCase(), layer: r.depth,
      span_u: Math.max(4, Math.round((r.layout_rect[2]) / 220)), map_rect: r.map_rect })),
    edges: connections,
    main_visit_order: [
      "upper_sluice","aqueduct_gate","rain_deck","sluice_locks","aqueduct_shrine","flume_crawl","pump_atrium",
      "wish_board_landing","pump_atrium","gauge_gallery","valve_overlook","forge_shrine","preboss_causeway","pump_atrium",
      "well_b","overflow_court","undercanal","tide_listening_cell","undercanal","overflow_court","silt_vault","wheel_shaft",
      "spillway_ladder","pump_atrium","well_a","grip_trial_cell","standpipe_shaft","riser_shrine","high_water_tower",
      "riser_shrine","bellbone_wl_station","pump_atrium","preboss_causeway","forge_shrine","smith_arena","echo_outfall",
      "pendulum_gantry","pendulum_works","hook_gallery","valve_overlook","echo_outfall",
    ],
    graph_fingerprint: { vertices: nodes.length, edges: connections.length, cycle_rank: connections.length - nodes.length + 1, maximum_degree: Math.max(...degSeq), degree_sequence: degSeq },
    forbidden_motifs: ["horizontal_36_platform_chain", "shared_upper_loop_recovery_loop", "single_hub_star_without_ring"],
  };

  const mainPlats = design.filter((p) => p.route_role === "main");
  const runtime_geometry = {
    ...base.runtime_geometry,
    spatial_grammar: "rain_foundry_canal_boxgarden",
    critical_route: mainPlats.map((p) => p.id),
    upper_loop: design.filter((p) => ["gauge_gallery","valve_overlook","wish_board_landing","hook_gallery"].includes(p.room)).map((p) => p.id),
    recovery_loop: design.filter((p) => ["well_b","overflow_court","undercanal","wheel_shaft","spillway_ladder"].includes(p.room)).map((p) => p.id),
    branch_programs: ["aqueduct_descent", "atrium_vertical_hub", "sunken_canal_ring", "spillway_return", "standpipe_wall_quest", "pendulum_hook_wing", "slag_chute_foreshadow"],
    route_tags: ["central_hub", "vertical_standpipe_well", "sunken_canal_ring", "valve_dive_shortcut", "pendulum_upper_wing", "ability_gated_boxgarden", "handcrafted_2d"],
    main_route_orders: mainPlats.length,
  };

  // locked gates ------------------------------------------------------------
  const locked_gates = GATES.map((g) => ({
    id: g.id, rect: g.rect, color: "5a3a2d", material: "sluice_bridge",
    required_ability: g.ability, required_ability_name: g.name,
    from: g.rooms[0], to: g.rooms[1], map_marker: "ability_gate",
  }));

  // collectibles (ability + rewards; kind=="item" only) ----------------------
  const collectibles = [
    { id: "col_silk_wall_grip", kind: "item", room_id: "grip_trial_cell", item_id: "silk_wall_grip", position: onPlat("gtc_floor", 130), ability_name: "丝壁攀附", label: "丝壁攀附", note: "湿墙试炼间守卫身后；解锁蹬墙跳与全部湿墙门。" },
    { id: "col_echo_hook", kind: "item", room_id: "pendulum_works", item_id: "echo_hook", position: onPlat("pw_floor", -60), ability_name: "回声钩索", label: "回声钩索", note: "钟摆车间，执剪者倒下后开启；解锁钩环门。" },
    { id: "col_testimony_02", kind: "item", room_id: "drowned_archive_pod", item_id: "testimony_02", position: onPlat("dap_floor", -80), ability_name: "证词其二", label: "证词·其二", note: "沉没档案舱冲刺门后，真结局收集品。" },
    { id: "col_heart_knot", kind: "item", room_id: "high_water_tower", item_id: "heart_knot", position: onPlat("twr_top", -60), ability_name: "心结", label: "心结", note: "高位水塔顶，湿墙门后。" },
    { id: "col_energy_spindle", kind: "item", room_id: "atrium_west_vault", item_id: "energy_spindle", position: onPlat("vault_floor"), ability_name: "能量纺锤", label: "能量纺锤", note: "西高台暗室，湿墙门后。" },
    { id: "col_damp_knot", kind: "item", room_id: "wheel_interior", item_id: "damp_knot", position: onPlat("wi_floor", 60), ability_name: "防潮线结", label: "护符·防潮线结", note: "水轮内部，冲刺门后。" },
    { id: "col_map_fragment_02", kind: "item", room_id: "counterweight_niche", item_id: "map_fragment_02", position: onPlat("cw_niche"), ability_name: "地图残页", label: "地图残页·其二", note: "配重暗格，水轮内部上方。" },
    { id: "col_worker_badge_1", kind: "item", room_id: "gutter_interstice", item_id: "worker_badge", position: onPlat("gi_floor", 40), ability_name: "工牌", label: "锈工牌·其一", note: "渡槽夹层——不下雨的房间。" },
    { id: "col_worker_badge_2", kind: "item", room_id: "tide_listening_cell", item_id: "worker_badge", position: onPlat("tide_floor", 120), ability_name: "工牌", label: "锈工牌·其二", note: "听潮暗室的水沿。" },
    { id: "col_worker_badge_3", kind: "item", room_id: "pendulum_vault", item_id: "worker_badge", position: onPlat("pv_floor", 30), ability_name: "工牌", label: "锈工牌·其三", note: "钩环链暗室，钩索门后。" },
  ];
  const catalog_extra = {
    thread_dash: { name: "绯线冲刺", category: "Abilities", description: "短距离水平冲刺。苔钟庭断枝祭坛的战利品，随行至铸雨渠。" },
    silk_wall_grip: { name: "丝壁攀附", category: "Abilities", description: "贴住湿墙短暂减速下滑并蹬墙跃起。铁匠柳说：湿墙认茧，不认胆子。" },
    echo_hook: { name: "回声钩索", category: "Abilities", description: "钩住钩环与雨溢立管的回访路线。钟摆车间停摆后留下的战利品。" },
    testimony_02: { name: "证词·其二", category: "Relics", description: "六份证词之二：沉没档案舱里泡了三十年的点名册。" },
    heart_knot: { name: "心结", category: "Upgrades", description: "增加最大生命。打了死结的绯线，攥紧就不冷。" },
    energy_spindle: { name: "能量纺锤", category: "Upgrades", description: "增加最大能量。半沉在暗室水里的纺锤仍在转。" },
    damp_knot: { name: "防潮线结", category: "Charms", description: "锈泵修女编的防潮线结，陷阱触发判定略微缩小。" },
    map_fragment_02: { name: "地图残页·其二", category: "Relics", description: "预先揭示一个区域的房间轮廓。残页背面画着水轮的剖面。" },
    worker_badge: { name: "锈工牌", category: "Quest", description: "半沉工头点名要的工牌。牌上的坑坑洼洼，都是工人自己敲的。" },
  };

  // enemies ------------------------------------------------------------------
  const eTmpl = {}; for (const e of base.enemy_spawns) if (!eTmpl[e.kind]) eTmpl[e.kind] = e;
  const enemyPlan = [
    ["drain_leech", "aq_deck"], ["pipe_thrower", "rd_run", 60], ["valve_crawler", "sl_lock_a"],
    ["bell_mote", "gg_c1"], ["rain_censer_mote", "vo_floor"], ["waterwheel_knight", "ra_a"],
    ["rust_diver", "oc_upper", -200], ["rust_diver", "oc_lower", 200], ["pipe_thrower", "uw_a"],
    ["drain_leech", "sv_floor", -60], ["waterwheel_knight", "ws_base", -60], ["bell_mote", "hub_floor_e", 140],
    ["rust_diver", "wa_floor"], ["waterwheel_knight", "gtc_floor", -120], ["pipe_thrower", "hg_floor"],
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
    { id: "waterwheel_shortcut_lever", kind: "lever", position: onPlat("ws_base", 90), requires_keys: 0, label: "水轮捷径控制器", shortcut_id: "ch02_wheel_hub_shortcut" },
    { id: "sunken_hammer_gate", kind: "boss_gate", position: [round(boss.x + 60), round(boss.y - 40)] },
    { id: "ch02_chapter_exit", kind: "chapter_exit", label: "前往第三章：盐白书库", position: onPlat("exit_floor"), next_runtime_config_id: "demo_ch03_saltwhite_archive", next_config_path: "res://data/demo_ch03_saltwhite_archive.json", requires_demo_complete: true, interaction_size: [240, 180] },
  ];
  const save_points = [
    { id: "save_ch02_aqueduct", label: "渡槽苔灯", position: onPlat("shrine_floor_a"), hidden: false, note: "入渠后的第一座钟龛。" },
    { id: "save_ch02_riser", label: "立管苔灯", position: onPlat("rs_floor"), hidden: false, note: "立管井顶的钟龛，攀墙支线的犒赏。" },
    { id: "save_ch02_forge", label: "炉前苔灯", position: onPlat("fs_floor", -60), hidden: false, note: "首领门前的稳定检查点，死亡回跑很短。" },
    { id: "save_ch02_tide", label: "听潮隐龛", position: onPlat("tide_floor", -80), hidden: true, note: "藏在听潮暗室，奖励向下的好奇心。" },
  ];

  // npcs: keep the four canon NPCs (id/role/identity), embed story_dialogue
  const npcById = {}; for (const n of base.npcs) npcById[n.id] = n;
  const npc = (id, pid, dx, dialogue, story_dialogue, dialogue_meta) => ({
    ...structuredClone(npcById[id]), position: onPlat(pid, dx), dialogue, story_dialogue, dialogue_meta,
  });
  const npcs = [
    npc("npc_canal_child", "rd_run", -60,
      [
        "水往右走，人不一定；顺着水活下去，逆着水才找得到门。",
        "红阀会让上面的水轮停一口气，一口气够你跳，也够你后悔。",
        "一滴、两滴、三滴——数到第七滴水轮就换向；这座渠的秘密都藏在拍子里。",
      ],
      {
        first_meet: [
          "水往右走，人不一定；顺着水活下去，逆着水才找得到门。",
          "红阀会让上面的水轮停一口气，一口气够你跳，也够你后悔。",
          "一滴、两滴、三滴——数到第七滴水轮就换向；这座渠的秘密都藏在拍子里。",
        ],
        repeat: [
          "一滴、两滴……你脚步的拍子乱了；乱拍子的人，过不了三岔泵井。",
          "修女说外面的世界也下雨；我不怕雨，我只是怕雨底下没有渠。",
          "你敢逆着水走，我就数拍子送你；这是我唯一拿得出手的行李。",
        ],
        after_ability: [
          "你那个钩子荡过泵井的样子，我做梦梦过一百次；原来梦是拿来给别人先用的。",
          "钩子出手时数半拍再收——水轮的空当，只肯借给懂拍子的人。",
        ],
        after_boss: [
          "锤声停了，渠里的拍子全变了；旧拍子记完了，我该去学新的。",
          "我决定了，往上走，去苔钟庭——你回来的时候记得在庭里找我；我会数着拍子等。",
        ],
        late_game: [
          "我上来了！庭里的雨是从苔叶上滴下来的，一滴、两滴——比渠里的干净，拍子也软。",
          "长梯站厅那位织线的姐姐说，等梯通了带我去看盐做的雪；你说，纸那边也下雪吗？",
        ],
        true_ending_branch: [
          "若你真能改契约，帮我添半句就好：让水往低处流，让人往高处走。",
          "我在庭里给你留了一格拍子；世界重新开口那天，那一格是你的。",
        ],
      },
      { ability_ref: "echo_hook", testimony_ref: "testimony_02", quest_flag: "",
        leave: { condition: "boss_down_ch02 且 after_boss 播毕", effect: "迁居 ch1 court_hub（东侧苔阶）；late_game / true_ending_branch 在新位置播放" } }),
    npc("npc_rain_smith_liu", "wa_floor", 90,
      [
        "你听见雨，说明你还没听见铁；铁里全是没来得及喊完的名字。",
        "贴住青铜湿墙，绯线会替你抓住一瞬；一瞬过后，水会把你甩下去。",
        "若井底有人敲三下，不要回答第四下；那不是人，是黑潮在学礼貌。",
      ],
      {
        first_meet: [
          "你听见雨，说明你还没听见铁；铁里全是没来得及喊完的名字。",
          "贴住青铜湿墙，绯线会替你抓住一瞬；一瞬过后，水会把你甩下去。",
          "若井底有人敲三下，不要回答第四下；那不是人，是黑潮在学礼貌。",
        ],
        repeat: [
          "别动嘴，我看得见你舌头在动，看不见声音；要问路就用手比，比慢一点。",
          "我把耳朵还给了铁；从那天起，铁说什么我都信，人说什么我都猜。",
          "炉子凉到什么程度，人心就凉到什么程度；这座渠的炉，还是温的——还有救。",
        ],
        after_ability: [
          "手上起茧了？好；湿墙认茧，不认胆子。",
          "攀墙的诀窍是把自己当一枚钉；钉不问墙高，只问下一寸。",
        ],
        after_boss: [
          "师兄的锤停了……停了好。他打的最后一炉全是别人的名字，没有一锤是自己的。",
          "印记从泵王心口出来时，我胸口跟着烫了一下——聋子也感觉得到那种响。",
        ],
        late_game: [
          "沉没舱里的名单你捞上来了？念给我看——用手指，一笔一划，我一个名字都不想漏。",
          "原来我聋掉之前听见的不是幻听，是点名；他们点了一辈子，没人应到。",
        ],
        true_ending_branch: [
          "契约若能改，替我加一条：往后铸钟，只准铸铁，不准铸人。",
          "等钟再响，我听不见；但我会把手贴在钟壁上——那对铁匠来说，就是听见。",
        ],
      },
      { ability_ref: "silk_wall_grip", testimony_ref: "testimony_02", quest_flag: "", leave: null }),
    npc("npc_sluice_nun", "hub_floor_w", -180,
      [
        "铸钟时，工匠们把自己的名字留在水声里；现在水声替他们上班。",
        "买一枚防潮线结吧，雨会偷走你的跳跃，顺便偷走你的脾气。",
        "盐白书库保存着第一份契约，可他们说纸早就结晶了。",
      ],
      {
        first_meet: [
          "铸钟时，工匠们把自己的名字留在水声里；现在水声替他们上班。",
          "买一枚防潮线结吧，雨会偷走你的跳跃，顺便偷走你的脾气。",
          "盐白书库保存着第一份契约，可他们说纸早就结晶了。",
        ],
        repeat: [
          "我的祷文没有神听，我就念给泵听；泵比神勤快，至少它每天回应。——愿水绕开你。",
          "雨下了多少年，我就点了多少年货；秩序这种东西，是数出来的。",
        ],
        after_ability: [
          "能攀墙了？那高架上的祷文龛替我掸掸灰；顺便说好——上面的货不打折。",
          "墙上湿，心上别湿；贴墙的人最忌讳想太多。",
        ],
        after_boss: [
          "锤声停了，我的祷文短了一半；替亡者念的部分，今天起可以改成替生者念。",
          "泵井以下的水清了；水一清，我反而看见了从前不敢看的东西。",
        ],
        late_game: [
          "你把沉没舱的名单带出了水？那我的祷文得全部重写——原来我念错了三十年的名字。",
          "名字念对的那一刻，泵的声音都不一样了；不信你听，它今天没有咳嗽。",
        ],
        true_ending_branch: [
          "改契约的时候，把我的祷文也缝进去一角；不求显灵，求个押韵。",
          "等雨只是雨了，我就把这间铺子改成渡口；卖伞，不卖护符。——愿水绕开你。",
        ],
      },
      { ability_ref: "silk_wall_grip", testimony_ref: "testimony_02", quest_flag: "", leave: null }),
    npc("npc_drowned_foreman", "sv_floor", -140,
      [
        "把三枚工牌带回休息间，我就告诉你哪根管子通向首领后门。",
        "别相信干净的水，那里面没有活人的倒影，只有王冠洗过的命令。",
        "铁匠印记在泵王心口，不在柜子里；我们从来没资格把心放进柜子。",
      ],
      {
        first_meet: [
          "把三枚工牌带回休息间，我就告诉你哪根管子通向首领后门。",
          "别相信干净的水，那里面没有活人的倒影，只有王冠洗过的命令。",
          "铁匠印记在泵王心口，不在柜子里；我们从来没资格把心放进柜子。",
        ],
        repeat: [
          "上工——喊了一辈子，喊惯了；其实早没有工可上，只有名没点完。",
          "一号在轮下，二号在淤里，三号……三号我不敢想在哪；你替我把他们捡回来。",
          "水退一寸，我就多露出一寸；可我宁愿水别退——露出来的部分，不像话。",
        ],
        after_ability: [
          "那钩子能捞东西？淤金库最深处有一枚工牌卡在水轮第三齿——手别去，让线去。",
          "我们当年要有你这条线，三号就不会下水底找扳手了。",
        ],
        after_boss: [
          "泵王倒了？……那是我招进来的最后一个工人。收工的钟，今天我替他敲。",
          "首领后门的管子没人巡了；情报作废——不过话说回来，作废的情报最安全。",
        ],
        sidequest_done: [
          "一号，到。二号，到。三号……到。全员到齐——三十年了，头一回点完名。",
          "名点完了，我也该收工了；把我这半截交给水轮吧——它转，我就还在上班。",
          "最后一条命令：往后谁再点名，只准点活人。——收工。",
        ],
        late_game: [
          "沉没舱的名单上有我的工人；你既然见过名单，就更得把工牌带回来——牌是名字的骨头。",
          "名单会写错，工牌不会；牌上的坑坑洼洼，都是他们自己敲的。",
        ],
        true_ending_branch: [
          "契约要改就改彻底：工钱结清，名字归还，水位退到膝盖以下。",
          "替我告诉那位第七签署者——签名之前，先学会点名。",
        ],
      },
      { ability_ref: "echo_hook", testimony_ref: "testimony_02", quest_flag: "item_ch02_worker_badges",
        leave: { condition: "sidequest_done 播毕", effect: "沉眠于水轮下；原位留「半枚锈工牌」拾取点与一段绯线低语" } }),
  ];

  const hz = (id, kind, pid, dx, dy, w, h, msg) => { const p = byId[pid]; return { id, kind, rect: [round(centerX(p) + dx - w / 2), round(p.y + dy), w, h], damage: 1, message: msg, platform_id: pid }; };
  const hazards = [
    hz("ch02_hazard_deck_clapper", "falling_clapper", "rd_run", 90, -150, 110, 30, "钟坠从渠顶松脱砸下。"),
    hz("ch02_hazard_causeway_clapper", "falling_clapper", "ra_b", 0, -150, 110, 30, "炉前吊锤突然脱钩。"),
    hz("ch02_hazard_atrium_gap", "bell_gap", "hub_floor_w", 365, -8, 120, 20, "泵井深不见底。"),
    hz("ch02_hazard_wheel_gap", "bell_gap", "ws_base", -230, -8, 110, 20, "水轮齿隙深不见底。"),
    hz("trap_wet_moss_tide", "fake_moss_floor", "uc_end", 60, -6, 120, 22, "湿苔板轰然塌陷——下面还有房间。"),
    hz("ch02_hazard_overflow_moss", "fake_moss_floor", "oc_upper", 250, -6, 130, 22, "溢流庭的假苔一踩就塌。"),
    hz("ch02_hazard_lock_spikes", "spikes", "sl_lock_b", 0, -8, 120, 20, "闸齿锈刺外露。"),
    hz("ch02_hazard_causeway_spikes", "spikes", "ra_a", -90, -8, 120, 20, "长堤上布满铸渣尖刺。"),
    hz("ch02_hazard_undercanal_spikes", "spikes", "uw_b", 20, -8, 120, 20, "暗渠底的锈钉阵。"),
    hz("ch02_hazard_silt_chest", "spore_chest", "sv_floor", 150, -30, 90, 34, "淤金库的孢箱炸开湿雾。"),
    hz("ch02_hazard_spillway_revenge", "shortcut_revenge", "sw206", 0, -30, 110, 30, "复仇伏兵顺着泄洪栈梯杀回来。"),
  ];

  const lb = (text, pid, dy, color) => { const p = byId[pid]; return { text, position: [round(centerX(p)), round(p.y + dy)], color }; };
  const labels = [
    lb("上闸口：来自苔钟庭的排水钟管", "start_ground", -70, "9fe8ff"),
    lb("渡槽夹层：不下雨的房间", "gi_floor", -50, "8d97a8"),
    lb("检修匍匐缝：压低身形", "cf", -60, "b9c7d4"),
    lb("泵房中庭：上读表 · 西攀管 · 下探渠 · 东讨炉", "hub_floor_w", -110, "a6ecff"),
    lb("钟骨长梯·水线站（未通电）", "station_floor", -80, "8d97a8"),
    lb("阀顶眺台：俯冲直落炉前", "vo_floor", -66, "f2c66b"),
    lb("泵井坠道 ↓ 回程走泄洪梯", "wbd1", -56, "dcb2ff"),
    lb("水轮捷径控制器", "ws_base", -80, "f2c66b"),
    lb("泄洪栈梯 · 直回泵房", "sw201", -60, "f2c66b"),
    lb("立管井口：铁匠柳在此", "wa_floor", -70, "c8e6f0"),
    lb("湿墙试炼：丝壁攀附", "gtc_floor", -66, "ff9d8a"),
    lb("立管井：蹬墙直上", "sp04", -56, "ff9d8a"),
    lb("高位水塔：雨溢立管（回访盐白档案馆）", "twr_top", -70, "e8e3c8"),
    lb("沉没档案舱：证词其二", "dap_floor", -66, "9a86b8"),
    lb("炉底：铸渣滑道（封）→ 黑曜巡礼路", "ff_floor", -70, "b8a086"),
    lb("沉炉大厅 →", "fs_floor", -80, "f2b873"),
    lb("钟摆车间：回声钩索", "pw_floor", -66, "ff9d8a"),
    lb("钩环回廊：西沿坠回眺台", "hg_floor", -60, "a6ecff"),
  ];

  const envBase = base.environment_blocks[0];
  const mass = (id, rect, color, z) => ({ id, rect: rect.map(round), color, z_index: z, visual_source: envBase.visual_source, asset_root: envBase.asset_root, ownership: envBase.ownership });
  const hubW = byId["hub_floor_w"], wheel = byId["ws_base"], tide = byId["tide_floor"], furnace = byId["ff_floor"], tower = byId["twr_top"];
  const environment_blocks = [
    mass("ch02_back_wall", [0, worldTop, worldWidth, worldHeight], "0d141c", -95),
    mass("ch02_atrium_shaft_mass", [hubW.x - 80, 1650, 1500, 1900], "101a24", -90),
    mass("ch02_waterwheel_silhouette", [wheel.x - 140, wheel.y - 900, 720, 980], "16202c", -89),
    mass("ch02_station_frame", [byId["station_floor"].x - 40, byId["station_floor"].y - 320, 420, 360], "1d2430", -89),
    mass("ch02_standpipe_column", [900, 1500, 520, 2200], "121c26", -91),
    mass("ch02_tower_seal", [tower.x + 20, tower.y - 320, 260, 320], "232b38", -88),
    mass("ch02_undercanal_water", [1500, byId["oc_lower"].y + 46, 2400, 260], "0a141e", -86),
    mass("ch02_tide_blackwater", [tide.x - 120, tide.y + tide.h, 700, 300], "05070c", -85),
    mass("ch02_furnace_glow", [furnace.x - 60, furnace.y + furnace.h, 620, 300], "1c110a", -87),
    mass("ch02_slag_chute_seal", [furnace.x + furnace.w - 60, furnace.y - 300, 240, 340], "241a12", -88),
    mass("ch02_arena_floor_mass", [byId["boss_floor"].x - 40, byId["boss_floor"].y + byId["boss_floor"].h, byId["boss_floor"].w + 80, 300], "0c0d13", -88),
    mass("ch02_crawl_shadow", [byId["cf"].x, byId["cf"].y - 140, 420, 140], "0b0f14", -84),
    mass("ch02_pendulum_mass", [byId["pw_floor"].x - 80, byId["pw_floor"].y - 700, 900, 760], "141b26", -90),
  ];

  const parkour_segments = [
    { id: "ch02_flume_atrium_drop", room_id: "flume_crawl", technique: "crawl then one-way drop into the hub",
      platforms: ["cf", "fc_d1", "fc_d2", "hub_top_shelf"],
      safety_contract: { max_gap: 176, max_rise: 110, minimum_full_jump_clearance: 232 } },
    { id: "ch02_wellb_descent", room_id: "well_b", technique: "one-way drop chain",
      platforms: ["hub_floor_e", "wbd1", "wbd2", "wbd3", "oc_upper"],
      safety_contract: { max_gap: 176, max_rise: 110, minimum_full_jump_clearance: 232 } },
    { id: "ch02_spillway_return", room_id: "spillway_ladder", technique: "long zigzag shortcut climb",
      platforms: ["ws_base", "sw201", "sw206", "sw212", "sw_top", "sw_bridge", "sw_bridge2", "hub_floor_e"],
      safety_contract: { max_gap: 176, max_rise: 112, minimum_full_jump_clearance: 232 } },
    { id: "ch02_standpipe_climb", room_id: "standpipe_shaft", technique: "wall-grip zigzag ascent",
      platforms: ["gtc_floor", "sp01", "sp08", "sp15", "sp22", "rs_floor"],
      safety_contract: { max_gap: 176, max_rise: 110, minimum_full_jump_clearance: 232 } },
  ];

  const cross_chapter_anchors = [
    { id: "anchor_drain_bellpipe", channel: "排水钟管", room: "upper_sluice", type: "main_visit", status: "open",
      counterpart: { chapter: "demo_ch01_moss_bell_court", room: "drain_bellpipe" },
      note: "ch1 锈冠殿排水钟管的对端；首访主线双向落地。" },
    { id: "anchor_rain_riser", channel: "雨溢立管", room: "high_water_tower", type: "revisit_gate", status: "sealed_until_ch03",
      counterpart: { chapter: "demo_ch03_saltwhite_archive", room: "wet_cellar" },
      required_abilities: ["silk_wall_grip", "echo_hook"],
      note: "高位水塔顶的封存立管口，ch3 湿书地窖重做后开通。" },
    { id: "anchor_slag_chute", channel: "铸渣滑道", room: "furnace_floor", type: "one_way_shortcut", status: "sealed_until_ch05",
      counterpart: { chapter: "demo_ch05_obsidian_pilgrim_road", room: "slag_arrival" },
      note: "炉底铸渣滑道口，单向坠向 ch5 巡礼路中段；对端建成前保持封存。" },
    { id: "anchor_bellbone_waterline", channel: "钟骨长梯·水线层", room: "bellbone_wl_station", type: "transit_station", status: "sealed",
      counterpart: { chapter: "world", room: "bellbone_ladder_network" },
      note: "五站快旅网络的水线层站厅，封存态可参观。" },
    { id: "anchor_mossgrip_export", channel: "苔壁竖井回访", room: "grip_trial_cell", type: "ability_export", status: "active_on_pickup",
      counterpart: { chapter: "demo_ch01_moss_bell_court", room: "mossgrip_shaft" },
      ability: "silk_wall_grip",
      note: "本章取得丝壁攀附后，ch1 苔壁竖井 wallshaft 门（心结）即可回访开启——第一条兑现的跨章回访经济。" },
  ];

  const out = { ...base };
  out.name = base.name;
  out.map_title = "铸雨渠：三井叠瀑箱庭版";
  out.goal = "以泵房中庭为枢纽探索三井叠瀑：沿渡槽匍匐坠入中庭，下探沉渠拉通泄洪梯，西入湿墙试炼夺回丝壁攀附并攀上高位水塔，东讨沉炉大厅击败绯线执剪者，最后在钟摆车间取回回声钩索、经回声出水口前往盐白书库。";
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
  out.enemy_spawns = enemy_spawns;
  out.boss = bossData;
  out.labels = labels;
  out.connections = connections;
  out.map_topology = map_topology;
  out.runtime_geometry = runtime_geometry;
  out.parkour_segments = parkour_segments;
  out.cross_chapter_anchors = cross_chapter_anchors;
  out.inventory = {
    ...base.inventory,
    starting_tools: ["thread_burst", "menders_right", "thread_dash"],
    catalog: { ...base.inventory.catalog, ...catalog_extra },
  };
  out.ability_gated_start = true;   // wall grip / hook locked until pickups; dash carried in from ch1
  out.map_layout_tags = ["handcrafted", "true_2d", "boxgarden", "central_hub", "three_well_cascade", "standpipe_wall_quest", "sunken_canal_ring", "pendulum_hook_wing", "ability_gates", "see_then_return", "spillway_return", "short_boss_run", "rain_foundry"];
  out.design_note = {
    source: "hand-authored (tools/handcraft_ch02_boxgarden.mjs)",
    intent: "Silksong-style three-well cascade box-garden: an aqueduct band feeds a 1600px pump-atrium hub; wells sink to a sunken canal ring with a hidden tide cell and a spillway-ladder return; a west standpipe well holds the silk_wall_grip elite trial and climbs to the sealed rain-riser door (ch3); the east forge wing ends in the boss, and the post-boss pendulum works holds echo_hook. 7 ability gates + 5 cross-chapter anchors wire the revisit economy (including ch1 mossgrip_shaft).",
    coordinate_mapping: { note: "explicit 2D world coordinates; main route is fully traversable without dash/wall/hook (gap<=160, rise<=96); those abilities only open shortcuts/secrets/revisit doors" },
  };
  out.progression_mode = "combat_clear";
  out.required_keys = 0;
  out.entry_from_previous = { ...base.entry_from_previous, position: out.player_start };
  out.chapter_transition = { ...base.chapter_transition, entry_spawn: out.player_start };

  return { out, design, platforms, map_rooms, connections, map_topology, worldWidth, worldHeight, worldTop, byId };
}

// ---- self-audit (mirrors strict checks + no-ability main route) ------------
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

// ---- uniqueness mirror -----------------------------------------------------
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
function deduplicate() {
  const NG = 3;
  const protectedIds = new Set(["start_ground", "boss_floor", "cf"]);
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
    let plat = route[targetIdx];
    for (let probe = 0; probe < NG && protectedIds.has(plat.id); probe++)
      plat = route[Math.min(route.length - 1, targetIdx + 1 + probe)];
    const entry = P.find((e) => e[0] === plat.id);
    const n = (mutCount[plat.id] = (mutCount[plat.id] || 0) + 1);
    const before = [entry[1], entry[2], entry[3]];
    entry[3] = Math.max(104, before[2] + wOpts[n % wOpts.length]);
    entry[2] = before[1] + yOpts[n % yOpts.length];
    entry[1] = before[0] + xOpts[n % xOpts.length];
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
  const targets = ["boss_floor", "exit_floor", "fs_floor", "oc_lower", "uc_end", "ws_base", "gtc_floor", "station_floor", "vo_floor", "hub_floor_w", "wb_floor", "shrine_floor_a", "tide_floor", "eo_floor", "ff_floor"];
  const targetsUnreached = targets.filter((t) => !reachNoDash.has(t));
  const heads = headBumps(r.platforms);
  const slots = wallSlots(r.platforms);
  const orders = r.platforms.filter((p) => p.route_role === "main").map((p) => p.route_order);
  const dupOrders = orders.filter((o, i) => orders.indexOf(o) !== i);
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
  const lx0 = Math.min(...r.map_rooms.map((m) => m.layout_rect[0]));
  const lx1 = Math.max(...r.map_rooms.map((m) => m.layout_rect[0] + m.layout_rect[2]));
  const ly0 = Math.min(...r.map_rooms.map((m) => m.layout_rect[1]));
  const ly1 = Math.max(...r.map_rooms.map((m) => m.layout_rect[1] + m.layout_rect[3]));
  const coverW = (lx1 - lx0) / r.worldWidth, coverH = (ly1 - ly0) / r.worldHeight;
  const gateBlocks = [];
  for (const g of GATES) for (const p of r.design) if (p.route_role === "main") {
    const [gx, gy, gw, gh] = g.rect;
    if (gx < p.x + p.w && gx + gw > p.x && gy < p.y + p.h && gy + gh > p.y) gateBlocks.push({ gate: g.id, platform: p.id });
  }
  const enemyBad = r.out.enemy_spawns.filter((e) => {
    const p = r.byId[e.platform_id];
    return !p || p.w < 86 || p.h > 90 || /wall|gate|locked/.test(p.id);
  }).map((e) => e.id);
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
  const cellKeys = r.map_rooms.map((m) => m.map_rect.slice(0, 2).join(","));
  const cellDup = cellKeys.filter((k, i) => cellKeys.indexOf(k) !== i);
  // hazard platform ids must exist
  const hazardBad = r.out.hazards.filter((h) => !r.byId[h.platform_id]).map((h) => h.id);
  // gate door counts match the topology matrix
  const gateCount = { thread_dash: 0, silk_wall_grip: 0, echo_hook: 0 };
  for (const g of GATES) gateCount[g.ability]++;
  const gateMatrixOk = gateCount.thread_dash === 2 && gateCount.silk_wall_grip === 3 && gateCount.echo_hook === 2;
  const aspect = r.worldWidth / r.worldHeight;

  console.log("== CH02 boxgarden self-audit ==");
  console.log("platforms:", r.platforms.length, "main:", orders.length, "rooms:", r.map_rooms.length,
    "world:", r.worldWidth + "x" + r.worldHeight, "aspect:", aspect.toFixed(3), "gates:", GATES.length, "collectibles:", r.out.collectibles.length);
  console.log("reach(dash):", reachDash.size + "/" + r.design.length, "reach(no-dash):", reachNoDash.size + "/" + r.design.length);
  console.log("mainUnreached:", JSON.stringify(mainUnreached), "mainUnreachedNoDash:", JSON.stringify(mainUnreachedNoDash));
  console.log("targetsUnreached(no-dash):", JSON.stringify(targetsUnreached));
  console.log("headBumps:", heads.length, JSON.stringify(heads.slice(0, 8)));
  console.log("wallSlots:", slots.length, JSON.stringify(slots.slice(0, 8)));
  console.log("dupOrders:", JSON.stringify(dupOrders), "bands:", JSON.stringify(bands));
  console.log("layoutCover:", coverW.toFixed(3), coverH.toFixed(3), "cellDup:", JSON.stringify(cellDup));
  console.log("gateBlocksMain:", JSON.stringify(gateBlocks), "enemyBad:", JSON.stringify(enemyBad), "posBad:", JSON.stringify(posBad));
  console.log("hazardBad:", JSON.stringify(hazardBad), "gateMatrixOk:", gateMatrixOk);
  console.log("cycle_rank:", r.map_topology.graph_fingerprint.cycle_rank, "maxDeg:", r.map_topology.graph_fingerprint.maximum_degree);
  const ok = mainUnreached.length === 0 && mainUnreachedNoDash.length === 0 && targetsUnreached.length === 0 &&
    heads.length === 0 && slots.length === 0 && dupOrders.length === 0 &&
    bands.upper && bands.mid && bands.lower && bands.span >= 1200 &&
    coverW >= 0.72 && coverH >= 0.55 && cellDup.length === 0 &&
    gateBlocks.length === 0 && enemyBad.length === 0 && posBad.length === 0 &&
    hazardBad.length === 0 && gateMatrixOk && aspect <= 1.4 &&
    r.map_topology.graph_fingerprint.cycle_rank >= 5 &&
    r.platforms.length >= r.map_rooms.length * 2 && r.map_rooms.length >= 36;
  console.log(ok ? "SELF_AUDIT_OK" : "SELF_AUDIT_ISSUES");

  if (process.argv.includes("--write")) {
    if (!ok) { console.error("refusing to write: audit failed"); process.exit(1); }
    writeFileSync(OUT_PATH, JSON.stringify(r.out, null, 2) + "\n", "utf8");
    console.log("WROTE", OUT_PATH);
  } else console.log("(dry-run; pass --write to save)");
}

main();
