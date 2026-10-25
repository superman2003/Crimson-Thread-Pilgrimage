import { appendUtilityPanel } from "./utility-panel.js";
export const GUIDE_SECTIONS = [
  [
    "键盘",
    "A/D 或 ←/→ 移动；空格/W/↑ 跳跃；Shift/K 冲刺；J/X 挥刃；R 重试当前关卡。",
  ],
  [
    "触控",
    "屏幕底部五键分别为左、右、跳、冲刺、攻击。移动时可同时按跳跃或攻击。",
  ],
  [
    "目标",
    "先沿平台收集三枚钟钥，再触碰末段机关打开捷径；击败守卫后前往最右侧出口。",
  ],
  [
    "战斗",
    "观察守卫预备动作，用冲刺脱离危险区。冲刺和挥刃有冷却；跳跃可短按控制高度。",
  ],
  [
    "重试与保存",
    "倒下后可从章节菜单重新挑战。浏览器试玩仅保存章节解锁，不保存关卡中的位置、敌人或钥匙。Godot 存档独立。",
  ],
];
export function hudDescription(state) {
  if (!state.player) return "尚未开始旅途";
  const p = state.player,
    b = state.boss;
  return `生命 ${Math.max(0, p.health)} / ${p.maxHealth}；钟钥 ${state.keys} / ${state.keyPickups.length}；${state.shortcutOpen ? "捷径已开" : "捷径未开"}；${b?.dead ? "守卫已击败" : `守卫生命 ${Math.max(0, b?.hp ?? 0)} / ${b?.maxHp ?? 0}`}`;
}
export function mountGuide(doc = document) {
  const style = doc.createElement("style");
  style.textContent = `@font-face{font-family:CrimsonBrowserGuide;src:url("${new URL("../../godot/assets/fonts/NotoSansSC.ttf", import.meta.url).href}")} .hud,.menu{font-family:CrimsonBrowserGuide,serif} ` +
    ".browser-sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap}.menu{overflow-y:auto}.menu__inner{max-height:88vh;overflow:auto}#game:focus-visible{outline:3px solid #ffdf92;outline-offset:-4px}";
  doc.head.append(style);
  const canvas = doc.querySelector("#game");
  canvas.tabIndex = 0;
  canvas.setAttribute("role", "img");
  canvas.setAttribute("aria-label", "绯线远征实时游戏画面");
  canvas.setAttribute("aria-describedby", "browserHudDescription");
  // Avoid announcing the entire changing HUD every animation frame.
  doc.querySelector("#hud")?.removeAttribute("aria-live");
  const description = doc.createElement("p");
  description.id = "browserHudDescription";
  description.className = "browser-sr-only";
  const live = doc.createElement("p");
  live.className = "browser-sr-only";
  live.setAttribute("role", "status");
  live.setAttribute("aria-live", "polite");
  const panel = doc.createElement("details");
  panel.id = "browserGuide";
  panel.style.cssText =
    "position:fixed;right:12px;bottom:156px;z-index:13;max-width:85vw;background:#182126;color:#fff;padding:8px;border-radius:8px";
  const title = doc.createElement("summary");
  title.textContent = "操作与玩法指引";
  panel.append(title);
  for (const [heading, text] of GUIDE_SECTIONS) {
    const h = doc.createElement("h3");
    h.textContent = heading;
    const p = doc.createElement("p");
    p.textContent = text;
    panel.append(h, p);
  }
  const read = doc.createElement("button");
  read.textContent = "播报当前状态";
  read.onclick = () => {
    live.textContent = description.textContent;
  };
  panel.append(read);
  appendUtilityPanel(panel, doc);
  doc.body.append(description, live);
  let signature = "",
    lastMode = "";
  return {
    update(state) {
      const next = hudDescription(state);
      if (next !== signature) {
        description.textContent = next;
        signature = next;
      }
      if (state.mode !== lastMode) {
        live.textContent =
          state.mode === "playing"
            ? "旅途开始。可打开操作与玩法指引。"
            : state.player?.health === 0
              ? "本次倒下，可选择章节重试。"
              : "请选择已解锁章节开始旅途。";
        lastMode = state.mode;
      }
    },
  };
}
