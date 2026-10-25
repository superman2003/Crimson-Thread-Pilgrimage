import { test } from "node:test";
import assert from "node:assert/strict";
import { PauseState } from "../src/browser/pause.js";
test("only a running world pauses; repeated blur keeps the original reason", () => {
  const p = new PauseState();
  assert.equal(p.pause("menu"), false);
  assert.equal(p.pause("playing", "blur"), true);
  assert.equal(p.pause("playing", "hidden"), false);
  assert.equal(p.reason, "blur");
});
test("background pages cannot resume; visible resume is explicit and idempotent", () => {
  const p = new PauseState();
  p.pause("playing");
  assert.equal(p.resume(false), false);
  assert.equal(p.paused, true);
  assert.equal(p.resume(true), true);
  assert.equal(p.resume(true), false);
  assert.equal(p.reason, "");
});
