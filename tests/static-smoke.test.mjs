import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const runtimeFiles = ["index.html", "src/main.js", "src/gameData.js", "src/styles.css"];
const content = runtimeFiles.map((file) => readFileSync(file, "utf8")).join("\n");
const mojibakePattern = /鑻|缁|绛|寮€|鈫|銆|锛|闂|鍙|鍊|瀹|�/;
const runtimeIpPattern = /Hollow Knight|Silksong|Team Cherry|空洞骑士|丝之歌/i;

assert.match(content, /<canvas id="game"/, "page must include the game canvas");
assert.match(content, /绯线远征/, "runtime text must use readable Chinese");
assert.match(content, /window\.__crimsonThreadQA/, "QA hook must be exposed for browser checks");
assert.match(content, /generated_hero_v2\/frames\/idle_00\.png/, "player must use generated hero v2 frames");
assert.match(content, /PLAYER_ANIMS/, "player animation frame selection must be present");
assert.match(content, /VISUAL_BOUNDS/, "visual bounds must be separate from collision boxes");
assert.match(content, /PLAYER_TUNING/, "player tuning must be explicit");
assert.match(content, /jumpBufferTime:\s*0\.12/, "jump buffering must be tuned");
assert.match(content, /coyoteTime:\s*0\.12/, "coyote time must be tuned");
assert.match(content, /shortcutOpen/, "shortcut state must exist");
assert.match(content, /keyPickups/, "key pickup state must exist");
assert.match(content, /hitStop/, "hit stop feedback must exist");
assert.match(content, /collectAllKeys/, "QA hook must be able to collect keys");
assert.match(content, /openShortcut/, "QA hook must be able to open the shortcut");
assert.match(content, /godot\/assets\/sprites\/gothicvania\/demo\/enemy_moss_larva\.png/, "enemies must use the open/free enemy set");
assert.match(content, /godot\/assets\/sprites\/gothicvania\/demo\/bg_ch01_sky\.png/, "background must use redistributable CH01 art");
assert.match(content, /godot\/assets\/audio\/sfx\/player_attack\.ogg/, "attack sfx must use the local OGG asset");
assert.doesNotMatch(content, mojibakePattern, "runtime source must not contain mojibake");
assert.doesNotMatch(content, runtimeIpPattern, "runtime source must not contain protected inspiration IP names");
assert.doesNotMatch(content, /https?:\/\//i, "runtime source must not depend on external network assets");

console.log("static-smoke.test: PASS");
