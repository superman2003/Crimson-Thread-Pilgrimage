"use strict";
(() => {
  const $ = id => document.getElementById(id);
  const canvas = $("canvas"), ctx = canvas.getContext("2d");
  const audio = $("audio");
  const regions = {ch06:"CH06 · 无声王冠",ch05:"CH05 · 黑曜巡礼道",ch04:"CH04 · 断弦温室",ch03:"CH03 · 盐白书库",ch02:"CH02 · 铸雨渠",ch01:"CH01 · 苔钟庭"};
  const crests = {crimson:"缝名契印",bell:"司铸契印",salt:"校录契印"};
  let all = [], kind = "animation", current = null, images = [], frame = 0;
  let playing = false, previousTime = null, accumulator = 0, requestId = null, selection = 0;
  const el = (tag, text, className) => { const e = document.createElement(tag); if (text !== undefined) e.textContent = text; if (className) e.className = className; return e; };
  const category = item => item.type === "animation" ? (crests[item.crest_id] || item.crest_id || "动作") : (regions[item.region_id] || item.region_id || "六区");
  const role = item => item.type === "audio" ? (item.role === "boss" ? "BOSS / 守门者" : "EXPLORATION / 探索") : item.type === "layers" ? "LAYERED SCENERY / 分层场景" : "MOTION STUDY / 动作研究";
  function stop() {
    playing = false; previousTime = null; accumulator = 0;
    if (requestId !== null) cancelAnimationFrame(requestId);
    requestId = null; $("play").textContent = "播放";
  }
  function stopAudio() { audio.pause(); audio.removeAttribute("src"); audio.load(); }
  function frameUI() {
    $("frame").value = String(frame); $("frame-label").value = `${frame + 1}/${current.frame_count}`;
    for (const event of $("events").children) event.classList.toggle("active", Number(event.dataset.frame) === frame);
  }
  function draw() {
    if (!current || current.type === "audio" || !images.length) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (current.type === "animation") {
      const fw = current.frame_width, fh = current.frame_height;
      // A constant cell scale preserves the authored pose displacement and pivot.
      const scale = Math.min(canvas.width / fw * .68, canvas.height / fh * .9);
      const w = fw * scale, h = fh * scale;
      ctx.drawImage(images[0], (frame % current.columns) * fw, Math.floor(frame / current.columns) * fh,
        fw, fh, (canvas.width - w) / 2, (canvas.height - h) / 2, w, h);
      frameUI();
    } else {
      const pan = Number($("pan").value) / 100;
      current.layers.forEach((layer, i) => {
        if (!$("layer-options").querySelectorAll("input")[i].checked) return;
        const margin = canvas.width * .045;
        ctx.drawImage(images[i], -margin + pan * margin * layer.parallax, -canvas.height * .045,
          canvas.width + margin * 2, canvas.height * 1.09);
      });
    }
  }
  function tick(time) {
    if (!playing || !current || current.type !== "animation") return;
    if (previousTime === null) previousTime = time;
    accumulator += Math.min(time - previousTime, 150) * Number($("speed").value);
    previousTime = time;
    const duration = 1000 / current.fps;
    while (accumulator >= duration) {
      accumulator -= duration;
      if (frame === current.frame_count - 1) {
        if ($("repeat").checked) frame = 0;
        else { stop(); draw(); return; }
      } else frame++;
    }
    draw(); requestId = requestAnimationFrame(tick);
  }
  async function loadImage(url) {
    const image = new Image(); image.src = url;
    await image.decode(); return image;
  }
  function fact(text) { $("facts").append(el("span", text, "fact")); }
  async function select(item) {
    const token = ++selection;
    stop(); stopAudio(); current = item; images = []; frame = 0;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    $("message").textContent = ""; $("description").textContent = item.description || "";
    $("item-title").textContent = item.title; $("item-category").textContent = `${category(item)} / ${role(item)}`;
    $("facts").replaceChildren(); $("events").replaceChildren(); $("layer-options").replaceChildren();
    $("visual-panel").hidden = item.type === "audio"; $("audio-panel").hidden = item.type !== "audio";
    $("motion-controls").hidden = item.type !== "animation"; $("scene-controls").hidden = item.type !== "layers";
    $("source-link").hidden = !item.url && !item.preview_url;
    $("source-link").href = item.url || item.preview_url || "#";
    for (const button of $("items").children) button.setAttribute("aria-pressed", String(button.dataset.id === item.id));
    if (item.type === "audio") {
      $("sound-region").textContent = (item.region_id || "MUSIC").toUpperCase();
      audio.src = item.url; audio.loop = $("audio-loop").checked;
      fact(item.role === "boss" ? "Boss 编排" : "探索编排"); fact(`${item.bpm} BPM`);
      fact(`${Number(item.duration_seconds).toFixed(2)} 秒`); fact(item.loop ? "循环素材" : "非循环素材");
      return;
    }
    $("play").disabled = true; $("previous").disabled = true; $("next").disabled = true; $("frame").disabled = true;
    if (item.type === "animation") {
      canvas.width = 768; canvas.height = 512; $("frame").max = String(item.frame_count - 1);
      $("frame").value = "0"; $("repeat").checked = item.loop;
      $("stage-label").textContent = "动作研究 · 固定帧格 / 未接入命中判定";
      fact(`${item.frame_count} 帧`); fact(`${item.fps} FPS`); fact(`${item.frame_width} × ${item.frame_height} px`);
      fact(item.loop ? "循环动作" : "单次动作");
      (item.events || []).forEach(event => { const badge = el("span", `第 ${event.frame + 1} 帧 · ${event.name}`, "event"); badge.dataset.frame = event.frame; $("events").append(badge); });
      frameUI();
    } else {
      canvas.width = item.width; canvas.height = item.height; $("pan").value = "0";
      $("stage-label").textContent = "场景素材 · 预览缩放 109% / 不含碰撞";
      fact(`${item.layers.length} 个独立图层`); fact(`${item.width} × ${item.height} px`); fact("装饰 / 非落脚平台");
      item.layers.forEach(layer => { const label = el("label", undefined, "check"), input = el("input"); input.type = "checkbox"; input.checked = true; input.addEventListener("change", draw); label.append(input, document.createTextNode(layer.title)); $("layer-options").append(label); });
    }
    try {
      const loaded = await Promise.all((item.type === "animation" ? [item.url] : item.layers.map(layer => layer.url)).map(loadImage));
      if (token !== selection) return;
      images = loaded; draw();
      $("play").disabled = false; $("previous").disabled = false; $("next").disabled = false; $("frame").disabled = false;
    } catch (_) {
      if (token === selection) $("message").textContent = "素材无法读取。请保留仓库目录结构，检查文件已下载；或在仓库根目录启动本地静态服务。";
    }
  }
  function renderList() {
    const value = $("filter").value;
    const items = all.filter(item => item.type === kind && (!value || (kind === "animation" ? item.crest_id : item.region_id) === value));
    $("items").replaceChildren(); $("count").textContent = `${items.length} 项`;
    for (const item of items) {
      const button = el("button", undefined, "item"); button.type = "button"; button.dataset.id = item.id;
      button.append(el("strong", item.title), el("small", category(item)));
      button.addEventListener("click", () => select(item)); $("items").append(button);
    }
    if (items.length) select(items[0]);
    else { stop(); stopAudio(); ++selection; current = null; $("message").textContent = "当前筛选没有素材。"; }
  }
  function setKind(next) {
    kind = next;
    for (const tab of document.querySelectorAll("[data-kind]")) tab.setAttribute("aria-pressed", String(tab.dataset.kind === kind));
    $("filter").replaceChildren();
    const choices = kind === "animation" ? crests : regions;
    const first = el("option", kind === "animation" ? "全部契印" : "全部地区 · CH06 → CH01"); first.value = ""; $("filter").append(first);
    Object.entries(choices).forEach(([value, title]) => { const option = el("option", title); option.value = value; $("filter").append(option); });
    renderList();
  }
  $("play").addEventListener("click", () => {
    if (playing) { stop(); return; }
    if (!current || !images.length) return;
    if (frame === current.frame_count - 1) frame = 0;
    playing = true; previousTime = null; $("play").textContent = "暂停"; requestId = requestAnimationFrame(tick);
  });
  $("previous").addEventListener("click", () => { stop(); frame = Math.max(0, frame - 1); draw(); });
  $("next").addEventListener("click", () => { stop(); frame = Math.min(current.frame_count - 1, frame + 1); draw(); });
  $("frame").addEventListener("input", () => { stop(); frame = Number($("frame").value); draw(); });
  $("pan").addEventListener("input", draw);
  $("reset-pan").addEventListener("click", () => { $("pan").value = "0"; draw(); });
  $("filter").addEventListener("change", renderList);
  $("audio-loop").addEventListener("change", () => { audio.loop = $("audio-loop").checked; });
  $("volume").addEventListener("input", () => { audio.volume = Number($("volume").value) / 100; audio.muted = false; });
  audio.addEventListener("volumechange", () => {
    const percent = Math.round(audio.volume * 100);
    $("volume").value = String(percent); $("volume-label").value = audio.muted ? "静音" : `${percent}%`;
  });
  audio.volume = .4;
  audio.addEventListener("error", () => { if (current?.type === "audio" && audio.hasAttribute("src")) $("message").textContent = "音乐无法播放。请检查本地文件完整性与浏览器 OGG 支持。"; });
  document.addEventListener("visibilitychange", () => { if (document.hidden) { stop(); audio.pause(); } });
  window.addEventListener("pagehide", () => { stop(); audio.pause(); });
  document.querySelectorAll("[data-kind]").forEach(button => button.addEventListener("click", () => setKind(button.dataset.kind)));
  if (!window.MEDIA_CATALOG?.packs?.length) { $("message").textContent = "素材目录缺失。请先运行 tools/proposals/reverse_media_v2/build_review.py。"; return; }
  all = window.MEDIA_CATALOG.packs.flatMap(pack => pack.items);
  setKind("animation");
})();
