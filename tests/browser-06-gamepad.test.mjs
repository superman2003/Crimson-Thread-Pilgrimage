import { test } from "node:test";
import assert from "node:assert/strict";
import { GamepadInput, readStandardPad, mountGamepad } from "../src/browser/gamepad.js";
const pad = (x = 0, pressed = []) => ({
  connected: true,
  mapping: "standard",
  axes: [x],
  buttons: Array.from({ length: 16 }, (_, i) => ({
    pressed: pressed.includes(i),
  })),
});
test("standard buttons, dpad, and hysteresis axis mapping", () => {
  assert.equal(readStandardPad(pad(-0.4)).left, true);
  assert.equal(readStandardPad(pad(-0.25), { left: true }).left, true);
  assert.equal(readStandardPad(pad(-0.1), { left: true }).left, false);
  assert.equal(readStandardPad(pad(0, [14, 0, 2, 5])).attack, true);
  assert.equal(readStandardPad({ ...pad(), mapping: "" }).jump, false);
});
test("held buttons require neutral on attach and after blur", () => {
  const g = new GamepadInput();
  assert.equal(g.merge({}, [pad(0, [0])]).jump, false);
  g.merge({}, [pad()]);
  assert.equal(g.merge({}, [pad(0, [0])]).jumpPressed, true);
  assert.equal(g.merge({}, [pad(0, [0])]).jumpPressed, false);
  g.merge({}, [pad()], false);
  assert.equal(g.merge({}, [pad(0, [0])]).jump, false);
});
test("disconnect releases gamepad without releasing keyboard; edges merge correctly", () => {
  const g = new GamepadInput();
  g.merge({}, [pad()]);
  g.merge({}, [pad(0, [0])]);
  assert.equal(g.merge({ jump: true }, []).jumpReleased, false);
  g.merge({}, [pad(0, [0])]);
  assert.equal(g.merge({}, []).jumpReleased, true);
});
test("keyboard press remains available when gamepad API is missing", () => {
  const g = new GamepadInput();
  assert.equal(g.merge({ attackPressed: true }, null).attackPressed, true);
});

test("hot-plug after idle frames requires neutral before movement", () => {
  let pads = [];
  const listeners = new Map();
  const win = {navigator:{getGamepads:()=>pads},addEventListener:(name,fn)=>listeners.set(name,fn)};
  const label = {setAttribute:()=>{},style:{}};
  const doc = {createElement:()=>label,body:{append:()=>{}},hidden:false,querySelector:()=>null};
  const input = mountGamepad(win,doc);
  input.read({}); // No pad on previous frames must not bypass hot-plug safety.
  pads=[pad(1)];
  listeners.get("gamepadconnected")();
  assert.equal(input.read({}).right,false);
  pads=[pad()];input.read({});pads=[pad(1)];
  assert.equal(input.read({}).right,true);
});
