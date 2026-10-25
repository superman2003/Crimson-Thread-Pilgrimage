import { appendUtilityPanel } from "./utility-panel.js";
export function mapGeometry(chapter, width, height, worldWidth, worldHeight) {
  const scale = width / worldWidth;
  const rect = (x, y, w, h) => ({
    x: x * scale,
    y: (y * height) / worldHeight,
    w: w * scale,
    h: Math.max(2, (h * height) / worldHeight),
  });
  return {
    platforms: (chapter.platforms || []).map((p) => rect(...p)),
    hazards: (chapter.hazards || []).map((p) => rect(p.x, p.y, p.w, p.h)),
    exit: rect(chapter.exit.x, chapter.exit.y, 64, 84),
    scale,
  };
}
export function mapObjectives(chapter, state) {
  const items = (state.keyPickups || [])
    .filter((k) => !k.taken)
    .map((k) => ({ kind: "钟钥", x: k.x, y: k.y }));
  if (!state.shortcutOpen && chapter.shortcut?.lever)
    items.push({ kind: "捷径机关", ...chapter.shortcut.lever });
  if (state.boss && !state.boss.dead)
    items.push({ kind: "守卫", x: state.boss.x, y: state.boss.y });
  items.push({
    kind: state.boss?.dead ? "已开放出口" : "守卫封锁的出口",
    x: chapter.exit.x,
    y: chapter.exit.y,
  });
  return items;
}
export function mountMap(doc = document, win = window) {
  const panel = doc.createElement("details");
  panel.id = "browserRouteMap";
  panel.style.cssText =
    "position:fixed;left:12px;bottom:12px;z-index:12;max-width:85vw;background:#182126;color:#fff;padding:8px;border-radius:8px";
  const title = doc.createElement("summary");
  title.textContent = "关卡路线 · M";
  const text = doc.createElement("p");
  text.textContent =
    "实时示意：浅色路面、红色危险、金色目标、白色玩家；地图不会暂停。";
  const canvas = doc.createElement("canvas");
  canvas.width = 560;
  canvas.height = 120;
  canvas.setAttribute("role", "img");
  canvas.style.cssText =
    "display:block;width:min(560px,75vw);height:auto;background:#0c1418";
  const list = doc.createElement("p");
  list.style.maxWidth = "560px";
  panel.append(title, text, canvas, list);
  appendUtilityPanel(panel, doc);
  win.addEventListener("keydown", (event) => {
    if (
      event.code === "KeyM" &&
      !event.repeat &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.altKey &&
      !event.target.closest?.("input,textarea,select,button,dialog[open]")
    ) {
      event.preventDefault();
      panel.open = !panel.open;
    }
  });
  const ctx = canvas.getContext("2d");
  let signature = "";
  return {
    draw(chapter, state, settings) {
      panel.hidden = state.mode !== "playing";
      if (!panel.open || panel.hidden) return;
      const g = mapGeometry(
        chapter,
        560,
        120,
        settings.levelWidth,
        settings.height,
      );
      ctx.clearRect(0, 0, 560, 120);
      ctx.fillStyle = "#334c58";
      ctx.fillRect(state.cameraX * g.scale, 0, settings.width * g.scale, 120);
      ctx.fillStyle = "#b7d5d0";
      for (const r of g.platforms) ctx.fillRect(r.x, r.y, r.w, r.h);
      ctx.fillRect(0, (settings.floorY / settings.height) * 120, 560, 3);
      ctx.fillStyle = "#ec7878";
      for (const r of g.hazards) ctx.fillRect(r.x, r.y, r.w, r.h);
      const objectives = mapObjectives(chapter, state);
      ctx.fillStyle = "#ffdd82";
      for (const o of objectives) {
        ctx.beginPath();
        ctx.arc(
          o.x * g.scale,
          (o.y / settings.height) * 120,
          3,
          0,
          Math.PI * 2,
        );
        ctx.fill();
      }
      if (state.player) {
        ctx.fillStyle = "#fff";
        ctx.fillRect(
          state.player.x * g.scale - 2,
          (state.player.y / settings.height) * 120 - 4,
          4,
          8,
        );
      }
      const description = `${chapter.name}：${objectives.map((o) => `${o.kind} ${Math.round((o.x / settings.levelWidth) * 100)}%`).join("；")}`;
      if (description !== signature) {
        list.textContent = description;
        canvas.setAttribute("aria-label", description);
        signature = description;
      }
    },
  };
}
