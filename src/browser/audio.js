import { appendUtilityPanel } from "./utility-panel.js";
export const AUDIO_KEY = "crimson-browser-audio-v1";
export function normalizeAudio(value) {
  return {
    volume:
      typeof value?.volume === "number" && Number.isFinite(value.volume)
        ? Math.max(0, Math.min(1, value.volume))
        : 0.7,
    muted: value?.muted === true,
  };
}
export class AudioPreferences {
  voices = new Set();
  constructor(storage) {
    this.storage = storage;
    this.value = normalizeAudio(null);
    this.error = "";
    try {
      this.value = normalizeAudio(JSON.parse(storage().getItem(AUDIO_KEY)));
    } catch {
      /* defaults */
    }
  }
  get gain() {
    return this.value.muted ? 0 : this.value.volume;
  }
  set(next) {
    this.value = normalizeAudio({ ...this.value, ...next });
    for (const voice of this.voices) voice.volume = voice.base * this.gain;
    try {
      this.storage().setItem(AUDIO_KEY, JSON.stringify(this.value));
      this.error = "";
    } catch {
      this.error = "本次生效，音量偏好未保存";
    }
  }
  track(element, base) {
    // Keep at most twelve simultaneous clips, retiring the oldest first.
    if (this.voices.size >= 12) {
      const old = this.voices.values().next().value;
      old.element.pause();
      this.voices.delete(old);
    }
    const voice = {
      element,
      base,
      set volume(n) {
        element.volume = n;
      },
    };
    element.volume = base * this.gain;
    this.voices.add(voice);
    const cleanup = () => this.voices.delete(voice);
    element.addEventListener("ended", cleanup, { once: true });
    element.addEventListener("error", cleanup, { once: true });
    return cleanup;
  }
  silence() {
    for (const voice of this.voices) voice.element.pause();
    this.voices.clear();
  }
}
export function mountAudio(preferences, doc = document) {
  const panel = doc.createElement("details");
  panel.id = "browserAudio";
  panel.style.cssText =
    "position:fixed;left:12px;top:12px;z-index:15;background:#182126;color:#f4e9d1;padding:8px;border-radius:8px";
  const summary = doc.createElement("summary");
  summary.textContent = "声音设置";
  const label = doc.createElement("label");
  label.textContent = "音量 ";
  const slider = doc.createElement("input");
  slider.type = "range";
  slider.min = "0";
  slider.max = "100";
  slider.step = "1";
  slider.value = String(preferences.value.volume * 100);
  const output = doc.createElement("output");
  const mute = doc.createElement("button");
  mute.type = "button";
  const status = doc.createElement("span");
  status.setAttribute("role", "status");
  function refresh() {
    output.textContent = `${Math.round(preferences.value.volume * 100)}%`;
    mute.textContent = preferences.value.muted ? "取消静音" : "静音";
    mute.setAttribute("aria-pressed", String(preferences.value.muted));
    status.textContent = preferences.error;
  }
  slider.oninput = () => {
    preferences.set({ volume: Number(slider.value) / 100 });
    refresh();
  };
  mute.onclick = () => {
    preferences.set({ muted: !preferences.value.muted });
    refresh();
  };
  label.append(slider, output);
  panel.append(summary, label, mute, status);
  appendUtilityPanel(panel, doc);
  refresh();
}
