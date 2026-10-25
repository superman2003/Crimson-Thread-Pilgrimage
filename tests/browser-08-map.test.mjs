import { test } from "node:test";
import assert from "node:assert/strict";
import { mapGeometry, mapObjectives } from "../src/browser/map.js";
const chapter = {
  platforms: [[100, 200, 50, 10]],
  hazards: [{ x: 0, y: 300, w: 40, h: 40 }],
  exit: { x: 900, y: 400 },
  shortcut: { lever: { x: 500, y: 300 } },
};
test("geometry uses a common world projection with visible thin platforms", () => {
  const g = mapGeometry(chapter, 500, 100, 1000, 500);
  assert.deepEqual(g.platforms[0], { x: 50, y: 40, w: 25, h: 2 });
  assert.equal(g.exit.x, 450);
  assert.equal(g.hazards[0].y, 60);
});
test("taken keys and open shortcuts disappear, live boss and exit stay distinct", () => {
  const state = {
    keyPickups: [
      { x: 1, y: 2, taken: true },
      { x: 3, y: 4, taken: false },
    ],
    boss: { x: 8, y: 9, dead: false },
    shortcutOpen: false,
  };
  assert.deepEqual(
    mapObjectives(chapter, state).map((o) => o.kind),
    ["钟钥", "捷径机关", "守卫", "守卫封锁的出口"],
  );
  state.boss.dead = true;
  state.shortcutOpen = true;
  assert.deepEqual(
    mapObjectives(chapter, state).map((o) => o.kind),
    ["钟钥", "已开放出口"],
  );
});
test("drawing model does not mutate chapter or world state", () => {
  const state = { keyPickups: [] };
  const before = JSON.stringify([chapter, state]);
  mapGeometry(chapter, 500, 100, 1000, 500);
  mapObjectives(chapter, state);
  assert.equal(JSON.stringify([chapter, state]), before);
});
