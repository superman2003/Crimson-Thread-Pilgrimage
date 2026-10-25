import { test } from "node:test";
import assert from "node:assert/strict";
import { allowedPractice } from "../src/browser/practice.js";
test("only earned integral chapters can be practiced", () => {
  for (const i of [-1, 1, 5, NaN, 0.5, Infinity])
    assert.equal(allowedPractice(i, 1, 6), false);
  assert.equal(allowedPractice(0, 1, 6), true);
  assert.equal(allowedPractice(5, 6, 6), true);
  assert.equal(allowedPractice(6, 9, 6), false);
});
test("practice completion returns before normal progression and records", async () => {
  const { readFile } = await import("node:fs/promises");
  const s = await readFile(new URL("../src/main.js", import.meta.url), "utf8");
  const finish = s.slice(
    s.indexOf("function finishChapter()"),
    s.indexOf("function draw()"),
  );
  assert.ok(
    finish.indexOf("if (state.practice)") < finish.indexOf("const nextUnlock"),
  );
  assert.match(finish, /未改变章节进度/);
  assert.match(finish, /return;/);
});
