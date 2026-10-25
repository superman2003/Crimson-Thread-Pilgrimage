const ACTIONS = ["left", "right", "jump", "dash", "attack"];
export function readStandardPad(pad, previous = {}) {
  const active = Object.fromEntries(ACTIONS.map((a) => [a, false]));
  if (!pad?.connected || pad.mapping !== "standard") return active;
  const button = (i) => pad.buttons?.[i]?.pressed === true;
  const x = Number.isFinite(pad.axes?.[0]) ? pad.axes[0] : 0;
  // Hysteresis avoids generating repeated presses near the deadzone.
  active.left = button(14) || x < -(previous.left ? 0.2 : 0.3);
  active.right = button(15) || x > (previous.right ? 0.2 : 0.3);
  active.jump = button(0);
  active.attack = button(2);
  active.dash = button(1) || button(5);
  return active;
}
export class GamepadInput {
  previous = {};
  waitingForRelease = true;
  reset() {
    this.previous = {};
    this.waitingForRelease = true;
  }
  merge(base, pads, enabled = true) {
    const pad = Array.from(pads || []).find(
      (p) => p?.connected && p.mapping === "standard",
    );
    let current = readStandardPad(pad, this.previous);
    if (!enabled) {
      this.reset();
      current = readStandardPad(null);
    } else if (this.waitingForRelease) {
      if (!Object.values(current).some(Boolean)) this.waitingForRelease = false;
      current = readStandardPad(null);
    }
    const merged = { ...base };
    for (const action of ACTIONS) {
      merged[action] = !!base[action] || current[action];
      if (["jump", "dash", "attack"].includes(action))
        merged[`${action}Pressed`] =
          !!base[`${action}Pressed`] ||
          (current[action] && !this.previous[action] && !base[action]);
    }
    merged.jumpReleased =
      (!!base.jumpReleased && !current.jump) ||
      (!!this.previous.jump && !current.jump && !base.jump);
    this.previous = current;
    return merged;
  }
}
export function mountGamepad(win = window, doc = document) {
  const input = new GamepadInput();
  const label = doc.createElement("div");
  label.id = "browserGamepad";
  label.setAttribute("role", "status");
  label.style.cssText =
    "position:fixed;right:12px;top:12px;z-index:11;max-width:40vw;background:#182126;color:#fff;padding:6px;border-radius:6px";
  doc.body.append(label);
  const reset = () => input.reset();
  win.addEventListener("blur", reset);
  win.addEventListener("gamepadconnected", reset);
  win.addEventListener("gamepaddisconnected", reset);
  let previousLabel = "";
  return {
    read(base) {
      let pads = [];
      try {
        pads = win.navigator.getGamepads?.() || [];
      } catch {}
      const pad = Array.from(pads).find((p) => p?.connected);
      const text = pad
        ? pad.mapping === "standard"
          ? "手柄：左摇杆/十字键移动 · A 跳 · X 攻击 · B/RB 冲刺"
          : "此手柄未提供标准映射，请使用键盘或触控"
        : "";
      if (text !== previousLabel) {
        label.textContent = text;
        label.hidden = !text;
        previousLabel = text;
      }
      return input.merge(
        base,
        pads,
        !doc.hidden && !doc.querySelector("dialog[open]"),
      );
    },
  };
}
