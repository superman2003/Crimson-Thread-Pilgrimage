import assert from "node:assert/strict";
import { createStaticServer } from "../server.js";

const server = createStaticServer();
const mojibakePattern = /鑻|缁|绛|寮€|鈫|銆|锛|闂|鍙|鍊|瀹|�/;
const runtimeIpPattern = /Hollow Knight|Silksong|Team Cherry|空洞骑士|丝之歌/i;

await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const { port } = server.address();
const base = `http://127.0.0.1:${port}`;

try {
  const index = await fetch(`${base}/`);
  assert.equal(index.status, 200, "home page must be reachable");
  const html = await index.text();
  assert.match(html, /绯线远征/, "home page must include the readable game title");
  assert.match(html, /等待启程/, "home page must include readable HUD text");
  assert.doesNotMatch(html, mojibakePattern, "served HTML must not contain mojibake");
  assert.doesNotMatch(html, runtimeIpPattern, "served HTML must not contain protected inspiration IP names");

  const main = await fetch(`${base}/src/main.js`);
  assert.equal(main.status, 200, "main script must be reachable");
  const mainText = await main.text();
  assert.match(mainText, /requestAnimationFrame/, "main loop must exist");
  assert.match(mainText, /jumpBufferTime/, "player tuning must be served");
  assert.doesNotMatch(mainText, mojibakePattern, "served main script must not contain mojibake");

  for (const assetPath of [
    "/godot/assets/sprites/player/generated_hero_v2/frames/idle_00.png",
    "/godot/assets/sprites/player/generated_hero_v2/frames/run_00.png",
    "/godot/assets/sprites/player/generated_hero_v2/frames/attack_00.png",
    "/godot/assets/sprites/player/generated_hero_v2/frames/dash_00.png",
    "/godot/assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    "/godot/assets/sprites/gothicvania/demo/bg_ch01_sky.png",
    "/godot/assets/audio/sfx/player_attack.ogg"
  ]) {
    const asset = await fetch(`${base}${assetPath}`);
    assert.equal(asset.status, 200, `asset must be reachable: ${assetPath}`);
    assert.ok((await asset.arrayBuffer()).byteLength > 0, `asset must not be empty: ${assetPath}`);
  }

  const missing = await fetch(`${base}/missing.file`);
  assert.equal(missing.status, 404, "missing files must return 404");

  console.log("runtime-smoke.test: PASS");
} finally {
  await new Promise((resolve) => server.close(resolve));
}
