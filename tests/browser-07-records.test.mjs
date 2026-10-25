import { test } from "node:test";
import assert from "node:assert/strict";
import { RunRecords, validateRecord } from "../src/browser/records.js";
const storage = () => ({ getItem: () => null, setItem: () => {} });
test("actual damage, kills and one result per run", () => {
  const r = new RunRecords(storage);
  r.begin(0);
  r.damage(2);
  r.kill();
  assert.equal(r.finish("clear", 12), true);
  assert.equal(r.finish("clear", 5), false);
  assert.equal(r.rows[0].damage, 2);
  assert.equal(r.rows[0].kills, 1);
});
test("bounded history and per-chapter best exclude failures", () => {
  const r = new RunRecords(storage);
  for (let i = 0; i < 30; i++) {
    r.begin(0);
    r.finish(i % 2 ? "clear" : "defeat", i + 1);
  }
  assert.equal(r.rows.length, 24);
  assert.equal(r.best(0), 8);
  assert.equal(r.best(1), null);
});
test("practice and abandoned sessions never award a record", () => {
  const r = new RunRecords(storage);
  r.begin(0);
  r.damage(4);
  r.begin(1);
  r.finish("clear", 5, true);
  assert.equal(r.rows.length, 0);
});
test("corrupt records are excluded; denied writes remain retryable", () => {
  assert.equal(validateRecord({ chapter: 99 }), false);
  let broken = true;
  const r = new RunRecords(() => ({
    getItem: () => null,
    setItem: () => {
      if (broken) throw Error();
    },
  }));
  r.begin(0);
  r.finish("clear", 5);
  assert.match(r.error, /失败/);
  broken = false;
  assert.equal(r.save(), true);
  assert.equal(r.error, "");
});
