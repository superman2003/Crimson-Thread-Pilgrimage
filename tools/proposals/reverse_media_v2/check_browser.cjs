/* Optional real-browser checks. Requires Playwright + Chromium outside this repo.
 * Serve the repository locally, then:
 * node tools/proposals/reverse_media_v2/check_browser.cjs http://127.0.0.1:8765
 * CHROMIUM_EXECUTABLE can point at an existing official Chromium installation.
 * MEDIA_QA_OUTPUT optionally stores screenshots and a compact report.
 */
"use strict";
const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

(async () => {
  const origin = process.argv[2] || "http://127.0.0.1:8765";
  const out = process.env.MEDIA_QA_OUTPUT;
  if (out) fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ headless: true,
    executablePath: process.env.CHROMIUM_EXECUTABLE || undefined,
    args: ["--no-sandbox", "--mute-audio", "--autoplay-policy=no-user-gesture-required"] });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1050 }, reducedMotion: "reduce" });
  const errors = [], failedRequests = [], checks = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("requestfailed", request => {
    // Switching a track intentionally cancels an unfinished old media request.
    if (request.failure()?.errorText !== "net::ERR_ABORTED") failedRequests.push(request.url());
  });
  const check = (name, value) => { assert.ok(value, name); checks.push(name); };
  const noMessage = async () => check("selected asset has no load error", (await page.locator("#message").innerText()) === "");
  try {
    await page.goto(`${origin}/docs/proposals/reverse_media_v2/`);
    await page.waitForFunction(() => !document.getElementById("play").disabled);
    check("27 entries in catalog", await page.evaluate(() => MEDIA_CATALOG.packs.flatMap(p => p.items).length === 27));
    check("9 motion entries", await page.locator("#items button").count() === 9);
    check("animation initially paused", await page.locator("#play").innerText() === "播放");
    await page.locator("#filter").selectOption("crimson");
    check("crest filter has 3 entries", await page.locator("#items button").count() === 3);
    await page.waitForFunction(() => !document.getElementById("next").disabled);
    await page.locator("#next").click();
    check("step advances one frame", await page.locator("#frame").inputValue() === "1");
    await page.locator("#previous").click();
    check("step rewinds one frame", await page.locator("#frame").inputValue() === "0");
    await page.locator("#play").click();
    await page.waitForFunction(() => document.getElementById("play").textContent === "播放" && document.getElementById("frame").value === "7");
    checks.push("single-shot animation stops at final frame");
    await page.locator("#frame").evaluate(input => { input.value = "3"; input.dispatchEvent(new Event("input", { bubbles: true })); });
    check("contact event highlighted", await page.locator("#events .active").count() === 1);
    if (out) await page.screenshot({ path: path.join(out, "review-motion.png"), fullPage: true });
    await noMessage();

    await page.locator('[data-kind="layers"]').click();
    check("6 scenery entries", await page.locator("#items button").count() === 6);
    for (const button of await page.locator("#items button").all()) {
      await button.click();
      await page.waitForFunction(() => !document.getElementById("play").disabled);
      check("scene has three toggleable layers", await page.locator("#layer-options input").count() === 3);
      await noMessage();
    }
    const before = await page.locator("#canvas").evaluate(c => c.toDataURL());
    await page.locator("#layer-options input").nth(0).uncheck();
    const after = await page.locator("#canvas").evaluate(c => c.toDataURL());
    check("layer toggle changes rendered pixels", before !== after);
    await page.locator("#layer-options input").nth(0).check();
    await page.locator("#pan").evaluate(input => { input.value = "80"; input.dispatchEvent(new Event("input", { bubbles: true })); });
    check("parallax changes rendered pixels", before !== await page.locator("#canvas").evaluate(c => c.toDataURL()));
    if (out) await page.screenshot({ path: path.join(out, "review-scenery.png"), fullPage: true });

    await page.locator('[data-kind="audio"]').click();
    check("12 music entries", await page.locator("#items button").count() === 12);
    for (const button of await page.locator("#items button").all()) {
      await button.click();
      await page.waitForFunction(() => {
        const audio = document.getElementById("audio");
        return audio.readyState >= 4 && Number.isFinite(audio.duration);
      });
      const record = await page.evaluate(() => {
        const audio = document.getElementById("audio");
        const item = MEDIA_CATALOG.packs.flatMap(p => p.items).find(i => i.id === document.querySelector('#items button[aria-pressed="true"]').dataset.id);
        return { id: item.id, seconds: audio.duration, expected: item.duration_seconds, paused: audio.paused };
      });
      check(`${record.id}: browser decoded duration (${record.seconds} / ${record.expected})`, Math.abs(record.seconds - record.expected) < .06);
      check(`${record.id}: no autoplay on selection`, record.paused);
      await noMessage();
    }
    await page.locator("#audio").evaluate(audio => { audio.volume = .12; });
    await page.waitForFunction(() => document.getElementById("volume").value === "12");
    await page.locator("#items button").first().click();
    check("native volume persists across track change", await page.locator("#audio").evaluate(a => a.volume) === .12);
    await page.waitForFunction(() => document.getElementById("audio").readyState >= 2);
    await page.locator("#audio").evaluate(audio => audio.play());
    await page.waitForFunction(() => document.getElementById("audio").currentTime > .15);
    checks.push("decoded audio playback advances");
    await page.locator('[data-kind="animation"]').click();
    check("switching category stops audio and releases source", await page.locator("#audio").evaluate(a => a.paused && !a.hasAttribute("src")));

    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForFunction(() => !document.getElementById("play").disabled);
    check("390px layout has no horizontal overflow", await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    if (out) await page.screenshot({ path: path.join(out, "review-mobile.png"), fullPage: true });
    check("no JavaScript runtime errors", errors.length === 0);
    check("no unexpected failed asset requests", failedRequests.length === 0);
    const report = { passed: true, browser: await browser.version(), checks, errors, failedRequests,
      limits: "Chromium automation checks visual asset loading and media decoding/playback, not subjective listening or game integration." };
    if (out) fs.writeFileSync(path.join(out, "browser_validation.json"), JSON.stringify(report, null, 2) + "\n");
    console.log(JSON.stringify({ passed: true, checks: checks.length, browser: report.browser }));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
