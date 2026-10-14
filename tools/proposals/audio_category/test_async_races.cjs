#!/usr/bin/env node
'use strict';
// Deterministic control-flow tests, not browser DSP, listening, or runtime tests.
// Run from any directory: node /path/to/tools/proposals/audio_category/test_async_races.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const filename = path.resolve(__dirname, '../../../docs/proposals/audio_category/review.js');
const source = fs.readFileSync(filename, 'utf8');
const beginning = source.indexOf('class MixEngine {');
const end = source.indexOf('const engine = new MixEngine();', beginning);
assert.ok(beginning >= 0 && end > beginning, 'MixEngine source boundaries must exist');
const classSource = source.slice(beginning, end);
const buffer = () => ({duration: 40, length: 1920000});
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return {promise, resolve};
}

function fixture(code) {
  class Parameter {
    constructor() { this.value = 1; }
    cancelScheduledValues() {}
    cancelAndHoldAtTime() {}
    setValueCurveAtTime(values) { this.value = values[values.length - 1]; }
    linearRampToValueAtTime(value) { this.value = value; }
    setTargetAtTime(value) { this.value = value; }
  }
  class Node {
    constructor() { this.connections = new Set(); }
    connect(node) { this.connections.add(node); }
    disconnect() { this.connections.clear(); }
  }
  class Context {
    constructor() {
      this.state = 'suspended'; this.currentTime = 0; this.sampleRate = 48000;
      this.destination = new Node(); this.sources = []; this.resumeGate = null;
    }
    async resume() {
      if (this.resumeGate) await this.resumeGate.promise;
      assert.notEqual(this.state, 'closed', 'cannot resume a closed context');
      this.state = 'running';
    }
    async close() { this.state = 'closed'; }
    createGain() { const node = new Node(); node.gain = new Parameter(); return node; }
    createBufferSource() {
      const node = new Node(); node.started = false; node.stopped = false;
      node.start = () => { node.started = true; };
      node.stop = () => { node.stopped = true; };
      this.sources.push(node); return node;
    }
  }
  const controls = {
    master: {value: '35'}, mixRegion: {value: 'ch06'}, musicState: {value: 'exploration'},
    mixStatus: {}, stageRegion: {},
  };
  const items = [
    ['audio_category_ambience', 'ambience', 'bed'],
    ['audio_category_ambience', 'ambience', 'landmark'],
    ['reverse_music_v2', 'music', 'exploration'],
    ['reverse_music_v2', 'music', 'boss'],
    ['audio_category_music', 'music', 'combat_layer'],
    ['reverse_audio', 'sfx', 'warning'],
  ].map(([pack, kind, role]) => ({
    pack, kind, role, id: `ch06_${role}`, key: `${pack}:ch06_${role}`,
    region_id: 'ch06', title: role, loop: role !== 'warning', recommended_playback_gain_db: -6,
  }));
  const sandbox = vm.createContext({
    window: {AudioContext: Context}, location: {protocol: 'http:'},
    catalog: {regions: {ch06: 'CH06'}, mix_profiles: {profiles: []}}, items,
    $: id => { assert.ok(controls[id], `unexpected DOM control: ${id}`); return controls[id]; },
    gain: db => 10 ** (db / 20), stopAudition() {}, error() {},
  });
  vm.runInContext(code + '\nglobalThis.TestEngine = MixEngine;', sandbox, {filename});
  const engine = new sandbox.TestEngine();
  engine.init();
  // Spatial DSP is not under test. Keep its real voice lifecycle while omitting
  // convolution and the visual DOM; all lifecycle/switch/warning methods are real.
  engine.createSpatial = (item, decoded) => {
    engine.landmark = engine.voice(item, decoded, engine.environmentBus);
  };
  engine.applySpatial = () => {};
  engine.load = async item => { assert.ok(item, 'requested sound exists'); return buffer(); };
  return {engine, controls};
}

const cases = [
  {
    name: 'stop during resume cannot restart playback',
    async run(code) {
      const {engine} = fixture(code), gate = deferred();
      engine.context.resumeGate = gate;
      const starting = engine.start();
      engine.stop(); gate.resolve(); await starting;
      assert.equal(engine.running, false, 'stopped start must remain stopped');
      assert.equal(engine.voices.size, 0, 'cancelled start must create no voices');
      assert.equal(engine.context.sources.length, 0, 'cancelled start must schedule no source');
    },
    mutate(code) {
      return replaceOnce(code,
        '    const epoch = ++this.epoch; this.starting = true;\n    await this.context.resume();\n    if (epoch !== this.epoch) return;',
        '    await this.context.resume();\n    const epoch = ++this.epoch; this.starting = true;');
    },
  },
  {
    name: 'return to current music cancels a pending Boss request',
    async run(code) {
      const {engine} = fixture(code); await engine.start();
      const original = engine.currentMusic, gate = deferred();
      engine.load = item => item.role === 'boss' ? gate.promise : Promise.resolve(buffer());
      const switching = engine.switchMusic('boss');
      await engine.switchMusic('exploration'); gate.resolve(buffer()); await switching;
      assert.equal(engine.currentMusic, original, 'same-track selection must preserve original voice');
      assert.equal(engine.musicStarts, 1, 'cancelled Boss must not start a music voice');
      assert.equal(engine.voices.size, 3, 'only bed, landmark and original music remain');
      engine.stop();
    },
    mutate(code) {
      code = replaceOnce(code, '    const request = ++this.musicEpoch;\n', '');
      return replaceOnce(code, '    const epoch = this.epoch;\n    const buffer = await this.load(item);',
        '    const epoch = this.epoch, request = ++this.musicEpoch;\n    const buffer = await this.load(item);');
    },
  },
  {
    name: 'music selection during startup wins over older decoding',
    async run(code) {
      const {engine, controls} = fixture(code), gate = deferred(), entered = deferred();
      engine.load = item => {
        if (item.role === 'exploration') { entered.resolve(); return gate.promise; }
        return Promise.resolve(buffer());
      };
      const starting = engine.start(); await entered.promise;
      controls.musicState.value = 'combat';
      await engine.switchMusic('combat'); gate.resolve(buffer()); await starting;
      assert.equal(engine.currentMusic?.item.role, 'combat_layer', 'latest startup selection must win');
      assert.equal(engine.musicStarts, 1, 'superseded startup must not start its music');
      assert.equal(engine.voices.size, 3, 'superseded startup must not duplicate ambience');
      engine.stop();
    },
    mutate(code) { return replaceOnce(code, '    if (this.starting) return this.start();\n', ''); },
  },
  {
    name: 'old warning completion cannot release a new pending warning',
    async run(code) {
      const {engine} = fixture(code), older = deferred(), newer = deferred();
      let loads = 0;
      engine.running = true;
      engine.load = () => (++loads === 1 ? older.promise : newer.promise);
      const oldWarning = engine.warning();
      engine.stop(); engine.running = true;
      const newWarning = engine.warning();
      assert.equal(loads, 2, 'both epochs must reach independent pending loads');
      older.resolve(buffer()); await oldWarning;
      const pendingAfterOld = engine.warningPending;
      const voicesAfterOld = engine.voices.size;
      const thirdWarning = engine.warning(); // Must be suppressed while the new request waits.
      newer.resolve(buffer()); await Promise.all([newWarning, thirdWarning]);
      assert.equal(pendingAfterOld, true, 'old finally must not unlock new pending warning');
      assert.equal(voicesAfterOld, 0, 'old epoch must not create a warning voice');
      assert.equal(loads, 2, 'a third warning must stay blocked while loading');
      assert.equal(engine.voices.size, 1, 'only the current warning may play');
      assert.equal(engine.warningPending, false, 'current completion must release pending flag');
      engine.stop();
    },
    mutate(code) {
      return replaceOnce(code, 'finally { if (epoch === this.epoch) this.warningPending = false; }',
        'finally { this.warningPending = false; }');
    },
  },
  {
    name: 'closed context rebuild resets the warning clock',
    async run(code) {
      const {engine} = fixture(code);
      engine.context.currentTime = 120; engine.running = true;
      await engine.warning();
      assert.equal(engine.lastWarning, 120, 'old context must establish a real warning timestamp');
      const oldContext = engine.context;
      engine.stop(); await oldContext.close();
      await engine.start();
      assert.notEqual(engine.context, oldContext, 'closed context must be rebuilt');
      const before = engine.voices.size;
      await engine.warning();
      assert.equal(engine.voices.size, before + 1, 'fresh context must accept warning immediately');
      assert.equal(engine.lastWarning, 0, 'warning timestamp must use the new context clock');
      engine.stop();
    },
    mutate(code) {
      return replaceOnce(code, '    this.context = new Context({sampleRate: 48000});\n    this.lastWarning = -Infinity;',
        '    this.context = new Context({sampleRate: 48000});');
    },
  },
];

function replaceOnce(text, before, after) {
  assert.equal(text.split(before).length - 1, 1, 'mutation must match exactly one source location');
  return text.replace(before, after);
}

async function main() {
  for (const test of cases) {
    await test.run(classSource);
    console.log(`PASS ${test.name}`);
    const mutant = test.mutate(classSource);
    let rejection;
    try { await test.run(mutant); } catch (error) { rejection = error; }
    assert.ok(rejection, `regression test did not reject restored bug: ${test.name}`);
    assert.equal(rejection.code, 'ERR_ASSERTION', 'restored bug must fail an assertion, not crash the harness');
    console.log(`DETECTED restored bug: ${rejection.message.split('\n')[0]}`);
  }
  console.log('PASS 5 race regressions; 5 in-memory restored bugs rejected; source files unchanged.');
}
// Pending promises alone do not keep Node alive. Make a deadlocked regression
// fail explicitly instead of silently exiting before the final summary.
const watchdog = setTimeout(() => {
  console.error('FAIL async race tests did not complete within 5 seconds');
  process.exit(1);
}, 5000);
main().catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => clearTimeout(watchdog));
