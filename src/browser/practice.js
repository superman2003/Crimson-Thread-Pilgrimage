import { appendUtilityPanel } from "./utility-panel.js";
export function allowedPractice(index, unlocked, count) {
  return (
    Number.isInteger(index) && index >= 0 && index < count && index < unlocked
  );
}
export function mountPractice({
  chapters,
  getUnlocked,
  start,
  doc = document,
}) {
  const panel = doc.createElement("details");
  panel.id = "browserPractice";
  panel.style.cssText =
    "position:fixed;right:12px;bottom:110px;z-index:13;max-width:85vw;background:#182126;color:#fff;padding:8px;border-radius:8px";
  const title = doc.createElement("summary");
  title.textContent = "守卫练习";
  const help = doc.createElement("p");
  help.textContent =
    "练习已解锁章节的守卫，保留正常伤害；胜败均不解锁下一章，也不计入完整关卡成绩。";
  const select = doc.createElement("select");
  select.setAttribute("aria-label", "练习章节");
  chapters.forEach((chapter, i) => {
    const o = doc.createElement("option");
    o.value = String(i);
    o.textContent = chapter.name;
    select.append(o);
  });
  const launch = doc.createElement("button");
  launch.textContent = "开始守卫练习";
  const status = doc.createElement("p");
  status.setAttribute("role", "status");
  function refresh() {
    for (const option of select.options)
      option.disabled = Number(option.value) >= getUnlocked();
    if (Number(select.value) >= getUnlocked()) select.value = "0";
  }
  panel.ontoggle = () => {
    if (panel.open) refresh();
  };
  launch.onclick = () => {
    const index = Number(select.value);
    if (!allowedPractice(index, getUnlocked(), chapters.length)) {
      status.textContent = "此章节尚未解锁";
      return;
    }
    if (!window.confirm("开始守卫练习会结束当前尝试。继续？")) return;
    start(index);
    panel.open = false;
  };
  panel.append(title, help, select, launch, status);
  appendUtilityPanel(panel, doc);
  refresh();
  return { refresh };
}
