/* Independent resource audition; no game runtime or account access. */
'use strict';
const catalog = window.AUDIO_CATALOG;
const $ = id => document.getElementById(id);
const labels = {music: '音乐', sfx: '动作 / 交互', ambience: '环境 / 地标'};
const items = catalog.items;
const gain = db => Math.pow(10, db / 20);
const seconds = value => `${Number(value).toFixed(2)} s`;
let selected = null;
function error(message) { $('error').textContent = message; $('error').hidden = !message; }
function option(select, value, name) { const node = document.createElement('option'); node.value = value; node.textContent = name; select.append(node); }
for (const [id, name] of Object.entries(catalog.regions)) {
  option($('region'), id, name);
  if (id !== 'global') option($('mixRegion'), id, name);
}
for (const kind of Object.keys(labels)) {
  const span = document.createElement('span'); span.textContent = `${labels[kind]} ${items.filter(x => x.kind === kind).length}`; $('totals').append(span);
}
$('audition').volume = 0.35;
function stopAudition() { $('audition').pause(); }
function showItem(item) {
  engine.stop(); stopAudition(); selected = item; error('');
  $('detailKind').textContent = `${labels[item.kind]} · ${catalog.regions[item.region_id]}`;
  $('detailTitle').textContent = item.title;
  $('detailDescription').textContent = item.description || item.role;
  $('audition').src = item.url;
  $('audition').loop = item.loop;
  $('auditionLoop').checked = item.loop;
  $('sourceLink').href = item.url;
  $('detailMetadata').replaceChildren();
  for (const [key, value] of [['声音 ID', item.id], ['角色 / 事件', item.role], ['长度', seconds(item.duration_seconds)], ['格式', `48 kHz · ${item.channels === 2 ? '双声道' : '单声道'}`], ['建议增益', `${item.recommended_playback_gain_db} dB`], ['授权', item.license || 'CC0-1.0（新合成声音）']]) {
    const dt = document.createElement('dt'), dd = document.createElement('dd'); dt.textContent = key; dd.textContent = value; $('detailMetadata').append(dt, dd);
  }
  renderList();
}
function renderList() {
  const search = $('search').value.trim().toLowerCase();
  const visible = items.filter(x => ($('kind').value === 'all' || x.kind === $('kind').value) && ($('region').value === 'all' || x.region_id === $('region').value) && `${x.title} ${x.id} ${x.role} ${x.description || ''}`.toLowerCase().includes(search));
  $('trackList').replaceChildren();
  for (const item of visible) {
    const button = document.createElement('button'); button.className = 'track' + (selected?.key === item.key ? ' selected' : ''); button.dataset.key = item.key; button.setAttribute('aria-pressed', String(selected?.key === item.key));
    const title = document.createElement('span'), length = document.createElement('span'), sub = document.createElement('small');
    title.textContent = item.title; length.textContent = seconds(item.duration_seconds); length.className = 'duration'; sub.textContent = `${labels[item.kind]} · ${catalog.regions[item.region_id]} · ${item.loop ? '循环' : '单次'}`;
    button.append(title, length, sub); button.onclick = () => showItem(item); $('trackList').append(button);
  }
  if (!visible.length) { const p = document.createElement('p'); p.textContent = '没有匹配的声音。'; $('trackList').append(p); }
}
for (const id of ['kind', 'region', 'search']) $(id).addEventListener('input', renderList);
$('auditionLoop').onchange = () => { $('audition').loop = $('auditionLoop').checked; };
$('audition').addEventListener('error', () => error('音频未能打开。请确认完整下载了本分支，并使用附带的本机审阅服务。'));
$('audition').addEventListener('play', () => { engine.stop(); error(''); });

class MixEngine {
  constructor() {
    this.context = null; this.epoch = 0; this.musicEpoch = 0; this.running = false; this.voices = new Set(); this.cache = new Map(); this.currentMusic = null; this.musicStarts = 0; this.warningPending = false; this.lastWarning = -Infinity; this.region = 'ch06'; this.lastError = null;
  }
  init() {
    if (location.protocol === 'file:') throw new Error('场景混音需要本机服务：运行 README 中的 serve_review.py，再打开显示的地址。逐条音频仍可用本地文件试听。');
    if (this.context?.state === 'closed') { this.context = null; this.cache.clear(); }
    if (this.context) return;
    const Context = window.AudioContext || window.webkitAudioContext;
    if (!Context) throw new Error('此浏览器不支持 Web Audio，请使用现代浏览器。');
    this.context = new Context({sampleRate: 48000});
    this.lastWarning = -Infinity;
    const ctx = this.context;
    this.master = ctx.createGain(); this.master.gain.value = Number($('master').value) / 100; this.master.connect(ctx.destination);
    this.musicBus = ctx.createGain(); this.environmentBus = ctx.createGain(); this.cueBus = ctx.createGain();
    for (const bus of [this.musicBus, this.environmentBus, this.cueBus]) bus.connect(this.master);
  }
  profile() { return (catalog.mix_profiles.profiles || []).find(x => x.region_id === this.region) || {}; }
  find(kind, role) {
    const candidates = items.filter(x => x.kind === kind && x.region_id === this.region);
    return candidates.find(x => x.role === role) || candidates.find(x => x.id === `${this.region}_${role}`) || candidates.find(x => x.id.endsWith(`_${role}`));
  }
  musicItem(state) { return this.find('music', state === 'combat' ? 'combat_layer' : state); }
  async load(item) {
    if (!item) throw new Error('所选地区缺少该声音角色。请重新生成完整目录。');
    if (this.cache.has(item.key)) { const buffer = this.cache.get(item.key); this.cache.delete(item.key); this.cache.set(item.key, buffer); return buffer; }
    const response = await fetch(item.url);
    if (!response.ok) throw new Error(`声音加载失败：${item.id} (${response.status})`);
    const buffer = await this.context.decodeAudioData(await response.arrayBuffer());
    if (Math.abs(buffer.duration - item.duration_seconds) > 0.04) throw new Error(`解码时长不一致：${item.id}`);
    this.cache.set(item.key, buffer);
    while (this.cache.size > 4) this.cache.delete(this.cache.keys().next().value);
    return buffer;
  }
  voice(item, buffer, destination, startGain = 1, offset = 0) {
    const ctx = this.context, source = ctx.createBufferSource(), level = ctx.createGain();
    source.buffer = buffer; source.loop = item.loop;
    if (item.loop) { source.loopStart = (item.loop_start_sample || 0) / 48000; source.loopEnd = Math.min(buffer.duration, (item.loop_end_sample_exclusive || buffer.length) / 48000); }
    level.gain.value = gain(item.recommended_playback_gain_db) * startGain; source.connect(level); level.connect(destination);
    const voice = {source, level, item, started: ctx.currentTime, offset, cleanup: null};
    source.onended = () => { source.disconnect(); level.disconnect(); source.buffer = null; voice.cleanup?.(); this.voices.delete(voice); };
    source.start(0, Math.max(0, Math.min(offset, buffer.duration - 0.001))); this.voices.add(voice); return voice;
  }
  async start() {
    stopAudition(); this.stop(); error(''); this.init();
    const epoch = ++this.epoch; this.starting = true;
    await this.context.resume();
    if (epoch !== this.epoch) return;
    this.region = $('mixRegion').value; $('mixStatus').textContent = '正在解码本区声音…';
    const profile = this.profile();
    const bed = items.find(x => x.pack === 'audio_category_ambience' && x.id === profile.bed_cue_id) || this.find('ambience', 'bed');
    const landmark = items.find(x => x.pack === 'audio_category_ambience' && x.id === profile.landmark_cue_id) || this.find('ambience', 'landmark');
    const music = this.musicItem($('musicState').value);
    try {
      const buffers = await Promise.all([this.load(bed), this.load(landmark), this.load(music)]);
      if (epoch !== this.epoch) return;
      this.running = true; this.starting = false; this.environmentBus.gain.value = 1; this.musicBus.gain.value = 1;
      this.bed = this.voice(bed, buffers[0], this.environmentBus);
      this.createSpatial(landmark, buffers[1]);
      this.currentMusic = this.voice(music, buffers[2], this.musicBus); this.musicStarts++;
      this.applySpatial(); this.status();
    } catch (e) { if (epoch === this.epoch) { this.stop(); this.lastError = e.message; throw e; } }
  }
  createSpatial(item, buffer) {
    const ctx = this.context, profile = this.profile();
    this.filter = ctx.createBiquadFilter(); this.filter.type = 'lowpass'; this.filter.frequency.value = 20000;
    this.distanceGain = ctx.createGain(); this.panner = ctx.createStereoPanner(); this.wet = ctx.createGain();
    const convolver = ctx.createConvolver(); const decay = Math.min(6, profile.reverb?.decay_seconds || 1.5);
    const impulse = ctx.createBuffer(2, Math.ceil(ctx.sampleRate * decay), ctx.sampleRate); let seed = 417;
    for (let ch = 0; ch < 2; ch++) { const data = impulse.getChannelData(ch); for (let i = 0; i < data.length; i++) { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; data[i] = (seed / 2147483648 - 1) * Math.pow(1 - i / data.length, 2.5) * 0.25; } }
    convolver.buffer = impulse;
    const predelay = ctx.createDelay(0.2); predelay.delayTime.value = Math.min(0.2, (profile.reverb?.predelay_ms || 0) / 1000);
    this.filter.connect(this.distanceGain); this.distanceGain.connect(this.panner); this.panner.connect(this.environmentBus); this.panner.connect(predelay); predelay.connect(convolver); convolver.connect(this.wet); this.wet.connect(this.environmentBus);
    this.landmark = this.voice(item, buffer, this.filter);
    const nodes = [this.filter, this.distanceGain, this.panner, predelay, convolver, this.wet]; this.landmark.cleanup = () => nodes.forEach(x => x.disconnect());
  }
  applySpatial() {
    const distance = Number($('distance').value), pan = Number($('pan').value) / 100, occluded = $('occluded').checked;
    $('distanceValue').textContent = `${distance} m`; $('distanceLabel').textContent = `距离 ${distance} 米`; $('panValue').textContent = pan.toFixed(2); $('occlusionLabel').textContent = occluded ? '隔墙遮挡' : '无遮挡';
    document.querySelector('.soundstage').classList.toggle('occluded', occluded);
    document.querySelector('.landmark').style.left = `${50 + pan * 36}%`;
    document.querySelector('.landmark').style.top = `${18 + Math.min(distance, 40) * 0.65}%`;
    if (!this.running) return;
    const profile = this.profile(), spatial = profile.landmark_spatial || {}, near = spatial.near_distance_m || 2, far = spatial.far_distance_m || 35;
    const attenuation = Math.max(0, 1 - Math.max(0, distance - near) / Math.max(1, far - near));
    const occlusionDb = spatial.occluded?.gain_db ?? -9; const now = this.context.currentTime;
    this.distanceGain.gain.setTargetAtTime(attenuation * (occluded ? gain(occlusionDb) : 1), now, 0.06);
    this.filter.frequency.setTargetAtTime(occluded ? (spatial.occluded?.lowpass_hz || 1600) : 20000, now, 0.06);
    this.panner.pan.setTargetAtTime(pan, now, 0.04);
    this.wet.gain.setTargetAtTime($('reverb').checked ? (profile.reverb?.wet ?? 0.15) : 0, now, 0.05);
  }
  async switchMusic(state) {
    const request = ++this.musicEpoch;
    if (this.starting) return this.start();
    if (!this.running) return;
    const item = this.musicItem(state); if (this.currentMusic?.item.key === item?.key) return;
    const epoch = this.epoch;
    const buffer = await this.load(item);
    if (epoch !== this.epoch || request !== this.musicEpoch || !this.running) return;
    const old = this.currentMusic, ctx = this.context, now = ctx.currentTime, duration = 0.75;
    // Same-region exploration/Boss pair share loop lengths. Other arrangements
    // enter at their beginning; this preview does not claim bar-synchronous game mixing.
    const paired = old && ['exploration', 'boss'].includes(old.item.role) && ['exploration', 'boss'].includes(item.role) && Math.abs(old.source.buffer.duration - buffer.duration) < 0.01;
    const offset = paired ? (now - old.started + old.offset) % buffer.duration : 0;
    const next = this.voice(item, buffer, this.musicBus, 0, offset);
    const curveIn = new Float32Array(33), curveOut = new Float32Array(33);
    const prior = old?.level.gain.value || 0;
    for (let i = 0; i < 33; i++) { curveIn[i] = Math.sin(i / 32 * Math.PI / 2) * gain(item.recommended_playback_gain_db); curveOut[i] = Math.cos(i / 32 * Math.PI / 2) * prior; }
    next.level.gain.setValueCurveAtTime(curveIn, now, duration);
    if (old) { old.level.gain.cancelScheduledValues(now); old.level.gain.setValueCurveAtTime(curveOut, now, duration); old.source.stop(now + duration + 0.02); }
    this.currentMusic = next; this.musicStarts++; this.status();
  }
  async warning() {
    if (!this.running) { $('mixStatus').textContent = '请先开始场景，再比较预警让位。'; return; }
    if (this.warningPending || this.context.currentTime - this.lastWarning < 0.5) return;
    this.warningPending = true;
    const epoch = this.epoch, item = items.find(x => x.pack === 'reverse_audio' && x.region_id === this.region && x.role === 'warning');
    try {
      const buffer = await this.load(item); if (epoch !== this.epoch || !this.running) return;
      const now = this.context.currentTime; this.lastWarning = now;
      this.voice(item, buffer, this.cueBus);
      const config = this.profile().warning_duck || {}; const amount = config.gain_db ?? -8;
      for (const bus of [this.musicBus, this.environmentBus]) {
        if (bus.gain.cancelAndHoldAtTime) bus.gain.cancelAndHoldAtTime(now); else bus.gain.cancelScheduledValues(now);
        bus.gain.linearRampToValueAtTime(gain(amount), now + (config.attack_ms || 35) / 1000);
        bus.gain.setTargetAtTime(1, now + buffer.duration + (config.hold_ms || 120) / 1000, (config.release_ms || 500) / 3000);
      }
      $('mixStatus').textContent = '预警前景播放；音乐与环境暂时降低，随后恢复。';
    } finally { if (epoch === this.epoch) this.warningPending = false; }
  }
  status() { $('mixStatus').textContent = this.running ? `正在播放：${catalog.regions[this.region]} · ${this.currentMusic?.item.title || ''}` : '已停止。'; $('stageRegion').textContent = catalog.regions[this.region]; }
  stop() {
    this.epoch++; this.musicEpoch++; this.running = false; this.starting = false; this.currentMusic = null; this.warningPending = false;
    for (const voice of [...this.voices]) { try { voice.source.stop(); } catch (_) {} voice.source.disconnect(); voice.level.disconnect(); voice.cleanup?.(); voice.source.buffer = null; }
    this.voices.clear();
    for (const bus of [this.musicBus, this.environmentBus]) if (bus) { bus.gain.cancelScheduledValues(0); bus.gain.value = 1; }
    this.status();
  }
  snapshot() { return {running: this.running, voices: this.voices.size, cached: this.cache.size, music: this.currentMusic?.item.id || null, musicStarts: this.musicStarts, region: this.region, contextState: this.context?.state || 'uninitialized', filterHz: this.filter?.frequency.value, distanceGain: this.distanceGain?.gain.value, musicBusGain: this.musicBus?.gain.value, error: this.lastError}; }
}
const engine = new MixEngine();
const perform = fn => async () => { try { error(''); await fn(); } catch (e) { error(e.message); } };
$('mixPlay').onclick = perform(() => engine.start());
$('mixStop').onclick = () => { engine.stop(); stopAudition(); };
$('warning').onclick = perform(() => engine.warning());
$('musicState').onchange = perform(() => engine.switchMusic($('musicState').value));
$('mixRegion').onchange = () => { engine.stop(); engine.region = $('mixRegion').value; engine.status(); error(''); };
for (const id of ['distance', 'pan', 'occluded', 'reverb']) $(id).addEventListener('input', () => engine.applySpatial());
$('master').oninput = () => { const value = Number($('master').value); $('masterValue').textContent = `${value}%`; if (engine.context) engine.master.gain.setTargetAtTime(value / 100, engine.context.currentTime, 0.02); };
function tab(mix) {
  engine.stop(); stopAudition(); error('');
  $('libraryView').hidden = mix; $('mixView').hidden = !mix;
  for (const [id, active] of [['libraryTab', !mix], ['mixTab', mix]]) { $(id).classList.toggle('selected', active); $(id).setAttribute('aria-pressed', String(active)); }
}
$('libraryTab').onclick = () => tab(false); $('mixTab').onclick = () => tab(true);
document.addEventListener('visibilitychange', () => { if (document.hidden) { stopAudition(); engine.stop(); } });
window.addEventListener('pagehide', () => { stopAudition(); engine.stop(); engine.cache.clear(); if (engine.context) engine.context.close().catch(() => {}); });
window.__audioReview = {engine, items, showItem, renderList};
if (items.length) showItem(items[0]); else renderList();
