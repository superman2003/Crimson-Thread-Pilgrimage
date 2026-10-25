// Each feature PR carries this identical shared host so it also works alone.
// Native details controls keep keyboard navigation available without a UI library.
export function appendUtilityPanel(panel, doc = document) {
  let dock = doc.getElementById("browserUtilityDock");
  if (!dock) {
    dock = doc.createElement("nav");
    dock.id = "browserUtilityDock";
    dock.setAttribute("aria-label", "试玩工具");
    const style = doc.createElement("style");
    style.id = "browserUtilityStyle";
    style.textContent = `
      @font-face{font-family:"CrimsonBrowserUI";src:url("${new URL("../../godot/assets/fonts/NotoSansSC.ttf", import.meta.url).href}") format("truetype");font-display:swap}
      #browserUtilityDock{position:fixed;inset:0 0 auto;z-index:20;display:flex;flex-wrap:wrap;justify-content:flex-end;gap:6px;padding:6px 10px;background:#142026;color:#f4e9d1;font:13px "CrimsonBrowserUI","FengMingGlobal",serif}
      #browserUtilityDock details{position:static!important;padding:0!important;background:transparent!important}
      #browserUtilityDock summary{cursor:pointer;padding:6px;border:1px solid #698080;border-radius:6px;list-style-position:inside}
      #browserUtilityDock summary:focus-visible,#browserUtilityDock button:focus-visible{outline:3px solid #ffe093;outline-offset:2px}
      #browserUtilityDock .browser-utility-content{position:absolute;right:8px;top:100%;width:min(520px,calc(100vw - 16px));max-height:65vh;overflow:auto;padding:16px;background:#142026;border:1px solid #a9bdb1;border-radius:8px;box-shadow:0 6px 24px #0009;line-height:1.6;box-sizing:border-box}
      #browserUtilityDock button,#browserUtilityDock select{font:inherit;padding:6px;margin:4px;border-radius:4px}
      #browserUtilityDock canvas{max-width:100%}
      .hud{top:52px}
      @media(max-width:760px){#browserUtilityDock{font-size:12px;gap:3px}#browserUtilityDock summary{padding:4px}.hud{top:88px}.menu__inner{max-height:65vh;overflow:auto}.touch-controls{bottom:72px}}
    `;
    doc.head.append(style);
    doc.body.append(dock);
  }
  const content = doc.createElement("div");
  content.className = "browser-utility-content";
  for (const child of [...panel.children])
    if (child.tagName !== "SUMMARY") content.append(child);
  panel.append(content);
  panel.removeAttribute("style");
  panel.addEventListener("keydown", (event) => event.stopPropagation());
  panel.addEventListener("toggle", () => {
    if (panel.open)
      for (const other of dock.querySelectorAll("details"))
        if (other !== panel) other.open = false;
  });
  dock.append(panel);
  return content;
}
