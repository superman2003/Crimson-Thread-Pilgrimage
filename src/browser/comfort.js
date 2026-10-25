import { appendUtilityPanel } from "./utility-panel.js";
const KEY = "crimson-browser-comfort-v1";
export function normalizeComfort(value, reduced = false) {
  return {
    reduced: typeof value?.reduced === "boolean" ? value.reduced : reduced,
    shake: value?.shake !== false,
    particles: value?.particles !== false,
    contrast: value?.contrast === true,
  };
}
export class ComfortPreferences {
  constructor(storage, systemReduced = false) {
    this.storage = storage;
    this.systemReduced = systemReduced;
    this.value = normalizeComfort(null, systemReduced);
    this.saved = false;
    try {
      const raw = storage().getItem(KEY);
      if (raw) {
        this.value = normalizeComfort(JSON.parse(raw), systemReduced);
        this.saved = true;
      }
    } catch {}
  }
  set(patch) {
    this.value = normalizeComfort(
      { ...this.value, ...patch },
      this.systemReduced,
    );
    try {
      this.storage().setItem(KEY, JSON.stringify(this.value));
      this.saved = true;
      return true;
    } catch {
      return false;
    }
  }
  get shake() {
    return this.value.shake && !this.value.reduced;
  }
  get particles() {
    return this.value.particles && !this.value.reduced;
  }
  systemChanged(reduced) {
    this.systemReduced = reduced;
    if (!this.saved) this.value.reduced = reduced;
  }
}
export function mountComfort(preferences, doc = document, win = window) {
  const panel = doc.createElement("details");
  panel.id = "browserComfort";
  panel.style.cssText =
    "position:fixed;left:12px;top:58px;z-index:14;background:#182126;color:#f4e9d1;padding:8px;border-radius:8px;max-width:85vw";
  const title = doc.createElement("summary");
  title.textContent = "视觉舒适";
  panel.append(title);
  const status = doc.createElement("span");
  status.setAttribute("role", "status");
  const controls = new Map();
  const refresh = () => {
    for (const [key, input] of controls) input.checked = preferences.value[key];
    doc.documentElement.classList.toggle(
      "browser-high-contrast",
      preferences.value.contrast,
    );
  };
  for (const [key, name] of [
    ["reduced", "减少动态（关闭震动/粒子/背景漂移）"],
    ["shake", "镜头震动"],
    ["particles", "装饰粒子"],
    ["contrast", "高对比界面"],
  ]) {
    const label = doc.createElement("label");
    label.style.display = "block";
    const input = doc.createElement("input");
    input.type = "checkbox";
    input.onchange = () => {
      status.textContent = preferences.set({ [key]: input.checked })
        ? "已保存"
        : "本次生效，偏好未保存";
      refresh();
    };
    controls.set(key, input);
    label.append(input, doc.createTextNode(name));
    panel.append(label);
  }
  const css = doc.createElement("style");
  css.textContent =
    ".browser-high-contrast .hud,.browser-high-contrast .menu__inner{background:#090e11!important;color:#fff!important;border:2px solid #fff}.browser-high-contrast button:focus-visible{outline:3px solid #ffe193;outline-offset:3px}";
  const query = win.matchMedia?.("(prefers-reduced-motion: reduce)");
  query?.addEventListener("change", (event) => {
    preferences.systemChanged(event.matches);
    refresh();
  });
  panel.append(status);
  doc.head.append(css);
  appendUtilityPanel(panel, doc);
  refresh();
}
