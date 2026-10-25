import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ProgressStore,
  parseUnlocks,
  PROGRESS_KEY,
} from "../src/browser/progress.js";
const memory = () => {
  const m = new Map();
  return { getItem: (k) => m.get(k) ?? null, setItem: (k, v) => m.set(k, v) };
};
test("reject corrupt, fractional, infinite, negative and out-of-range progress", () => {
  for (const raw of ["NaN", "Infinity", "2.4", "-1", "7", "{}", " 3 ", "1e2"])
    assert.equal(parseUnlocks(raw, 6), 1);
  assert.equal(parseUnlocks("6", 6), 6);
  assert.equal(parseUnlocks(null, 6), 1);
});
test("unlock writes preserve higher progress from another tab; explicit reset lowers it", () => {
  const m = memory(),
    s = new ProgressStore(() => m, 6);
  m.setItem(PROGRESS_KEY, "5");
  assert.equal(s.save(2), true);
  assert.equal(s.read(), 5);
  assert.equal(s.save(1, true), true);
  assert.equal(s.read(), 1);
});
test("storage failure is visible and retry clears the error without corrupting data", () => {
  const m = memory();
  let broken = true;
  const s = new ProgressStore(() => {
    if (broken) throw Error();
    return m;
  }, 6);
  assert.equal(s.read(), 1);
  assert.equal(s.save(3), false);
  assert.match(s.error, /未保存/);
  broken = false;
  assert.equal(s.save(3), true);
  assert.equal(s.error, "");
  assert.equal(s.read(), 3);
});
test("silent dropped writes and invalid candidates are rejected", () => {
  const s = new ProgressStore(
    () => ({ getItem: () => null, setItem: () => {} }),
    6,
  );
  assert.equal(s.save(4), false);
  assert.equal(s.save(1.5), false);
});
