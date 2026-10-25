import { test } from "node:test";
import assert from "node:assert/strict";
import { GUIDE_SECTIONS, hudDescription } from "../src/browser/guide.js";
test("controls guide covers keyboard touch objective combat and save scope", () => {
  assert.equal(GUIDE_SECTIONS.length, 5);
  assert.match(GUIDE_SECTIONS.flat().join(" "), /Godot 存档独立/);
  assert.match(GUIDE_SECTIONS.flat().join(" "), /三枚钟钥/);
});
test("hud describes actual health keys shortcut and guardian state", () => {
  const state = {
    player: { health: 3, maxHealth: 8 },
    keys: 2,
    keyPickups: [1, 2, 3],
    shortcutOpen: true,
    boss: { hp: 5, maxHp: 40, dead: false },
  };
  assert.equal(
    hudDescription(state),
    "生命 3 / 8；钟钥 2 / 3；捷径已开；守卫生命 5 / 40",
  );
  state.boss.dead = true;
  assert.match(hudDescription(state), /守卫已击败/);
});
test("initial and zero-health states remain meaningful", () => {
  assert.equal(hudDescription({}), "尚未开始旅途");
  assert.match(
    hudDescription({
      player: { health: 0, maxHealth: 8 },
      keys: 0,
      keyPickups: [],
      boss: null,
    }),
    /生命 0/,
  );
});
