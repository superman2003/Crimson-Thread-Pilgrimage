import { test } from "node:test";
import assert from "node:assert/strict";
import { AudioPreferences, normalizeAudio } from "../src/browser/audio.js";
const store = () => ({ getItem: () => null, setItem: () => {} });
test("normalize preferences and reject malformed data", () => {
  assert.deepEqual(normalizeAudio({ volume: Infinity, muted: "yes" }), {
    volume: 0.7,
    muted: false,
  });
  assert.equal(normalizeAudio({ volume: -2 }).volume, 0);
  assert.equal(normalizeAudio({ volume: 5 }).volume, 1);
});
test("mute and volume affect already playing voices", () => {
  const p = new AudioPreferences(store),
    events = {};
  const clip = { addEventListener: (n, f) => (events[n] = f), pause: () => {} };
  p.track(clip, 0.5);
  p.set({ volume: 0.4 });
  assert.equal(clip.volume, 0.2);
  p.set({ muted: true });
  assert.equal(clip.volume, 0);
  p.set({ muted: false });
  assert.equal(clip.volume, 0.2);
  events.ended();
  assert.equal(p.voices.size, 0);
});
test("voice budget retires oldest and blur stops all tracked clips", () => {
  const p = new AudioPreferences(store);
  let pauses = 0;
  for (let i = 0; i < 13; i++)
    p.track({ addEventListener: () => {}, pause: () => pauses++ }, 1);
  assert.equal(pauses, 1);
  assert.equal(p.voices.size, 12);
  p.silence();
  assert.equal(pauses, 13);
  assert.equal(p.voices.size, 0);
});
test("storage denial keeps session preferences with honest status", () => {
  const p = new AudioPreferences(() => {
    throw Error();
  });
  p.set({ volume: 0.2 });
  assert.equal(p.gain, 0.2);
  assert.match(p.error, /未保存/);
});
