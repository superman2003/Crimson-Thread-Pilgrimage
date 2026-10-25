// Pause is an overlay state, so a suspended run keeps its exact world state.
export class PauseState {
  paused = false;
  reason = "";
  pause(mode, reason = "手动暂停") {
    if (mode !== "playing" || this.paused) return false;
    this.paused = true;
    this.reason = reason;
    return true;
  }
  resume(visible = true) {
    if (!visible || !this.paused) return false;
    this.paused = false;
    this.reason = "";
    return true;
  }
}

export function mountPause({
  getMode,
  clearInput,
  root = document.body,
  win = window,
  doc = document,
}) {
  const font = doc.createElement("style");
  font.textContent = `@font-face{font-family:CrimsonBrowserPause;src:url("${new URL("../../godot/assets/fonts/NotoSansSC.ttf", import.meta.url).href}")}#browserPauseButton,#browserPauseDialog{font-family:CrimsonBrowserPause,serif}`;
  doc.head.append(font);
  const model = new PauseState();
  const button = doc.createElement("button");
  button.id = "browserPauseButton";
  button.textContent = "暂停 · Esc";
  button.style.cssText =
    "position:fixed;right:16px;bottom:16px;z-index:12;padding:10px;background:#202b2f;color:#fff;border:1px solid #c7b28c;border-radius:8px";
  const dialog = doc.createElement("dialog");
  dialog.id = "browserPauseDialog";
  dialog.setAttribute("aria-label", "旅途已暂停");
  dialog.style.cssText =
    "background:#182126;color:#f4e9d1;border:1px solid #bba680;border-radius:12px;max-width:80vw;padding:28px";
  const heading = doc.createElement("h2");
  heading.textContent = "旅途已暂停";
  const reason = doc.createElement("p");
  const resume = doc.createElement("button");
  resume.textContent = "继续旅途";
  dialog.append(heading, reason, resume);
  root.append(button, dialog);
  let previousFocus;
  function pause(message) {
    if (!model.pause(getMode(), message)) return;
    clearInput();
    previousFocus = doc.activeElement;
    reason.textContent = message;
    dialog.showModal();
    resume.focus();
  }
  function continueRun() {
    if (!model.resume(!doc.hidden)) return;
    clearInput();
    dialog.close();
    if (previousFocus?.isConnected) previousFocus.focus();
  }
  const onKey = (event) => {
    if (event.code !== "Escape" || event.repeat) return;
    // Leave other native dialogs in control of their own Escape key.
    if (!model.paused && doc.querySelector("dialog[open]")) return;
    event.preventDefault();
    model.paused ? continueRun() : pause("手动暂停");
  };
  const onHidden = () => {
    if (doc.hidden) pause("页面已切到后台，请确认后继续");
  };
  const onBlur = () => pause("窗口失去焦点，请确认后继续");
  const onCancel = (event) => {
    event.preventDefault();
    continueRun();
  };
  win.addEventListener("keydown", onKey);
  win.addEventListener("blur", onBlur);
  doc.addEventListener("visibilitychange", onHidden);
  dialog.addEventListener("cancel", onCancel);
  button.addEventListener("click", () => pause("手动暂停"));
  resume.addEventListener("click", continueRun);
  return {
    get paused() {
      return model.paused;
    },
    refresh() {
      button.hidden = getMode() !== "playing";
    },
    destroy() {
      win.removeEventListener("keydown", onKey);
      win.removeEventListener("blur", onBlur);
      doc.removeEventListener("visibilitychange", onHidden);
      if (dialog.open) dialog.close();
      font.remove();
      dialog.remove();
      button.remove();
    },
  };
}
