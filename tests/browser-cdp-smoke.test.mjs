import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { createStaticServer } from "../server.js";

const chrome = findChrome();

if (!chrome) {
  console.log("browser-cdp-smoke.test: SKIP (Chrome not found)");
  process.exit(0);
}

mkdirSync("artifacts", { recursive: true });

const server = createStaticServer();
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const { port: appPort } = server.address();
const debugPort = 9400 + Math.floor(Math.random() * 400);
const userDataDir = mkdtempSync(join(tmpdir(), "crimson-thread-chrome-"));
const chromeProcess = spawn(chrome, [
  "--headless=new",
  "--disable-gpu",
  "--hide-scrollbars",
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${userDataDir}`,
  "--window-size=1280,720",
  "about:blank"
], { stdio: "ignore" });

try {
  await waitForChrome(debugPort);
  const target = await fetchJson(`http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(`http://127.0.0.1:${appPort}/`)}`, {
    method: "PUT"
  });
  const client = await connectCdp(target.webSocketDebuggerUrl);
  try {
    await client.send("Page.enable");
    await client.send("Runtime.enable");
    await waitForQaHook(client);

    const first = await evaluate(client, "window.__crimsonThreadQA.startChapter(0)");
    assert.equal(first.mode, "playing", "chapter 1 must start");
    assert.equal(first.chapterIndex, 0, "chapter 1 index must be active");
    assert.ok(first.enemyCount >= 5, "chapter 1 must spawn normal enemies");
    assert.equal(first.keys, 0, "chapter must start with zero keys");
    assert.equal(first.totalKeys, 3, "chapter must expose three key pickups");
    assert.equal(first.shortcutOpen, false, "shortcut must start closed");
    assert.equal(first.hitStop, 0, "hit stop must start inactive");
    assert.equal(typeof first.playerX, "number", "snapshot must expose playerX");

    const bodyText = await evaluate(client, "document.body.innerText");
    assert.doesNotMatch(bodyText, /鑻|缁|绛|寮€|鈫|銆|锛|闂|鍙|鍊|瀹|�/, "page text must not contain mojibake");
    assert.doesNotMatch(bodyText, /Hollow Knight|Silksong|Team Cherry|空洞骑士|丝之歌/i, "runtime page must not contain protected inspiration IP names");

    const metrics = await waitForVisualReady(client);
    assert.match(metrics.heroIdlePath, /generated_hero_v2\/frames\/idle_00\.png/, "hero must use generated v2 frame path");
    assert.deepEqual(metrics.heroFrameSize, { width: 192, height: 192 }, "hero frame source must be 192x192");
    assert.equal(metrics.loadedHeroFrames, metrics.totalHeroFrames, "all hero frames must load");
    assert.deepEqual(metrics.playerCollision, { w: 34, h: 54 }, "collision box must keep gameplay size");
    assert.deepEqual(metrics.playerVisual, { w: 128, h: 128, yOffset: 9 }, "visual hero size must be high resolution");

    const sample = await samplePlayerPixels(client);
    assert.ok(sample.brightPixels > 30, `hero sample should include bright mask pixels: ${JSON.stringify(sample)}`);
    assert.ok(sample.uniqueBins > 12, `hero sample should have color detail: ${JSON.stringify(sample)}`);

    const keyed = await evaluate(client, "window.__crimsonThreadQA.collectAllKeys()");
    assert.equal(keyed.keys, 3, "QA key collection must collect all three keys");
    assert.match(keyed.lastEvent, /钟钥 3\/3/, "key collection must update lastEvent");
    const shortcut = await evaluate(client, "window.__crimsonThreadQA.openShortcut()");
    assert.equal(shortcut.shortcutOpen, true, "shortcut must open after all keys");
    const afterShortcutMetrics = await evaluate(client, "window.__crimsonThreadQA.visualMetrics()");
    assert.equal(afterShortcutMetrics.shortcutPlatforms, 1, "shortcut bridge must become a collision platform");
    const hit = await evaluate(client, "window.__crimsonThreadQA.strikeFirstEnemy()");
    assert.ok(hit.hitStop > 0, "striking an enemy must trigger hit stop");
    assert.match(hit.lastEvent, /受击/, "hit must update lastEvent");

    const advanced = await evaluate(client, "window.__crimsonThreadQA.completeChapter()");
    assert.equal(advanced.mode, "playing", "chapter clear must advance into gameplay");
    assert.equal(advanced.chapterIndex, 1, "chapter clear must advance to chapter 2");
    assert.ok(advanced.unlocked >= 2, "chapter clear must unlock chapter 2");

    const finale = await evaluate(client, "window.__crimsonThreadQA.startChapter(5)");
    assert.equal(finale.chapterIndex, 5, "QA must be able to start the finale chapter");
    await waitForVisualReady(client);

    const desktopPath = "artifacts/browser-cdp-playing.png";
    await writeScreenshot(client, desktopPath);

    await client.send("Emulation.setDeviceMetricsOverride", {
      width: 390,
      height: 844,
      deviceScaleFactor: 2,
      mobile: true
    });
    await delay(500);
    const mobilePath = "artifacts/browser-cdp-mobile.png";
    await writeScreenshot(client, mobilePath);

    console.log(`browser-cdp-smoke.test: PASS screenshots=${desktopPath},${mobilePath}`);
  } finally {
    client.close();
  }
} finally {
  chromeProcess.kill();
  await waitForProcessExit(chromeProcess, 1600);
  await new Promise((resolve) => server.close(resolve));
  rmSync(userDataDir, { recursive: true, force: true, maxRetries: 8, retryDelay: 180 });
}

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
  ].filter(Boolean);
  return candidates.find((candidate) => existsSync(candidate));
}

async function waitForChrome(port) {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    try {
      await fetchJson(`http://127.0.0.1:${port}/json/version`);
      return;
    } catch {
      await delay(160);
    }
  }
  throw new Error("Chrome DevTools did not start in time");
}

async function waitForQaHook(client) {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    const value = await evaluate(client, "typeof window.__crimsonThreadQA");
    if (value === "object") return;
    await delay(120);
  }
  throw new Error("QA hook did not become ready");
}

async function waitForVisualReady(client) {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
    const metrics = await evaluate(client, "window.__crimsonThreadQA.visualMetrics()");
    if (
      metrics.loadedHeroFrames === metrics.totalHeroFrames
      && metrics.heroFrameSize.width === 192
      && metrics.heroFrameSize.height === 192
      && metrics.playerRect
    ) {
      await delay(180);
      return metrics;
    }
    await delay(140);
  }
  throw new Error("hero visuals did not load in time");
}

async function samplePlayerPixels(client) {
  return evaluate(client, `(() => {
    const canvas = document.querySelector("#game");
    const context = canvas.getContext("2d");
    const metrics = window.__crimsonThreadQA.visualMetrics();
    const scaleX = canvas.width / 960;
    const scaleY = canvas.height / 540;
    const x = Math.max(0, Math.floor(metrics.playerRect.x * scaleX));
    const y = Math.max(0, Math.floor(metrics.playerRect.y * scaleY));
    const w = Math.max(1, Math.min(canvas.width - x, Math.ceil(metrics.playerRect.w * scaleX)));
    const h = Math.max(1, Math.min(canvas.height - y, Math.ceil(metrics.playerRect.h * scaleY)));
    const data = context.getImageData(x, y, w, h).data;
    const bins = new Set();
    let brightPixels = 0;
    for (let i = 0; i < data.length; i += 16) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const a = data[i + 3];
      if (a === 0) continue;
      if (r + g + b > 420) brightPixels += 1;
      bins.add(\`\${r >> 4},\${g >> 4},\${b >> 4}\`);
    }
    return { brightPixels, uniqueBins: bins.size, sampleWidth: w, sampleHeight: h };
  })()`);
}

async function writeScreenshot(client, path) {
  const screenshot = await client.send("Page.captureScreenshot", { format: "png" });
  writeFileSync(path, Buffer.from(screenshot.data, "base64"));
  assert.ok(existsSync(path), `screenshot must be written: ${path}`);
}

async function fetchJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) throw new Error(`${url} -> ${response.status}`);
  return response.json();
}

function connectCdp(url) {
  const socket = new WebSocket(url);
  let nextId = 1;
  const pending = new Map();

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (!message.id || !pending.has(message.id)) return;
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(message.error.message));
    else resolve(message.result);
  });

  return new Promise((resolve, reject) => {
    socket.addEventListener("open", () => {
      resolve({
        send(method, params = {}) {
          const id = nextId;
          nextId += 1;
          socket.send(JSON.stringify({ id, method, params }));
          return new Promise((innerResolve, innerReject) => {
            pending.set(id, { resolve: innerResolve, reject: innerReject });
          });
        },
        close() {
          socket.close();
        }
      });
    });
    socket.addEventListener("error", reject);
  });
}

async function evaluate(client, expression) {
  const result = await client.send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true
  });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.text || "Runtime.evaluate failed");
  }
  return result.result.value;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function waitForProcessExit(child, timeout) {
  if (child.exitCode !== null || child.signalCode !== null) return Promise.resolve();
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, timeout);
    child.once("exit", () => {
      clearTimeout(timer);
      resolve();
    });
  });
}
