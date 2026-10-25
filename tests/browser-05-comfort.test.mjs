import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ComfortPreferences,
  normalizeComfort,
} from "../src/browser/comfort.js";
const store = () => ({ getItem: () => null, setItem: () => {} });
test("system reduced motion is the default with no saved override", () => {
  const p = new ComfortPreferences(store, true);
  assert.equal(p.shake, false);
  assert.equal(p.particles, false);
  p.systemChanged(false);
  assert.equal(p.shake, true);
});
test("saved explicit choice survives system changes and reload", () => {
  let raw = null;
  const s = () => ({ getItem: () => raw, setItem: (k, v) => (raw = v) });
  const p = new ComfortPreferences(s, true);
  p.set({ reduced: false, shake: false });
  p.systemChanged(true);
  assert.equal(p.value.reduced, false);
  assert.equal(p.shake, false);
  assert.deepEqual(new ComfortPreferences(s, true).value, p.value);
});
test("individual particle and shake controls preserve independent choices", () => {
  const p = new ComfortPreferences(store);
  p.set({ particles: false });
  assert.equal(p.shake, true);
  assert.equal(p.particles, false);
  p.set({ reduced: true });
  assert.equal(p.shake, false);
  p.set({ reduced: false });
  assert.equal(p.shake, true);
  assert.equal(p.particles, false);
});
test("malformed storage and denied writes remain usable", () => {
  const p = new ComfortPreferences(() => {
    throw Error();
  }, true);
  assert.equal(p.set({ reduced: false }), false);
  assert.equal(p.shake, true);
  assert.equal(normalizeComfort({ contrast: "yes" }).contrast, false);
});
