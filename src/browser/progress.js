export const PROGRESS_KEY = "crimson-thread-unlocked";
export function parseUnlocks(raw, count) {
  if (raw == null || raw === "") return 1;
  if (!/^\d+$/.test(raw)) return 1;
  const n = Number(raw);
  return Number.isSafeInteger(n) && n >= 1 && n <= count ? n : 1;
}
export class ProgressStore {
  constructor(storage, count) {
    this.storage = storage;
    this.count = count;
    this.error = "";
  }
  read() {
    try {
      return parseUnlocks(this.storage().getItem(PROGRESS_KEY), this.count);
    } catch {
      this.error = "无法读取本机进度，本次仍可游玩";
      return 1;
    }
  }
  save(value, reset = false) {
    if (!Number.isInteger(value) || value < 1 || value > this.count)
      return false;
    try {
      const target = reset ? value : Math.max(value, this.read());
      const storage = this.storage();
      storage.setItem(PROGRESS_KEY, String(target));
      if (storage.getItem(PROGRESS_KEY) !== String(target))
        throw Error("write verification");
      this.error = "";
      return true;
    } catch {
      this.error = "进度未保存：本机存储不可用，请保持页面打开并重试";
      return false;
    }
  }
}
export function mountProgressStatus(store, retry, doc = document) {
  const notice = doc.createElement("div");
  notice.id = "browserProgressStatus";
  notice.setAttribute("role", "status");
  notice.style.cssText =
    "position:fixed;left:12px;bottom:76px;max-width:80vw;z-index:18;background:#352b27;color:#fff;padding:8px;border-radius:8px";
  const text = doc.createElement("span");
  const button = doc.createElement("button");
  button.textContent = "重试保存";
  notice.append(text, button);
  doc.body.append(notice);
  button.onclick = () => {
    retry();
    refresh();
  };
  function refresh() {
    text.textContent = store.error;
    notice.hidden = !store.error;
  }
  refresh();
  return { refresh };
}
