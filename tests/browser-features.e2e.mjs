import { createRequire } from "node:module";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";
const require = createRequire(import.meta.url);
const { chromium } = process.env.PLAYWRIGHT_MODULE_PATH
  ? require(process.env.PLAYWRIGHT_MODULE_PATH)
  : await import("playwright");
const repo = fileURLToPath(new URL("../", import.meta.url)).replace(/\/$/, "");
const mainSource = await readFile(repo + "/src/main.js", "utf8");
const has = name => name === "utility-panel"
  ? ["audio","comfort","records","map","practice","guide"].some(has)
  : mainSource.includes("./browser/" + name + ".js");
const { createStaticServer } = await import(repo + "/server.js");
const server = createStaticServer(repo);
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const browser = await chromium.launch({
  headless: true,
  ...(process.env.CHROMIUM_EXECUTABLE
    ? { executablePath: process.env.CHROMIUM_EXECUTABLE }
    : {}),
  args: process.env.CHROMIUM_ARGS
    ? JSON.parse(process.env.CHROMIUM_ARGS)
    : ["--no-sandbox", "--disable-dev-shm-usage"],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
const results = [];
const check = async (name, fn) => {
  await fn();
  results.push(name);
  console.log("PASS " + name);
};
await page.route("**/src/main.js", async (route) => {
  let source = await readFile(repo + "/src/main.js", "utf8");
  source +=
    "\nwindow.__browserTest={state,input,update,draw,startChapter,startBossTrial,finishChapter,hurtPlayer,damageEnemy,saveUnlocks};";
  await route.fulfill({
    status: 200,
    contentType: "text/javascript",
    body: source,
  });
});
try {
  await page.goto("http://127.0.0.1:" + server.address().port);
  await page.waitForFunction(() => window.__browserTest);
  const run = (expr) => page.evaluate(expr);
  await run("__browserTest.startChapter(0,{silent:true})");
  await page.waitForTimeout(100);
  await check("boot and native toolbar", async () => {
    assert.deepEqual(errors, []);
    if (has("utility-panel"))
      assert.equal(await page.locator("#browserUtilityDock").count(), 1);
  });
  if (has("pause"))
    await check(
      "pause freezes world and explicit resume preserves position",
      async () => {
        await run("window.__browserTest.startChapter(0,{silent:true})");
        await page.keyboard.press("Escape");
        await page.waitForSelector("#browserPauseDialog[open]");
        const a = await run(
          "({time:__browserTest.state.time,x:__browserTest.state.player.x})",
        );
        await page.waitForTimeout(150);
        assert.deepEqual(
          await run(
            "({time:__browserTest.state.time,x:__browserTest.state.player.x})",
          ),
          a,
        );
        await page
          .getByRole("button", { name: "继续旅途", exact: true })
          .click();
        assert.equal(
          await page.locator("#browserPauseDialog").getAttribute("open"),
          null,
        );
      },
    );
  if (has("input"))
    await check("physical keyboard aliases hold independently", async () => {
      await page.locator("#game").click({ position: { x: 20, y: 350 } });
      await page.keyboard.down("a");
      await page.keyboard.down("ArrowLeft");
      await page.keyboard.up("a");
      assert.equal(await run("__browserTest.input.left"), true);
      await page.keyboard.up("ArrowLeft");
      assert.equal(await run("__browserTest.input.left"), false);
    });
  if (has("input"))
    await check("blur clears input and opens pause dialog", async () => {
      await page.keyboard.down("d");
      await run('window.dispatchEvent(new Event("blur"))');
      await page.keyboard.up("d");
      assert.equal(await run("__browserTest.input.right"), false);
      if (has("pause"))
        await page
          .getByRole("button", { name: "继续旅途", exact: true })
          .click();
    });
  if (has("input"))
    await check("touch pointer capture releases outside button", async () => {
      await page.setViewportSize({ width: 390, height: 844 });
      const button = page.locator('[data-key="left"]');
      const b = await button.boundingBox();
      await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
      await page.mouse.down();
      assert.equal(await run("__browserTest.input.left"), true);
      await page.mouse.move(380, 400);
      await page.mouse.up();
      assert.equal(await run("__browserTest.input.left"), false);
      await page.setViewportSize({ width: 1280, height: 800 });
    });
  if (has("audio"))
    await check("audio controls save and mute", async () => {
      await page.locator("#browserAudio summary").click();
      await page.locator("#browserAudio input").fill("25");
      await page.locator("#browserAudio input").dispatchEvent("input");
      await page.getByRole("button", { name: "静音", exact: true }).click();
      assert.deepEqual(
        await run(
          'JSON.parse(localStorage.getItem("crimson-browser-audio-v1"))',
        ),
        { volume: 0.25, muted: true },
      );
    });
  if (has("comfort"))
    await check(
      "comfort settings persist and do not freeze hazard clocks",
      async () => {
        await page.locator("#browserComfort summary").click();
        await page.locator("#browserComfort input").first().check();
        assert.equal(
          await run(
            'JSON.parse(localStorage.getItem("crimson-browser-comfort-v1")).reduced',
          ),
          true,
        );
        const source = await readFile(repo + "/src/main.js", "utf8");
        assert.match(
          source,
          /Math\.sin\(state\.time \* 3\.4 \+ hazard\.phase\)/,
        );
      },
    );
  if (has("gamepad"))
    await check(
      "simulated standard Gamepad API reaches player movement",
      async () => {
        await run(`__browserTest.startChapter(0,{silent:true});
  window.__pad={connected:true,mapping:'standard',axes:[0],buttons:Array.from({length:16},()=>({pressed:false}))};
  Object.defineProperty(navigator,'getGamepads',{configurable:true,value:()=>[window.__pad]});
  __browserTest.update(0.016);__pad.axes[0]=1;__browserTest.update(0.016);`);
        assert.ok((await run("__browserTest.state.player.vx")) > 0);
        assert.match(
          await page.locator("#browserGamepad").textContent(),
          /手柄/,
        );
        await run("__pad.connected=false;__browserTest.update(0.016)");
      },
    );
  if (has("records"))
    await check(
      "records follow real damage and completion; practice is excluded",
      async () => {
        await run(
          "__browserTest.startChapter(0,{silent:true}); __browserTest.state.player.invuln=0;__browserTest.hurtPlayer(2);__browserTest.finishChapter()",
        );
        let records = await run(
          'JSON.parse(localStorage.getItem("crimson-browser-records-v1"))',
        );
        assert.equal(records.rows[0].damage, 2);
        assert.equal(records.rows[0].result, "clear");
        await run(
          "__browserTest.startBossTrial(0,{silent:true});__browserTest.finishChapter()",
        );
        if (has("practice"))
          assert.equal(await run("__browserTest.state.mode"), "menu");
        assert.deepEqual(
          await run(
            'JSON.parse(localStorage.getItem("crimson-browser-records-v1"))',
          ),
          records,
        );
      },
    );
  if (has("practice"))
    await check(
      "practice selection obeys earned chapters and cancel preserves run",
      async () => {
        await page.locator("#browserPractice summary").click();
        assert.equal(
          await page.locator("#browserPractice option").last().isDisabled(),
          true,
        );
        const before = await run("__browserTest.state.mode");
        page.once("dialog", (d) => d.dismiss());
        await page
          .getByRole("button", { name: "开始守卫练习", exact: true })
          .click();
        assert.equal(await run("__browserTest.state.mode"), before);
        page.once("dialog", (d) => d.accept());
        await page
          .getByRole("button", { name: "开始守卫练习", exact: true })
          .click();
        assert.equal(await run("__browserTest.state.practice"), true);
      },
    );
  if (has("map"))
    await check(
      "map updates taken keys and has semantic objective text",
      async () => {
        await run("__browserTest.startChapter(0,{silent:true})");
        await page.locator("#browserRouteMap summary").click();
        await page.waitForTimeout(100);
        assert.match(
          await page
            .locator("#browserRouteMap canvas")
            .getAttribute("aria-label"),
          /钟钥/,
        );
        await run("window.__crimsonThreadQA.collectAllKeys()");
        await page.waitForTimeout(50);
        assert.doesNotMatch(
          await page
            .locator("#browserRouteMap canvas")
            .getAttribute("aria-label"),
          /钟钥/,
        );
      },
    );
  if (has("guide"))
    await check(
      "accessibility guide owns focus, status and explicit announcement",
      async () => {
        await page.locator("#browserGuide summary").click();
        await page.getByRole("button", { name: "播报当前状态" }).click();
        assert.match(
          await page.locator("#browserHudDescription").textContent(),
          /生命/,
        );
        assert.equal(
          await page.locator("#hud").getAttribute("aria-live"),
          null,
        );
      },
    );
  if (has("progress"))
    await check(
      "reset cancellation preserves progress; storage denial preserves live state",
      async () => {
        await run(
          '__browserTest.state.mode="menu";document.querySelector("#menu").classList.remove("is-hidden")',
        );
        const unlocked = await run("__browserTest.state.unlocked");
        page.once("dialog", (d) => d.dismiss());
        await page.locator("#resetButton").click();
        assert.equal(await run("__browserTest.state.unlocked"), unlocked);
        await run(
          'window.__originalSet=Storage.prototype.setItem;Storage.prototype.setItem=()=>{throw new Error("blocked")};__browserTest.saveUnlocks()',
        );
        assert.match(
          await page.locator("#browserProgressStatus").textContent(),
          /未保存/,
        );
        await run("Storage.prototype.setItem=window.__originalSet");
        await page
          .getByRole("button", { name: "重试保存", exact: true })
          .click();
        assert.equal(
          await page.locator("#browserProgressStatus").isVisible(),
          false,
        );
      },
    );
  if (has("utility-panel"))
    await check(
      "mobile toolbar and touch controls stay within viewport",
      async () => {
        await page.setViewportSize({ width: 390, height: 844 });
        await run("__browserTest.startChapter(0,{silent:true})");
        await page
          .locator("#browserUtilityDock details")
          .first()
          .evaluate((el) => (el.open = true));
        await page.waitForTimeout(50);
        const bounds = await page
          .locator("#browserUtilityDock details[open] .browser-utility-content")
          .first()
          .boundingBox();
        assert.ok(bounds.x >= 0 && bounds.x + bounds.width <= 391);
        await page.evaluate(() => document.fonts.ready);
        await mkdir(repo + "/artifacts/browser-features", { recursive: true });
        await page.screenshot({
          path: repo + "/artifacts/browser-features/mobile.png",
        });
      },
    );
  assert.deepEqual(errors, []);
  await mkdir(repo + "/artifacts/browser-features", { recursive: true });
  await writeFile(
    repo + "/artifacts/browser-features/results.json",
    JSON.stringify({ results, errors }, null, 2),
  );
  console.log("ALL " + results.length + " BROWSER CHECKS PASSED");
} finally {
  await browser.close();
  await new Promise((r) => server.close(r));
}
