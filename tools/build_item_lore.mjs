// Build godot/data/item_lore.json from the worldview canon §7 item lore library.
// The lore text is extracted VERBATIM from the spec (docs/ stays read-only).
//
//   node tools/build_item_lore.mjs           # regenerate godot/data/item_lore.json
//   node tools/build_item_lore.mjs --verify  # re-parse spec and diff against the json, char-exact
//
// Canon id -> runtime id adjudication:
//   resin              -> currency      (runtime currency bucket; canon currency_name 松脂碎片)
//   lost_worker_badges -> worker_badge  (ch2 badge sidequest collects x3 single badges; the
//                                        catalog display name 锈工牌 is kept, lore applies)
// All other canon ids are used as-is; canon items that have no runtime pickup yet
// (silent_mark_moss, pollen_filter, burned_banner_ash, final_charm_crimson_loop,
//  salt_page_1_3, greenhouse_song_page, seventh_name_parts) are still emitted so future
// content that adds those ids picks the lore up automatically.
import { readFileSync, writeFileSync } from "node:fs";

const SPEC = "docs/spec/20260726160100000_绯线巡礼世界观圣典.md";
const OUT = "godot/data/item_lore.json";

// canon id -> runtime id
const RUNTIME_ID = {
  resin: "currency",
  lost_worker_badges: "worker_badge",
};

// runtime ids whose in-game catalog display name is kept (lore still applies)
const KEEP_CATALOG_NAME = new Set(["worker_badge"]);

// functional one-liners appended AFTER the canon lore (先铭文后功能).
const FUNCTION_LINES = {
  moss_lens: "【功能】自动记录已探索的房间，写入路线图。",
  quiet_sole: "【功能】陷阱触发判定略微缩小。",
  heart_knot: "【功能】增加最大生命。",
  energy_spindle: "【功能】增加最大能量。",
  map_fragment: "【功能】预先揭示一个区域的房间轮廓。",
  smith_oath_plate: "【功能】可作为进入盐白书库的凭证。",
};

function parseSpec() {
  const text = readFileSync(SPEC, "utf8");
  const start = text.indexOf("## 7. 物品铭文库");
  const end = text.indexOf("## 8. 术语表与命名规则");
  if (start < 0 || end < 0) throw new Error("spec section 7 boundaries not found");
  const section = text.slice(start, end);
  // **<name> `<id>`<optional trailing inside bold>**<optional annotation>\n(> line)+
  const blockRe = /\*\*([^`*\n]+)`([a-z0-9_]+)`[^*\n]*\*\*[^\n]*\n((?:> .*\n?)+)/g;
  const entries = [];
  let m;
  while ((m = blockRe.exec(section)) !== null) {
    const name = m[1].trim();
    const id = m[2];
    const lore = m[3]
      .split("\n")
      .filter((l) => l.startsWith("> "))
      .map((l) => l.slice(2));
    entries.push({ canon_id: id, canon_name: name, lore });
  }
  if (entries.length !== 32)
    throw new Error(`expected 32 canon lore entries, parsed ${entries.length}`);
  return entries;
}

function buildItems(entries) {
  const items = {};
  for (const e of entries) {
    const runtimeId = RUNTIME_ID[e.canon_id] || e.canon_id;
    const item = { canon_id: e.canon_id, canon_name: e.canon_name };
    if (!KEEP_CATALOG_NAME.has(runtimeId)) item.display_name = e.canon_name;
    item.lore = e.lore;
    const fn = FUNCTION_LINES[runtimeId];
    if (fn) item.function = fn;
    items[runtimeId] = item;
  }
  return items;
}

const entries = parseSpec();

if (process.argv.includes("--verify")) {
  const json = JSON.parse(readFileSync(OUT, "utf8"));
  const items = json.items || {};
  let mismatches = 0;
  for (const e of entries) {
    const runtimeId = RUNTIME_ID[e.canon_id] || e.canon_id;
    const item = items[runtimeId];
    if (!item) {
      console.log(`MISMATCH ${e.canon_id}: missing runtime entry ${runtimeId}`);
      mismatches++;
      continue;
    }
    const problems = [];
    if (item.canon_name !== e.canon_name) problems.push("canon_name");
    if ("display_name" in item && item.display_name !== e.canon_name) problems.push("display_name");
    const a = (item.lore || []).join("\n");
    const b = e.lore.join("\n");
    if (a !== b) problems.push(`lore (json ${a.length} chars vs spec ${b.length} chars)`);
    if (problems.length) {
      console.log(`MISMATCH ${e.canon_id} -> ${runtimeId}: ${problems.join(", ")}`);
      mismatches++;
    } else {
      console.log(`OK ${e.canon_id} -> ${runtimeId} (${e.lore.length} lines, verbatim)`);
    }
  }
  console.log(`ITEM_LORE_VERIFY entries=${entries.length} mismatches=${mismatches}`);
  process.exit(mismatches === 0 ? 0 : 1);
}

const out = {
  _source: "docs/spec/20260726160100000_绯线巡礼世界观圣典.md §7 物品铭文库",
  _generated_by: "tools/build_item_lore.mjs (lore lines verbatim; do not hand-edit lore text)",
  _runtime_id_map: RUNTIME_ID,
  items: buildItems(entries),
};
writeFileSync(OUT, JSON.stringify(out, null, 2) + "\n", "utf8");
console.log(`wrote ${OUT} with ${entries.length} canon entries`);
