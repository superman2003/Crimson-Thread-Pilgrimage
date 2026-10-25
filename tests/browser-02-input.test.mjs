import { test } from "node:test";
import assert from "node:assert/strict";
import { InputSources, editableTarget } from "../src/browser/input.js";
test("keyboard aliases and touch holds cannot release each other", () => {
  const events = [];
  const s = new InputSources((...event) => events.push(event));
  s.set("A", "left", true);
  s.set("ArrowLeft", "left", true);
  s.set("pointer:1", "left", true);
  s.set("A", "left", false);
  s.set("ArrowLeft", "left", false);
  assert.deepEqual(events, [["left", true]]);
  s.set("pointer:1", "left", false);
  assert.deepEqual(events.at(-1), ["left", false]);
});
test("repeat and duplicate cancellation are edge triggered", () => {
  const events = [];
  const s = new InputSources((...e) => events.push(e));
  s.set("Space", "jump", true);
  s.set("Space", "jump", true);
  s.clear();
  s.clear();
  s.set("Space", "jump", false);
  s.set("bad", "invalid", true);
  assert.deepEqual(events, [
    ["jump", true],
    ["jump", false],
  ]);
});
test("blur clears every action, preserving fresh presses", () => {
  const events = [];
  const s = new InputSources((...e) => events.push(e));
  s.set("a", "left", true);
  s.set("b", "attack", true);
  s.clear();
  assert.equal(s.active("left"), false);
  assert.equal(s.active("attack"), false);
  s.set("b", "attack", true);
  assert.deepEqual(events.at(-1), ["attack", true]);
});
test("editable and semantic controls own their keys", () => {
  assert.equal(editableTarget(null), false);
  assert.equal(editableTarget({ closest: () => ({}) }), true);
});
