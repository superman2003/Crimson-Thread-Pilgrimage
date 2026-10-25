export const ACTIONS = ["left", "right", "jump", "dash", "attack"];
export function editableTarget(target) {
  return !!target?.closest?.(
    'input,textarea,select,[contenteditable="true"],dialog[open],button,summary',
  );
}
// A held action belongs to physical sources, not the most recent event.
export class InputSources {
  sources = new Map();
  constructor(emit) {
    this.emit = emit;
  }
  set(source, action, pressed) {
    if (!ACTIONS.includes(action)) return;
    const before = this.active(action);
    if (pressed) this.sources.set(source, action);
    else this.sources.delete(source);
    const after = this.active(action);
    if (before !== after) this.emit(action, after);
  }
  active(action) {
    return [...this.sources.values()].includes(action);
  }
  clear() {
    const active = new Set(this.sources.values());
    this.sources.clear();
    for (const action of active) this.emit(action, false);
  }
}
export function mountPointers(buttons, sources, win = window) {
  const remove = [];
  for (const button of buttons) {
    button.style.touchAction = "none";
    button.setAttribute(
      "aria-label",
      {
        left: "向左",
        right: "向右",
        jump: "跳跃",
        dash: "冲刺",
        attack: "挥刃",
      }[button.dataset.key],
    );
    const down = (event) => {
      event.preventDefault();
      button.setPointerCapture?.(event.pointerId);
      sources.set(`pointer:${event.pointerId}`, button.dataset.key, true);
    };
    const up = (event) => {
      sources.set(`pointer:${event.pointerId}`, button.dataset.key, false);
    };
    button.addEventListener("pointerdown", down);
    for (const name of ["pointerup", "pointercancel", "lostpointercapture"])
      button.addEventListener(name, up);
    remove.push(() => {
      button.removeEventListener("pointerdown", down);
      for (const name of ["pointerup", "pointercancel", "lostpointercapture"])
        button.removeEventListener(name, up);
    });
  }
  const clear = () => sources.clear();
  win.addEventListener("blur", clear);
  return () => {
    clear();
    remove.forEach((fn) => fn());
    win.removeEventListener("blur", clear);
  };
}
