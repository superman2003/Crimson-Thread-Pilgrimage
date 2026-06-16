import assert from "node:assert/strict";
import { CHAPTERS, SETTINGS } from "../src/gameData.js";

const mojibakePattern = /鑻|缁|绛|寮€|鈫|銆|锛|闂|鍙|鍊|瀹|�/;
const runtimeIpPattern = /Hollow Knight|Silksong|Team Cherry|空洞骑士|丝之歌/i;

assert.equal(CHAPTERS.length, 6, "必须正好包含 6 章");
assert.equal(SETTINGS.width, 960, "逻辑画布宽度固定，便于回归验证");
assert.equal(SETTINGS.height, 540, "逻辑画布高度固定，便于回归验证");

const ids = new Set();
const names = new Set();
const bosses = new Set();
const accents = new Set();

for (const [index, chapter] of CHAPTERS.entries()) {
  const textFields = [
    chapter.id,
    chapter.name,
    chapter.shortName,
    chapter.objective,
    chapter.flow,
    chapter.motif,
    chapter.boss?.name,
    ...chapter.enemies.map((enemy) => enemy.name)
  ].join("\n");

  assert.ok(chapter.id, `第 ${index + 1} 章缺少 id`);
  assert.ok(chapter.name, `第 ${index + 1} 章缺少名称`);
  assert.ok(chapter.objective, `第 ${index + 1} 章缺少目标`);
  assert.ok(chapter.flow?.includes("Boss 前捷径"), `${chapter.name} 必须有 Boss 前捷径节奏`);
  assert.ok(chapter.motif, `第 ${index + 1} 章缺少风格母题`);
  assert.equal(chapter.keys?.length, 3, `${chapter.name} 必须配置 3 把钟钥`);
  assert.equal(chapter.shortcut?.requiresKeys, 3, `${chapter.name} 捷径必须要求 3 把钟钥`);
  assert.ok(chapter.shortcut?.lever?.w > 0 && chapter.shortcut?.lever?.h > 0, `${chapter.name} 必须配置有效拉杆`);
  assert.ok(chapter.shortcut?.bridge?.w >= 180 && chapter.shortcut?.bridge?.h > 0, `${chapter.name} 必须配置有效捷径桥`);
  assert.ok(chapter.enemies.length >= 5, `${chapter.name} 至少需要 5 个普通怪`);
  assert.ok(chapter.platforms.length >= 7, `${chapter.name} 至少需要 7 段平台`);
  assert.ok(chapter.hazards.length >= 2, `${chapter.name} 至少需要 2 个章节机制`);
  assert.ok(chapter.boss?.hp >= 35, `${chapter.name} Boss 血量过低`);
  assert.doesNotMatch(textFields, mojibakePattern, `${chapter.name} 文案不能乱码`);
  assert.doesNotMatch(textFields, runtimeIpPattern, `${chapter.name} 运行时文案不能包含对标 IP 名称`);

  ids.add(chapter.id);
  names.add(chapter.name);
  bosses.add(chapter.boss.name);
  accents.add(chapter.palette.accent);
}

assert.equal(ids.size, CHAPTERS.length, "章节 id 必须唯一");
assert.equal(names.size, CHAPTERS.length, "章节名称必须唯一");
assert.equal(bosses.size, CHAPTERS.length, "Boss 必须不同");
assert.equal(accents.size, CHAPTERS.length, "每章主强调色必须不同");

console.log("game-data.test: PASS");
