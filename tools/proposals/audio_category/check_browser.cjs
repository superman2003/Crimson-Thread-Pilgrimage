#!/usr/bin/env node
'use strict';
/* Run against serve_review.py. This is muted browser QA, not human listening.
 * NODE_PATH=$CODEX_PRIMARY_RUNTIME_NODE_MODULES CHROMIUM_EXECUTABLE=/path/to/chrome
 * node tools/proposals/audio_category/check_browser.cjs http://127.0.0.1:8765/
 * Optional AUDIO_QA_OUTPUT=/path writes report and three review screenshots.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');

const baseURL = process.argv[2];
if (!baseURL || !process.env.CHROMIUM_EXECUTABLE) {
  console.error('Usage: CHROMIUM_EXECUTABLE=/path/to/chrome node check_browser.cjs baseURL');
  process.exit(2);
}
const url = new URL(baseURL);
if (!url.pathname.includes('/docs/proposals/audio_category')) url.pathname = '/docs/proposals/audio_category/';
const output = process.env.AUDIO_QA_OUTPUT;
const report = {schema_version: 1, url: url.href, status: 'running', browser_muted: true,
  human_listening_review: 'pending', checks: [], decoded: [], page_errors: [], console_errors: [],
  failed_requests: [], expected_media_cancellations: [], bad_responses: [], screenshots: []};
if (output) fs.mkdirSync(output, {recursive: true});

(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_EXECUTABLE,
    headless: true, args: ['--no-sandbox', '--mute-audio', '--disable-dev-shm-usage']});
  report.browser = browser.version();
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}, deviceScaleFactor: 1});
  page.setDefaultTimeout(20000);
  page.on('pageerror', e => report.page_errors.push(e.message));
  page.on('console', m => {if (m.type() === 'error') report.console_errors.push(m.text());});
  page.on('response', r => {if (r.status() >= 400) report.bad_responses.push({url: r.url(), status: r.status()});});
  page.on('requestfailed', r => {
    const entry = {url: r.url(), type: r.resourceType(), error: r.failure()?.errorText};
    if (r.resourceType() === 'media' && entry.error === 'net::ERR_ABORTED') report.expected_media_cancellations.push(entry);
    else report.failed_requests.push(entry);
  });
  async function check(name, fn) {
    try { const evidence = await fn(); report.checks.push({name, status: 'pass', evidence: evidence ?? null}); }
    catch (e) { report.checks.push({name, status: 'fail', error: e.message}); console.error(`FAIL ${name}: ${e.message}`); }
  }
  const snapshot = () => page.evaluate(() => window.__audioReview.engine.snapshot());
  const stable = role => page.waitForFunction(expected => {
    const e = window.__audioReview.engine;
    return e.running && e.voices.size === 3 && e.currentMusic?.item.role === expected;
  }, role, {timeout: 25000});
  async function setRange(id, value) {
    await page.locator('#' + id).evaluate((node, v) => {node.value = v; node.dispatchEvent(new Event('input', {bubbles: true}));}, String(value));
  }
  async function screenshot(name) {
    if (output) {await page.screenshot({path: path.join(output, name), fullPage: true}); report.screenshots.push(name);}
  }
  try {
    await page.goto(url.href, {waitUntil: 'networkidle'});
    await page.waitForFunction(() => window.__audioReview?.items?.length > 0);
    await check('no_autoplay_and_catalog_counts', async () => {
      const initial = await page.evaluate(() => ({snapshot: window.__audioReview.engine.snapshot(),
        paused: document.getElementById('audition').paused,
        counts: window.__audioReview.items.reduce((a,x) => (a[x.kind]=(a[x.kind]||0)+1,a),{})}));
      assert.equal(initial.paused, true); assert.equal(initial.snapshot.voices, 0);
      assert.equal(initial.snapshot.contextState, 'uninitialized');
      assert.deepEqual(initial.counts, {music: 41, sfx: 75, ambience: 24});
      assert.equal(await page.locator('#trackList .track').count(), 140);
      return initial;
    });
    await screenshot('browser_archive_desktop.png');

    await check('all_140_actual_webaudio_decodes', async () => {
      // Decode sequentially and retain only scalar metadata to bound browser memory.
      report.decoded = await page.evaluate(async () => {
        const ctx = new AudioContext({sampleRate: 48000}), result = [];
        try {
          for (const item of window.__audioReview.items) {
            const response = await fetch(item.url);
            if (!response.ok) throw new Error(`${item.id}: HTTP ${response.status}`);
            const buffer = await ctx.decodeAudioData(await response.arrayBuffer());
            result.push({key: item.key, duration: buffer.duration, expected_duration: item.duration_seconds,
              channels: buffer.numberOfChannels, expected_channels: item.channels, sample_rate: buffer.sampleRate});
          }
        } finally {await ctx.close();}
        return result;
      });
      assert.equal(report.decoded.length, 140);
      for (const d of report.decoded) {
        assert.ok(Math.abs(d.duration - d.expected_duration) <= 0.04, `${d.key}: decoded duration`);
        assert.equal(d.channels, d.expected_channels, `${d.key}: decoded channels`);
        assert.equal(d.sample_rate, 48000, `${d.key}: sample rate`);
      }
      return {count: report.decoded.length, tolerance_seconds: 0.04};
    });

    await check('native_player_advances_switch_stops_and_volume_persists', async () => {
      await page.locator('#trackList .track').first().click();
      await page.evaluate(async () => {const a=document.getElementById('audition');a.volume=0.27;await a.play();});
      await page.waitForFunction(() => document.getElementById('audition').currentTime > 0.15);
      const playing = await page.locator('#audition').evaluate(a => ({time:a.currentTime,paused:a.paused,source:a.currentSrc,volume:a.volume}));
      assert.equal(playing.paused, false);
      await page.locator('#trackList .track').nth(1).click();
      const switched = await page.locator('#audition').evaluate(a => ({time:a.currentTime,paused:a.paused,source:a.src,volume:a.volume}));
      assert.equal(switched.paused, true); assert.equal(switched.volume, 0.27); assert.notEqual(switched.source, playing.source);
      await page.evaluate(() => document.getElementById('audition').play());
      await page.waitForFunction(() => document.getElementById('audition').currentTime > 0.15);
      await page.locator('#mixTab').click();
      assert.equal(await page.locator('#audition').evaluate(a => a.paused), true);
      return {playing, switched};
    });

    await check('six_regions_four_music_states_and_same_track_continuity', async () => {
      await page.locator('#mixTab').click();
      const results = [];
      for (const region of ['ch01','ch02','ch03','ch04','ch05','ch06']) {
        await page.locator('#mixRegion').selectOption(region);
        assert.equal((await snapshot()).voices, 0, `${region}: region change stops voices`);
        await page.locator('#musicState').selectOption('exploration');
        await page.locator('#mixPlay').click(); await stable('exploration');
        const states = {exploration: await snapshot()};
        for (const state of ['boss','combat','lullaby']) {
          await page.locator('#musicState').selectOption(state);
          await stable(state === 'combat' ? 'combat_layer' : state);
          states[state] = await snapshot();
          assert.equal(states[state].region, region);
        }
        const before = await page.evaluate(() => ({starts:window.__audioReview.engine.musicStarts, started:window.__audioReview.engine.currentMusic.started}));
        await page.locator('#musicState').dispatchEvent('change');
        await page.waitForTimeout(100);
        const after = await page.evaluate(() => ({starts:window.__audioReview.engine.musicStarts, started:window.__audioReview.engine.currentMusic.started}));
        assert.deepEqual(after,before,`${region}: identical music must not restart`);
        results.push({region, states, same_track: after});
        await page.locator('#mixStop').click();
        const stopped=await snapshot(); assert.equal(stopped.voices,0); assert.equal(stopped.running,false);
      }
      return results;
    });

    await check('spatial_distance_occlusion_pan_reverb_and_master', async () => {
      await page.locator('#mixRegion').selectOption('ch03');
      await page.locator('#musicState').selectOption('exploration');
      await page.locator('#mixPlay').click(); await stable('exploration');
      await setRange('distance', 2); await page.waitForTimeout(450);
      const near=await snapshot();
      await setRange('distance', 10); await page.waitForTimeout(450);
      const far=await snapshot(); assert.ok(far.distanceGain < near.distanceGain * .5);
      await page.locator('#occluded').check(); await page.waitForTimeout(450);
      const blocked=await snapshot(); assert.ok(blocked.filterHz < 2000); assert.ok(blocked.distanceGain < far.distanceGain*.6);
      await page.locator('#occluded').uncheck(); await page.waitForTimeout(450);
      assert.ok((await snapshot()).filterHz > 19500);
      await setRange('pan', -80); await page.waitForTimeout(300);
      const left=await page.evaluate(() => window.__audioReview.engine.panner.pan.value); assert.ok(left<-.79);
      await setRange('pan', 70); await page.waitForTimeout(300);
      const right=await page.evaluate(() => window.__audioReview.engine.panner.pan.value); assert.ok(right>.69);
      await page.locator('#reverb').uncheck(); await page.waitForTimeout(400);
      const dry=await page.evaluate(() => window.__audioReview.engine.wet.gain.value); assert.ok(dry<.001);
      await page.locator('#reverb').check(); await page.waitForTimeout(400);
      const wet=await page.evaluate(() => window.__audioReview.engine.wet.gain.value); assert.ok(wet>.07);
      await setRange('master', 22); await page.waitForTimeout(200);
      const master=await page.evaluate(() => window.__audioReview.engine.master.gain.value); assert.ok(Math.abs(master-.22)<.001);
      return {near,far,blocked,left,right,dry,wet,master};
    });

    await check('warning_duck_then_recovers_to_three_voices', async () => {
      await page.locator('#warning').click();
      await page.waitForFunction(() => window.__audioReview.engine.musicBus.gain.value < .5);
      const duck=await page.evaluate(() => ({music:window.__audioReview.engine.musicBus.gain.value,environment:window.__audioReview.engine.environmentBus.gain.value}));
      assert.ok(duck.environment<.5);
      await page.waitForFunction(() => {const e=window.__audioReview.engine;return e.musicBus.gain.value>.99&&e.environmentBus.gain.value>.99&&e.voices.size===3;},{},{timeout:7000});
      return {duck,recovered:await snapshot()};
    });
    await screenshot('browser_mix_desktop.png');

    await check('rapid_music_changes_last_selection_wins', async () => {
      await page.evaluate(() => {const el=document.getElementById('musicState');for(const v of ['boss','combat','exploration','lullaby']){el.value=v;el.dispatchEvent(new Event('change'));}});
      await stable('lullaby');
      const final=await snapshot(); assert.equal(final.voices,3); return final;
    });
    await check('stop_during_delayed_resume_cannot_restart', async () => {
      await page.evaluate(() => {
        const e=window.__audioReview.engine;e.stop();
        const original=e.context.resume.bind(e.context);
        e.context.resume=()=>new Promise(resolve=>{window.releaseResume=()=>{e.context.resume=original;resolve();};});
      });
      await page.locator('#mixPlay').click();
      await page.waitForFunction(() => typeof window.releaseResume==='function');
      await page.locator('#mixStop').click();
      await page.evaluate(() => {window.releaseResume();delete window.releaseResume;});
      await page.waitForTimeout(250);
      const stopped=await snapshot();assert.equal(stopped.voices,0);assert.equal(stopped.running,false);return stopped;
    });
    await check('return_to_current_track_cancels_delayed_boss', async () => {
      await page.locator('#musicState').selectOption('exploration');
      await page.locator('#mixPlay').click();await stable('exploration');
      const before=await snapshot();
      await page.evaluate(() => {
        const e=window.__audioReview.engine,original=e.load.bind(e);
        e.load=async item=>{if(item.role==='boss'){await new Promise(resolve=>{window.releaseBoss=resolve;});}return original(item);};
        window.restoreLoad=()=>{e.load=original;};
      });
      await page.locator('#musicState').selectOption('boss');
      await page.waitForFunction(() => typeof window.releaseBoss==='function');
      await page.locator('#musicState').selectOption('exploration');
      await page.evaluate(() => {window.releaseBoss();window.restoreLoad();delete window.releaseBoss;delete window.restoreLoad;});
      await page.waitForTimeout(1000);
      const after=await snapshot();assert.equal(after.music,before.music);assert.equal(after.musicStarts,before.musicStarts);assert.equal(after.voices,3);return after;
    });
    await check('stop_is_immediate_and_remains_silent', async () => {
      await page.locator('#mixStop').click(); const immediate=await snapshot();
      assert.equal(immediate.voices,0); assert.equal(immediate.running,false);
      await page.waitForTimeout(900); const settled=await snapshot(); assert.equal(settled.voices,0);
      return {immediate,settled};
    });

    await check('mobile_390px_has_no_horizontal_overflow', async () => {
      await page.setViewportSize({width:390,height:844});
      const sizes=[];
      for (const id of ['libraryTab','mixTab']) {
        await page.locator('#'+id).click();
        const size=await page.evaluate(() => ({viewport:innerWidth,document:document.documentElement.scrollWidth,body:document.body.scrollWidth}));
        assert.ok(size.document<=size.viewport+1,`${id}: document overflow ${JSON.stringify(size)}`);
        assert.ok(size.body<=size.viewport+1,`${id}: body overflow ${JSON.stringify(size)}`); sizes.push({view:id,...size});
      }
      await screenshot('browser_mobile_390.png'); return sizes;
    });
    await check('no_script_errors_or_unexpected_failed_requests', async () => {
      assert.deepEqual(report.page_errors,[]); assert.deepEqual(report.console_errors,[]);
      assert.deepEqual(report.failed_requests,[]); assert.deepEqual(report.bad_responses,[]);
      assert.equal(await page.locator('#error').evaluate(e => e.hidden),true);
      return {page_errors:0,console_errors:0,failed_requests:0,bad_responses:0,expected_media_cancellations:report.expected_media_cancellations.length};
    });
  } catch (e) {report.checks.push({name:'test_harness',status:'fail',error:e.stack});}
  finally {await browser.close();}
  report.status=report.checks.every(c=>c.status==='pass')?'pass':'fail';
  if(output) fs.writeFileSync(path.join(output,'browser_validation.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({status:report.status,browser:report.browser,decoded:report.decoded.length,checks:report.checks.map(({name,status,error})=>({name,status,...(error?{error}:{})})),output:output||null},null,2));
  process.exitCode=report.status==='pass'?0:1;
})().catch(e=>{console.error(e);process.exitCode=1;});
