import { appendUtilityPanel } from "./utility-panel.js";
const KEY = "crimson-browser-records-v1";
export function validateRecord(value) {
  return (
    !!value &&
    Number.isInteger(value.chapter) &&
    value.chapter >= 0 &&
    value.chapter < 6 &&
    ["clear", "defeat"].includes(value.result) &&
    Number.isFinite(value.seconds) &&
    value.seconds >= 0 &&
    value.seconds <= 86400 &&
    ["damage", "kills"].every(
      (k) =>
        Number.isSafeInteger(value[k]) && value[k] >= 0 && value[k] <= 100000,
    )
  );
}
export class RunRecords {
  rows = [];
  active = null;
  error = "";
  constructor(storage) {
    this.storage = storage;
    try {
      const data = JSON.parse(storage().getItem(KEY));
      if (data?.version === 1 && Array.isArray(data.rows))
        this.rows = data.rows.filter(validateRecord).slice(0, 24);
    } catch {}
  }
  begin(chapter) {
    this.active = { chapter, damage: 0, kills: 0 };
  }
  damage(amount) {
    if (this.active && Number.isFinite(amount))
      this.active.damage += Math.max(0, Math.trunc(amount));
  }
  kill() {
    if (this.active) this.active.kills++;
  }
  finish(result, seconds, practice = false) {
    if (!this.active) return false;
    const row = { ...this.active, result, seconds };
    this.active = null;
    if (practice || !validateRecord(row)) return false;
    this.rows = [row, ...this.rows].slice(0, 24);
    this.save();
    return true;
  }
  save() {
    try {
      this.storage().setItem(
        KEY,
        JSON.stringify({ version: 1, rows: this.rows }),
      );
      this.error = "";
      return true;
    } catch {
      this.error = "成绩仅保留在本页，保存失败";
      return false;
    }
  }
  best(chapter) {
    const times = this.rows
      .filter((r) => r.chapter === chapter && r.result === "clear")
      .map((r) => r.seconds);
    return times.length ? Math.min(...times) : null;
  }
}
export function mountRecords(records, names, doc = document) {
  const panel = doc.createElement("details");
  panel.id = "browserRecords";
  panel.style.cssText =
    "position:fixed;right:12px;bottom:64px;z-index:13;max-width:85vw;max-height:65vh;overflow:auto;background:#182126;color:#fff;padding:10px;border-radius:8px";
  const title = doc.createElement("summary");
  title.textContent = "本机成绩 · 最近24次";
  const body = doc.createElement("div");
  const retry = doc.createElement("button");
  retry.textContent = "重试保存成绩";
  function refresh() {
    body.replaceChildren();
    const status = doc.createElement("p");
    status.textContent =
      records.error ||
      "仅记录完整关卡；练习不计入。最快成绩取最近24条完赛记录。";
    body.append(status);
    retry.hidden = !records.error;
    if (!records.rows.length) {
      const empty = doc.createElement("p");
      empty.textContent = "尚无完成记录";
      body.append(empty);
    }
    for (const row of records.rows) {
      const p = doc.createElement("p");
      const best = records.best(row.chapter);
      p.textContent = `${names[row.chapter]} · ${row.result === "clear" ? "通过" : "倒下"} · ${row.seconds.toFixed(1)}秒 · 受伤${row.damage} · 击败${row.kills}${row.result === "clear" && row.seconds === best ? " · 最快" : ""}`;
      body.append(p);
    }
  }
  retry.onclick = () => {
    records.save();
    refresh();
  };
  panel.ontoggle = () => {
    if (panel.open) refresh();
  };
  panel.append(title, body, retry);
  appendUtilityPanel(panel, doc);
  refresh();
  return { refresh };
}
