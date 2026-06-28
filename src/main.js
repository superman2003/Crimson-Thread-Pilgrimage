import { CHAPTERS, SETTINGS } from "./gameData.js";

const canvas = document.querySelector("#game");
const ctx = canvas.getContext("2d");
const menu = document.querySelector("#menu");
const startButton = document.querySelector("#startButton");
const resetButton = document.querySelector("#resetButton");
const chapterList = document.querySelector("#chapterList");
const chapterMark = document.querySelector("#chapterMark");
const chapterName = document.querySelector("#chapterName");
const chapterObjective = document.querySelector("#chapterObjective");
const hpFill = document.querySelector("#hpFill");
const bossFill = document.querySelector("#bossFill");
const statusPill = document.querySelector("#statusPill");

const TAU = Math.PI * 2;
const FLOOR = SETTINGS.floorY;
const WORLD_W = SETTINGS.levelWidth;
const HERO_FRAME_ROOT = "godot/assets/sprites/player/generated_hero_v2/frames";
const HERO_FRAME_NAMES = [
  "idle_00", "idle_01", "idle_02", "idle_03",
  "run_00", "run_01", "run_02", "run_03",
  "jump_00", "fall_00", "dash_00", "hurt_00",
  "wall_cling_00", "land_00", "crouch_00", "interact_00",
  "attack_00", "attack_01", "attack_02", "attack_03",
  "air_attack_00", "hook_throw_00", "skill_burst_00", "guard_00",
  "heal_00", "item_use_00", "map_look_00", "victory_00",
  "death_00", "death_01", "death_02", "respawn_00"
];

const ASSET_PATHS = {
  player: "godot/assets/sprites/player/generated_hero_v2/frames/idle_00.png",
  playerFrames: Object.fromEntries(HERO_FRAME_NAMES.map((name) => [name, `${HERO_FRAME_ROOT}/${name}.png`])),
  background: "godot/assets/sprites/gothicvania/demo/bg_ch01_sky.png",
  backdrop: "godot/assets/sprites/gothicvania/demo/bg_ch01_near_vines.png",
  tile: "godot/assets/sprites/gothicvania/demo/platform_moss_stone.png",
  bridge: "godot/assets/sprites/gothicvania/demo/platform_bronze_bridge.png",
  bossTile: "godot/assets/sprites/gothicvania/demo/platform_boss_stone.png",
  enemies: {
    crawler: "godot/assets/sprites/gothicvania/demo/enemy_moss_larva.png",
    flyer: "godot/assets/sprites/gothicvania/demo/enemy_bronze_moth.png",
    shooter: "godot/assets/sprites/gothicvania/demo/enemy_spore_bellmaker.png",
    charger: "godot/assets/sprites/gothicvania/demo/enemy_gear_sentinel.png"
  },
  boss: "godot/assets/sprites/gothicvania/demo/boss_rust_crown_guardian.png",
  key: "godot/assets/sprites/gothicvania/demo/pickup_bell_key.png",
  lever: "godot/assets/sprites/gothicvania/demo/shortcut_lever.png",
  bossGate: "godot/assets/sprites/gothicvania/demo/boss_gate.png"
};

const AUDIO_PATHS = {
  start: "godot/assets/audio/sfx/interact.ogg",
  jump: "godot/assets/audio/sfx/player_jump.ogg",
  dash: "godot/assets/audio/sfx/player_dash.ogg",
  attack: "godot/assets/audio/sfx/player_attack.ogg",
  hit: "godot/assets/audio/sfx/enemy_hit.ogg",
  bossHit: "godot/assets/audio/sfx/heavy_hit.ogg",
  boss: "godot/assets/audio/sfx/heavy_hit.ogg",
  hurt: "godot/assets/audio/sfx/player_hurt.ogg",
  clear: "godot/assets/audio/sfx/pickup.ogg"
};

const VISUAL_BOUNDS = {
  player: { w: 128, h: 128, yOffset: 9 },
  enemy: { w: 96, h: 96, yOffset: 10 },
  boss: { w: 168, h: 168, yOffset: 18 }
};

const PLAYER_TUNING = {
  coyoteTime: 0.12,
  jumpBufferTime: 0.12,
  jumpVelocity: -710,
  jumpCutMultiplier: 0.48,
  groundAccel: 2300,
  airAccel: 1600,
  groundMaxSpeed: 285,
  airMaxSpeed: 305,
  groundFriction: 2200,
  airFriction: 520,
  dashTime: 0.16,
  dashCooldown: 0.72,
  dashSpeed: 780,
  attackLunge: 96
};

const PLAYER_ANIMS = {
  idle: ["idle_00", "idle_01", "idle_02", "idle_03"],
  run: ["run_00", "run_01", "run_02", "run_03"],
  attack: ["attack_00", "attack_01", "attack_02", "attack_03"]
};

const BOSS_SPECIALS_BY_CHAPTER = [
  [
    {
      id: "boss_01_atk_01",
      name: "Moss Bell Liturgy",
      color: "#78c26d",
      frames: makeBossSpecialFramePaths("boss_01_moss_bell_matriarch", "boss_01_atk_01")
    },
    {
      id: "boss_01_atk_02",
      name: "Cradle of Roots",
      color: "#6fa85d",
      frames: makeBossSpecialFramePaths("boss_01_moss_bell_matriarch", "boss_01_atk_02")
    },
    {
      id: "boss_01_atk_03",
      name: "Matriarch Chime Rain",
      color: "#a7d66f",
      frames: makeBossSpecialFramePaths("boss_01_moss_bell_matriarch", "boss_01_atk_03")
    }
  ]
];

const input = {
  left: false,
  right: false,
  jump: false,
  dash: false,
  attack: false,
  jumpPressed: false,
  jumpReleased: false,
  dashPressed: false,
  attackPressed: false
};

const keys = new Map([
  ["ArrowLeft", "left"],
  ["KeyA", "left"],
  ["ArrowRight", "right"],
  ["KeyD", "right"],
  ["ArrowUp", "jump"],
  ["KeyW", "jump"],
  ["Space", "jump"],
  ["ShiftLeft", "dash"],
  ["ShiftRight", "dash"],
  ["KeyK", "dash"],
  ["KeyJ", "attack"],
  ["KeyX", "attack"]
]);

const state = {
  mode: "menu",
  chapterIndex: 0,
  unlocked: loadUnlocks(),
  time: 0,
  cameraX: 0,
  shake: 0,
  player: null,
  enemies: [],
  boss: null,
  projectiles: [],
  attacks: [],
  keyPickups: [],
  keys: 0,
  shortcutOpen: false,
  hitStop: 0,
  lastEvent: "待启程",
  particles: [],
  chapterClearTimer: 0,
  messageTimer: 0
};

const audio = {
  ctx: null,
  clips: buildAudioClips()
};

const assets = buildAssets();
resizeCanvas();
renderChapterList();
updateHud();
requestAnimationFrame(loop);

window.addEventListener("resize", resizeCanvas);
window.addEventListener("keydown", onKeyDown);
window.addEventListener("keyup", onKeyUp);

startButton.addEventListener("click", () => startChapter(Math.min(state.unlocked - 1, state.chapterIndex)));
resetButton.addEventListener("click", resetProgress);

document.querySelectorAll("[data-key]").forEach((button) => {
  const key = button.dataset.key;
  button.addEventListener("pointerdown", (event) => {
    event.preventDefault();
    setInput(key, true);
  });
  button.addEventListener("pointerup", (event) => {
    event.preventDefault();
    setInput(key, false);
  });
  button.addEventListener("pointercancel", () => setInput(key, false));
});

window.__crimsonThreadQA = {
  startChapter(index = 0) {
    const safeIndex = clamp(Math.trunc(index), 0, CHAPTERS.length - 1);
    state.unlocked = Math.max(state.unlocked, safeIndex + 1);
    saveUnlocks();
    startChapter(safeIndex, { silent: true });
    return snapshot();
  },
  completeChapter() {
    finishChapter();
    return snapshot();
  },
  startBossTrial(index = 0) {
    const safeIndex = clamp(Math.trunc(index), 0, CHAPTERS.length - 1);
    state.unlocked = Math.max(state.unlocked, safeIndex + 1);
    saveUnlocks();
    startBossTrial(safeIndex, { silent: true });
    return snapshot();
  },
  collectAllKeys() {
    for (const key of state.keyPickups) key.taken = true;
    state.keys = state.keyPickups.length;
    state.lastEvent = `钟钥 ${state.keys}/${state.keyPickups.length}`;
    updateHud();
    return snapshot();
  },
  openShortcut() {
    state.keys = state.keyPickups.length;
    state.shortcutOpen = true;
    state.lastEvent = "捷径已打开";
    updateHud();
    return snapshot();
  },
  strikeFirstEnemy() {
    const chapter = CHAPTERS[state.chapterIndex];
    const target = state.enemies.find((enemy) => !enemy.dead) || state.boss;
    if (target) damageEnemy(target, 1, chapter);
    updateHud();
    return snapshot();
  },
  snapshot,
  visualMetrics
};

const bootParams = new URLSearchParams(window.location.search);
if (bootParams.has("boss")) {
  const requested = Number(bootParams.get("boss"));
  const chapterIndex = Number.isFinite(requested) ? requested - 1 : 0;
  startBossTrial(clamp(Math.trunc(chapterIndex), 0, CHAPTERS.length - 1), { silent: true });
}

function loop(now) {
  const dt = Math.min((now - (loop.last || now)) / 1000, 0.033);
  loop.last = now;
  update(dt);
  draw();
  input.jumpPressed = false;
  input.jumpReleased = false;
  input.dashPressed = false;
  input.attackPressed = false;
  requestAnimationFrame(loop);
}

function resizeCanvas() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = SETTINGS.width * dpr;
  canvas.height = SETTINGS.height * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function onKeyDown(event) {
  const action = keys.get(event.code);
  if (!action) {
    if (event.code === "Enter" && state.mode !== "playing") {
      startChapter(Math.min(state.unlocked - 1, state.chapterIndex));
    }
    if (event.code === "KeyR" && state.mode === "playing") {
      startChapter(state.chapterIndex);
    }
    return;
  }
  event.preventDefault();
  setInput(action, true);
}

function onKeyUp(event) {
  const action = keys.get(event.code);
  if (!action) return;
  event.preventDefault();
  setInput(action, false);
}

function setInput(action, value) {
  if (value && !input[action]) {
    if (action === "jump") input.jumpPressed = true;
    if (action === "dash") input.dashPressed = true;
    if (action === "attack") input.attackPressed = true;
  } else if (!value && action === "jump" && input.jump) {
    input.jumpReleased = true;
  }
  input[action] = value;
}

function startChapter(index, options = {}) {
  ensureAudio();
  const chapter = CHAPTERS[index];
  state.mode = "playing";
  state.chapterIndex = index;
  state.time = 0;
  state.cameraX = 0;
  state.shake = 0;
  state.chapterClearTimer = 0;
  state.messageTimer = 1.6;
  state.projectiles = [];
  state.attacks = [];
  state.particles = [];
  state.keyPickups = (chapter.keys || []).map((key, keyIndex) => ({ ...key, id: `k-${index}-${keyIndex}`, taken: false }));
  state.keys = 0;
  state.shortcutOpen = false;
  state.hitStop = 0;
  state.lastEvent = "寻找钟钥";
  state.player = createPlayer(chapter.spawn);
  state.enemies = chapter.enemies.map((entry, enemyIndex) => createEnemy(entry, enemyIndex, index));
  state.boss = createBoss(chapter.boss, index);
  menu.classList.add("is-hidden");
  if (!options.silent) playTone("start");
  updateHud();
}

function startBossTrial(index, options = {}) {
  startChapter(index, options);
  const chapter = CHAPTERS[state.chapterIndex];
  state.enemies = [];
  state.keyPickups = (chapter.keys || []).map((key, keyIndex) => ({ ...key, id: `k-${index}-${keyIndex}`, taken: true }));
  state.keys = state.keyPickups.length;
  state.shortcutOpen = true;
  state.projectiles = [];
  state.attacks = [];
  state.particles = [];
  state.player.x = Math.max(0, chapter.boss.x - 420);
  state.player.y = 370;
  state.player.vx = 0;
  state.player.vy = 0;
  state.player.face = 1;
  state.player.health = state.player.maxHealth;
  state.boss = createBoss(chapter.boss, state.chapterIndex);
  state.boss.x = chapter.boss.x;
  state.boss.y = chapter.boss.y;
  state.boss.baseY = chapter.boss.y;
  state.boss.dir = -1;
  state.boss.attackTimer = 0.5;
  state.cameraX = clamp(state.player.x - SETTINGS.width * 0.43, 0, WORLD_W - SETTINGS.width);
  state.lastEvent = "Boss Trial";
  updateHud();
  if (!options.silent) playTone("start");
}

function resetProgress() {
  state.unlocked = 1;
  state.chapterIndex = 0;
  saveUnlocks();
  renderChapterList();
  state.mode = "menu";
  menu.classList.remove("is-hidden");
  updateHud();
}

function createPlayer(spawn) {
  return {
    x: spawn.x,
    y: spawn.y,
    w: 34,
    h: 54,
    vx: 0,
    vy: 0,
    face: 1,
    health: SETTINGS.playerMaxHealth,
    maxHealth: SETTINGS.playerMaxHealth,
    grounded: false,
    coyote: 0,
    jumpBuffer: 0,
    landTimer: 0,
    lastGroundedY: spawn.y,
    dashTimer: 0,
    dashCooldown: 0,
    attackCooldown: 0,
    invuln: 0,
    hazardLatch: 0
  };
}

function createEnemy(entry, enemyIndex, chapterIndex) {
  const stats = {
    crawler: { w: 42, h: 34, hp: 8, speed: 58 },
    flyer: { w: 46, h: 38, hp: 7, speed: 62 },
    shooter: { w: 44, h: 48, hp: 9, speed: 0 },
    charger: { w: 48, h: 38, hp: 12, speed: 78 }
  }[entry.kind];

  return {
    id: `e-${chapterIndex}-${enemyIndex}`,
    kind: entry.kind,
    name: entry.name,
    x: entry.x,
    y: entry.y,
    baseY: entry.y,
    homeX: entry.x,
    w: stats.w,
    h: stats.h,
    hp: stats.hp + chapterIndex,
    maxHp: stats.hp + chapterIndex,
    speed: stats.speed + chapterIndex * 4,
    range: entry.range,
    dir: enemyIndex % 2 === 0 ? 1 : -1,
    phase: enemyIndex * 0.9 + chapterIndex,
    fireTimer: 0.7 + enemyIndex * 0.25,
    pendingShot: false,
    alertTimer: 0,
    stunTimer: 0,
    windupTimer: 0,
    chargeTimer: 0,
    chargeCooldown: 1.4,
    hitFlash: 0,
    dead: false
  };
}

function createBoss(entry, chapterIndex) {
  return {
    id: `boss-${chapterIndex}`,
    kind: "boss",
    name: entry.name,
    pattern: entry.pattern,
    x: entry.x,
    y: entry.y,
    baseY: entry.y,
    w: 84,
    h: 88,
    vx: 0,
    vy: 0,
    hp: entry.hp,
    maxHp: entry.hp,
    dir: -1,
    phase: chapterIndex,
    attackTimer: 1.1,
    specialAttackIndex: 0,
    specialAttack: "",
    specialAttackName: "",
    specialAttackColor: "",
    attackAnimTimer: 0,
    attackAnimTotal: 0,
    attackVfxTimer: 0,
    alertTimer: 0,
    hitFlash: 0,
    dead: false
  };
}

function update(dt) {
  state.time += dt;
  state.shake = Math.max(0, state.shake - dt * 18);
  state.particles = state.particles.filter((particle) => {
    particle.life -= dt;
    particle.x += particle.vx * dt;
    particle.y += particle.vy * dt;
    particle.vy += 440 * dt;
    return particle.life > 0;
  });

  if (state.mode !== "playing") return;

  if (state.hitStop > 0) {
    state.hitStop = Math.max(0, state.hitStop - dt);
    updateHud();
    return;
  }

  updatePlayer(dt);
  updateEnemies(dt);
  updateBoss(dt);
  updateProjectiles(dt);
  updateAttacks(dt);
  checkExit();
  updateHud();
}

function updatePlayer(dt) {
  const player = state.player;
  const chapter = CHAPTERS[state.chapterIndex];
  player.invuln = Math.max(0, player.invuln - dt);
  player.attackCooldown = Math.max(0, player.attackCooldown - dt);
  player.dashCooldown = Math.max(0, player.dashCooldown - dt);
  player.hazardLatch = Math.max(0, player.hazardLatch - dt);
  player.jumpBuffer = input.jumpPressed ? PLAYER_TUNING.jumpBufferTime : Math.max(0, player.jumpBuffer - dt);
  player.landTimer = Math.max(0, player.landTimer - dt);
  player.coyote = player.grounded ? PLAYER_TUNING.coyoteTime : Math.max(0, player.coyote - dt);

  const moveAxis = (input.right ? 1 : 0) - (input.left ? 1 : 0);
  if (moveAxis !== 0) player.face = moveAxis;

  if (input.dashPressed && player.dashCooldown <= 0) {
    player.dashTimer = PLAYER_TUNING.dashTime;
    player.dashCooldown = PLAYER_TUNING.dashCooldown;
    player.vx = player.face * PLAYER_TUNING.dashSpeed;
    player.vy *= 0.35;
    player.invuln = Math.max(player.invuln, 0.18);
    state.lastEvent = "冲刺";
    playTone("dash");
    spawnParticles(player.x + player.w / 2, player.y + player.h / 2, chapter.palette.accent, 18);
  }

  if (input.attackPressed && player.attackCooldown <= 0) {
    player.attackCooldown = 0.24;
    player.vx += player.face * (player.grounded ? PLAYER_TUNING.attackLunge : PLAYER_TUNING.attackLunge * 0.48);
    const attack = {
      x: player.face > 0 ? player.x + player.w - 4 : player.x - 64,
      y: player.y + 9,
      w: 72,
      h: 36,
      face: player.face,
      life: 0.11,
      maxLife: 0.11,
      damage: 5,
      hit: new Set()
    };
    state.attacks.push(attack);
    state.lastEvent = "挥刃";
    playTone("attack");
  }

  if (player.jumpBuffer > 0 && (player.grounded || player.coyote > 0)) {
    player.vy = PLAYER_TUNING.jumpVelocity;
    player.grounded = false;
    player.coyote = 0;
    player.jumpBuffer = 0;
    state.lastEvent = "跳跃";
    playTone("jump");
    spawnParticles(player.x + player.w / 2, player.y + player.h, chapter.palette.groundAlt, 10);
  }

  if (input.jumpReleased && player.vy < 0) {
    player.vy *= PLAYER_TUNING.jumpCutMultiplier;
  }

  applyChapterForces(player, chapter, dt);
  updatePickupsAndShortcut(player, chapter);

  if (player.dashTimer > 0) {
    player.dashTimer -= dt;
  } else {
    const accel = player.grounded ? PLAYER_TUNING.groundAccel : PLAYER_TUNING.airAccel;
    const maxSpeed = player.grounded ? PLAYER_TUNING.groundMaxSpeed : PLAYER_TUNING.airMaxSpeed;
    player.vx += moveAxis * accel * dt;
    player.vx = clamp(player.vx, -maxSpeed, maxSpeed);
    if (moveAxis === 0) {
      const friction = player.grounded ? PLAYER_TUNING.groundFriction : PLAYER_TUNING.airFriction;
      player.vx = approach(player.vx, 0, friction * dt);
    }
    player.vy += SETTINGS.gravity * dt;
  }

  movePlayerWithSolids(player, dt);

  if (player.y > SETTINGS.height + 160) {
    hurtPlayer(2);
    player.x = Math.max(90, state.cameraX + 80);
    player.y = 220;
    player.vx = 0;
    player.vy = 0;
  }

  for (const enemy of state.enemies) {
    if (!enemy.dead && intersects(player, enemy)) hurtPlayer(enemy.kind === "charger" ? 2 : 1);
  }
  if (state.boss && !state.boss.dead && intersects(player, state.boss)) hurtPlayer(2);

  state.cameraX = clamp(player.x - SETTINGS.width * 0.43, 0, WORLD_W - SETTINGS.width);
}

function movePlayerWithSolids(player, dt) {
  const solids = getSolids();
  const wasGrounded = player.grounded;
  player.x += player.vx * dt;
  player.x = clamp(player.x, 0, WORLD_W - player.w);
  for (const solid of solids) {
    if (!intersects(player, solid)) continue;
    if (player.vx > 0) player.x = solid.x - player.w;
    if (player.vx < 0) player.x = solid.x + solid.w;
    player.vx = 0;
  }

  player.grounded = false;
  player.y += player.vy * dt;
  for (const solid of solids) {
    if (!intersects(player, solid)) continue;
    if (player.vy > 0) {
      player.y = solid.y - player.h;
      player.vy = 0;
      player.grounded = true;
      player.lastGroundedY = player.y;
      if (!wasGrounded) {
        player.landTimer = 0.14;
        const chapter = CHAPTERS[state.chapterIndex];
        spawnParticles(player.x + player.w / 2, player.y + player.h, chapter.palette.groundAlt, 8);
      }
    } else if (player.vy < 0) {
      player.y = solid.y + solid.h;
      player.vy = 0;
    }
  }
}

function updatePickupsAndShortcut(player, chapter) {
  for (const key of state.keyPickups) {
    if (key.taken) continue;
    const keyRect = { x: key.x, y: key.y, w: 34, h: 34 };
    if (intersects(player, keyRect)) {
      key.taken = true;
      state.keys += 1;
      state.lastEvent = `钟钥 ${state.keys}/${state.keyPickups.length}`;
      playTone("clear");
      spawnParticles(key.x + 17, key.y + 17, chapter.palette.accent, 20);
    }
  }

  const shortcut = chapter.shortcut;
  if (!shortcut || state.shortcutOpen) return;
  const lever = shortcut.lever;
  const leverRect = { x: lever.x - 10, y: lever.y - 8, w: lever.w + 20, h: lever.h + 16 };
  if (state.keys >= shortcut.requiresKeys && intersects(player, leverRect)) {
    state.shortcutOpen = true;
    state.lastEvent = "捷径已打开";
    state.shake = Math.max(state.shake, 5);
    playTone("start");
    spawnParticles(lever.x + lever.w / 2, lever.y + lever.h / 2, chapter.palette.accent, 34);
  }
}

function updateEnemies(dt) {
  const player = state.player;
  const chapter = CHAPTERS[state.chapterIndex];
  for (const enemy of state.enemies) {
    if (enemy.dead) continue;
    enemy.hitFlash = Math.max(0, enemy.hitFlash - dt);
    enemy.alertTimer = Math.max(0, enemy.alertTimer - dt);
    enemy.stunTimer = Math.max(0, enemy.stunTimer - dt);
    if (enemy.stunTimer > 0) continue;
    if (enemy.kind === "crawler") {
      enemy.x += enemy.dir * enemy.speed * dt;
      if (Math.abs(enemy.x - enemy.homeX) > enemy.range) enemy.dir *= -1;
    }
    if (enemy.kind === "flyer") {
      const toPlayer = player.x - enemy.x;
      const desired = Math.abs(toPlayer) < enemy.range + 150 ? Math.sign(toPlayer) : Math.sin(state.time + enemy.phase);
      enemy.x += desired * enemy.speed * dt;
      enemy.y = enemy.baseY + Math.sin(state.time * 2.4 + enemy.phase) * 30;
      enemy.dir = desired >= 0 ? 1 : -1;
    }
    if (enemy.kind === "shooter") {
      enemy.dir = player.x > enemy.x ? 1 : -1;
      enemy.fireTimer -= dt;
      const inRange = Math.abs(player.x - enemy.x) < enemy.range + 160;
      if (enemy.pendingShot && enemy.alertTimer <= 0) {
        enemy.pendingShot = false;
        enemy.fireTimer = 1.45 - Math.min(0.35, state.chapterIndex * 0.04);
        shoot(enemy, player, chapter.palette.danger, 260 + state.chapterIndex * 12, 1);
      } else if (!enemy.pendingShot && enemy.fireTimer <= 0 && inRange) {
        enemy.pendingShot = true;
        enemy.alertTimer = 0.24;
        state.lastEvent = "敌人预警";
      }
    }
    if (enemy.kind === "charger") {
      enemy.chargeCooldown -= dt;
      if (enemy.windupTimer > 0) {
        enemy.windupTimer -= dt;
        enemy.alertTimer = Math.max(enemy.alertTimer, enemy.windupTimer);
        if (enemy.windupTimer <= 0) {
          enemy.chargeTimer = 0.45;
          spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h, chapter.palette.danger, 16);
        }
      } else if (enemy.chargeTimer > 0) {
        enemy.chargeTimer -= dt;
        enemy.x += enemy.dir * (enemy.speed + 260) * dt;
      } else {
        const near = Math.abs(player.x - enemy.x) < 320 && Math.abs(player.y - enemy.y) < 110;
        if (near && enemy.chargeCooldown <= 0) {
          enemy.dir = player.x > enemy.x ? 1 : -1;
          enemy.windupTimer = 0.28;
          enemy.alertTimer = 0.28;
          enemy.chargeCooldown = 1.6;
          state.lastEvent = "冲锋预警";
          spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h, chapter.palette.danger, 12);
        } else {
          enemy.x += enemy.dir * enemy.speed * 0.72 * dt;
          if (Math.abs(enemy.x - enemy.homeX) > enemy.range) enemy.dir *= -1;
        }
      }
    }
    enemy.x = clamp(enemy.x, enemy.homeX - enemy.range - 50, enemy.homeX + enemy.range + 50);
  }
}

function updateBoss(dt) {
  const boss = state.boss;
  if (!boss || boss.dead) return;
  const chapter = CHAPTERS[state.chapterIndex];
  const player = state.player;
  boss.hitFlash = Math.max(0, boss.hitFlash - dt);
  boss.attackAnimTimer = Math.max(0, boss.attackAnimTimer - dt);
  boss.attackVfxTimer = Math.max(0, boss.attackVfxTimer - dt);
  boss.attackTimer -= dt;
  boss.dir = player.x > boss.x ? 1 : -1;

  const floaty = ["wind", "core", "mirror"].includes(boss.pattern);
  if (floaty) {
    boss.y = boss.baseY + Math.sin(state.time * 1.7 + boss.phase) * 36;
    boss.x += Math.sign(player.x - boss.x) * 42 * dt;
  } else {
    boss.x += Math.sign(player.x - boss.x) * 34 * dt;
  }

  boss.x = clamp(boss.x, 2740, 3050);

  if (boss.attackTimer <= 0) {
    const cadence = Math.max(0.78, 1.65 - state.chapterIndex * 0.09);
    boss.attackTimer = cadence;
    bossAttack(boss, player, chapter);
  }
}

function bossAttack(boss, player, chapter) {
  const special = nextBossSpecial(boss);
  const color = special?.color || chapter.palette.danger;
  if (special) {
    boss.specialAttack = special.id;
    boss.specialAttackName = special.name;
    boss.specialAttackColor = special.color;
    boss.attackAnimTotal = 0.5;
    boss.attackAnimTimer = boss.attackAnimTotal;
    boss.attackVfxTimer = 0.42;
    state.lastEvent = special.name;
  }
  playTone("boss");
  if (boss.pattern === "bell") {
    if (special?.id === "boss_01_atk_02") {
      rootSpikeLine(boss, player, color);
    } else if (special?.id === "boss_01_atk_03") {
      chimeRain(boss, player, color);
    } else {
      shoot(boss, player, color, 310, 2);
      radialBurst(boss, color, 5, 180);
    }
  } else if (boss.pattern === "mirror") {
    for (const offset of [-36, 0, 36]) shoot({ ...boss, y: boss.y + offset }, player, color, 330, 1);
  } else if (boss.pattern === "ember") {
    shoot(boss, player, color, 360, 2);
    dropProjectile(boss.x + boss.w / 2 - 90, color);
    dropProjectile(boss.x + boss.w / 2 + 90, color);
  } else if (boss.pattern === "tide") {
    radialBurst(boss, color, 7, 170);
  } else if (boss.pattern === "wind") {
    shoot(boss, player, color, 350, 1);
    boss.x += boss.dir * 90;
  } else {
    radialBurst(boss, color, 9, 210);
    shoot(boss, player, chapter.palette.accent, 410, 2);
  }
  spawnParticles(boss.x + boss.w / 2, boss.y + boss.h / 2, color, 16);
}

function nextBossSpecial(boss) {
  const specials = BOSS_SPECIALS_BY_CHAPTER[state.chapterIndex] || [];
  if (!specials.length) return null;
  const special = specials[boss.specialAttackIndex % specials.length];
  boss.specialAttackIndex = (boss.specialAttackIndex + 1) % specials.length;
  return special;
}

function shoot(source, target, color, speed, damage) {
  const sx = source.x + source.w / 2;
  const sy = source.y + source.h / 2;
  const tx = target.x + target.w / 2;
  const ty = target.y + target.h / 2;
  const angle = Math.atan2(ty - sy, tx - sx);
  state.projectiles.push({
    x: sx,
    y: sy,
    r: 7,
    vx: Math.cos(angle) * speed,
    vy: Math.sin(angle) * speed,
    color,
    damage,
    life: 3.2
  });
}

function radialBurst(source, color, count, speed) {
  for (let i = 0; i < count; i += 1) {
    const angle = (-Math.PI * 0.85) + (Math.PI * 1.7 * i) / Math.max(1, count - 1);
    state.projectiles.push({
      x: source.x + source.w / 2,
      y: source.y + source.h / 2,
      r: 6,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      color,
      damage: 1,
      life: 2.8
    });
  }
}

function dropProjectile(x, color) {
  state.projectiles.push({
    x,
    y: 40,
    r: 9,
    vx: 0,
    vy: 320,
    color,
    damage: 1,
    life: 2.2
  });
}

function rootSpikeLine(source, target, color) {
  const startX = source.x + source.w / 2;
  const endX = target.x + target.w / 2;
  const dir = Math.sign(endX - startX) || source.dir || -1;
  for (let i = 0; i < 4; i += 1) {
    state.projectiles.push({
      x: startX + dir * (62 + i * 74),
      y: FLOOR - 22,
      r: 10,
      vx: dir * 18,
      vy: -70 - i * 8,
      color,
      damage: 1,
      life: 1.25
    });
  }
}

function chimeRain(source, target, color) {
  const center = target.x + target.w / 2;
  for (let i = 0; i < 5; i += 1) {
    state.projectiles.push({
      x: center - 150 + i * 75,
      y: 54 - i * 9,
      r: 8,
      vx: Math.sin(i) * 22,
      vy: 300,
      color,
      damage: 1,
      life: 1.65
    });
  }
}

function updateProjectiles(dt) {
  const player = state.player;
  state.projectiles = state.projectiles.filter((projectile) => {
    projectile.life -= dt;
    projectile.x += projectile.vx * dt;
    projectile.y += projectile.vy * dt;
    if (intersectsCircle(player, projectile)) {
      hurtPlayer(projectile.damage);
      spawnParticles(projectile.x, projectile.y, projectile.color, 12);
      return false;
    }
    return projectile.life > 0 && projectile.x > state.cameraX - 200 && projectile.x < state.cameraX + SETTINGS.width + 260 && projectile.y < SETTINGS.height + 140;
  });
}

function updateAttacks(dt) {
  const chapter = CHAPTERS[state.chapterIndex];
  for (const attack of state.attacks) {
    attack.life -= dt;
    for (const enemy of state.enemies) {
      if (enemy.dead || attack.hit.has(enemy.id) || !intersects(attack, enemy)) continue;
      attack.hit.add(enemy.id);
      damageEnemy(enemy, attack.damage, chapter);
    }
    const boss = state.boss;
    if (boss && !boss.dead && !attack.hit.has(boss.id) && intersects(attack, boss)) {
      attack.hit.add(boss.id);
      damageEnemy(boss, attack.damage, chapter);
    }
  }
  state.attacks = state.attacks.filter((attack) => attack.life > 0);
}

function damageEnemy(enemy, amount, chapter) {
  enemy.hp -= amount;
  enemy.hitFlash = 0.16;
  enemy.stunTimer = enemy.kind === "boss" ? 0 : 0.09;
  state.hitStop = Math.max(state.hitStop, enemy.kind === "boss" ? 0.055 : 0.035);
  state.lastEvent = enemy.kind === "boss" ? "Boss 受击" : "敌人受击";
  if (enemy.kind !== "boss") {
    enemy.x += Math.sign(enemy.x - state.player.x || state.player.face) * 18;
  }
  state.shake = Math.max(state.shake, enemy.kind === "boss" ? 8 : 4);
  spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, chapter.palette.accent, enemy.kind === "boss" ? 24 : 12);
  playTone(enemy.kind === "boss" ? "bossHit" : "hit");
  if (enemy.hp <= 0) {
    enemy.dead = true;
    spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, chapter.palette.danger, enemy.kind === "boss" ? 48 : 20);
    if (enemy.kind === "boss") {
      state.messageTimer = 2.2;
      state.lastEvent = "Boss 已击败";
      state.projectiles = [];
      playTone("clear");
    }
  }
}

function applyChapterForces(player, chapter, dt) {
  for (const hazard of chapter.hazards) {
    const rect = { x: hazard.x, y: hazard.y, w: hazard.w, h: hazard.h };
    if (hazard.type === "wind" && intersects(player, rect)) {
      player.vx += hazard.force * dt;
      player.vy -= 100 * dt;
    } else if (hazard.type === "geyser") {
      const active = Math.sin(state.time * 3.4 + hazard.phase) > 0.12;
      const activeRect = active ? { x: hazard.x, y: hazard.y - 70, w: hazard.w, h: hazard.h + 70 } : rect;
      if (active && intersects(player, activeRect)) hurtPlayer(1);
    } else if (hazard.type === "void") {
      const active = Math.sin(state.time * 4.1 + hazard.phase) > -0.3;
      if (active && intersects(player, rect)) hurtPlayer(1);
    } else if (hazard.type !== "wind" && intersects(player, rect)) {
      hurtPlayer(1);
    }
  }
}

function hurtPlayer(amount) {
  const player = state.player;
  if (!player || player.invuln > 0) return;
  player.health = Math.max(0, player.health - amount);
  player.invuln = 0.95;
  player.vx = -player.face * 230;
  player.vy = -260;
  state.shake = Math.max(state.shake, 10);
  playTone("hurt");
  if (player.health <= 0) {
    state.mode = "menu";
    statusPill.textContent = "倒下";
    menu.classList.remove("is-hidden");
    renderChapterList();
  }
}

function checkExit() {
  const chapter = CHAPTERS[state.chapterIndex];
  const exitRect = { x: chapter.exit.x, y: chapter.exit.y, w: 64, h: 84 };
  if (state.boss.dead && intersects(state.player, exitRect)) finishChapter();
}

function finishChapter() {
  const nextUnlock = Math.min(CHAPTERS.length, state.chapterIndex + 2);
  state.unlocked = Math.max(state.unlocked, nextUnlock);
  saveUnlocks();
  renderChapterList();
  if (state.chapterIndex + 1 >= CHAPTERS.length) {
    state.mode = "menu";
    state.chapterIndex = CHAPTERS.length - 1;
    menu.classList.remove("is-hidden");
    statusPill.textContent = "全章完成";
  } else {
    startChapter(state.chapterIndex + 1, { silent: true });
    playTone("start");
  }
}

function draw() {
  const chapter = CHAPTERS[state.chapterIndex] || CHAPTERS[0];
  ctx.save();
  ctx.clearRect(0, 0, SETTINGS.width, SETTINGS.height);
  if (state.shake > 0) {
    const sx = (Math.random() - 0.5) * state.shake;
    const sy = (Math.random() - 0.5) * state.shake;
    ctx.translate(sx, sy);
  }
  drawBackground(chapter);
  ctx.save();
  ctx.translate(-state.cameraX, 0);
  drawHazards(chapter);
  drawPlatforms(chapter);
  drawExit(chapter);
  drawProps(chapter);
  drawGuideArrow(chapter);
  for (const enemy of state.enemies) drawEnemy(enemy, chapter);
  if (state.boss && !state.boss.dead) drawEnemy(state.boss, chapter);
  for (const projectile of state.projectiles) drawProjectile(projectile);
  for (const attack of state.attacks) drawAttack(attack, chapter);
  if (state.player) drawPlayer(chapter);
  drawParticles();
  ctx.restore();
  drawForeground(chapter);
  ctx.restore();
}

function drawBackground(chapter) {
  const gradient = ctx.createLinearGradient(0, 0, 0, SETTINGS.height);
  gradient.addColorStop(0, chapter.palette.skyTop);
  gradient.addColorStop(1, chapter.palette.skyBottom);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, SETTINGS.width, SETTINGS.height);

  const asset = assets.chapters[state.chapterIndex];
  if (isDrawable(asset.background)) {
    const parallaxX = -((state.cameraX * 0.06) % SETTINGS.width);
    ctx.globalAlpha = 0.82;
    for (let x = parallaxX - SETTINGS.width; x < SETTINGS.width * 2; x += SETTINGS.width) {
      ctx.drawImage(asset.background, x, 0, SETTINGS.width, SETTINGS.height);
    }
    ctx.globalAlpha = 1;
  }
  for (let layer = 0; layer < 3; layer += 1) {
    const parallax = 0.12 + layer * 0.11;
    const spacing = 230 - layer * 25;
    const yBase = 92 + layer * 62;
    for (let i = -1; i < 7; i += 1) {
      const x = i * spacing - ((state.cameraX * parallax) % spacing);
      const y = yBase + Math.sin(i * 1.7 + state.time * 0.35 + layer) * 12;
      ctx.globalAlpha = 0.16 + layer * 0.05;
      drawImageOrFallback(asset.backdrop, x, y, 190, 130);
    }
  }
  ctx.globalAlpha = 1;

  ctx.strokeStyle = "rgba(255,255,255,0.08)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 18; i += 1) {
    const x = (i * 87 - (state.cameraX * 0.22) % 87);
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + 70, SETTINGS.height);
    ctx.stroke();
  }
}

function drawForeground(chapter) {
  const pulse = 0.35 + Math.sin(state.time * 2) * 0.08;
  ctx.fillStyle = chapter.palette.mist;
  ctx.globalAlpha = pulse;
  ctx.fillRect(0, 0, SETTINGS.width, SETTINGS.height);
  ctx.globalAlpha = 1;

  if (state.mode === "playing" && state.boss?.dead && state.messageTimer > 0) {
    state.messageTimer -= 1 / 60;
    ctx.fillStyle = "rgba(0,0,0,0.42)";
    ctx.fillRect(SETTINGS.width / 2 - 178, 82, 356, 52);
    ctx.fillStyle = "#fff6dc";
    ctx.font = "800 22px Microsoft YaHei, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("门已苏醒", SETTINGS.width / 2, 116);
  }
}

function drawHazards(chapter) {
  for (const hazard of chapter.hazards) {
    ctx.save();
    if (hazard.type === "lava") {
      ctx.fillStyle = chapter.palette.danger;
      ctx.globalAlpha = 0.8;
      waveRect(hazard.x, hazard.y, hazard.w, hazard.h, 8);
    } else if (hazard.type === "shards") {
      ctx.fillStyle = chapter.palette.danger;
      for (let x = hazard.x; x < hazard.x + hazard.w; x += 22) {
        ctx.beginPath();
        ctx.moveTo(x, hazard.y + hazard.h);
        ctx.lineTo(x + 11, hazard.y);
        ctx.lineTo(x + 22, hazard.y + hazard.h);
        ctx.closePath();
        ctx.fill();
      }
    } else if (hazard.type === "mist") {
      ctx.fillStyle = chapter.palette.mist;
      ctx.globalAlpha = 0.75;
      ctx.fillRect(hazard.x, hazard.y, hazard.w, hazard.h);
    } else if (hazard.type === "geyser") {
      const active = Math.sin(state.time * 3.4 + hazard.phase) > 0.12;
      ctx.fillStyle = chapter.palette.danger;
      ctx.globalAlpha = active ? 0.72 : 0.22;
      waveRect(hazard.x, active ? hazard.y - 70 : hazard.y, hazard.w, active ? hazard.h + 70 : hazard.h, 6);
    } else if (hazard.type === "wind") {
      ctx.strokeStyle = chapter.palette.accent;
      ctx.globalAlpha = 0.42;
      for (let i = 0; i < 6; i += 1) {
        ctx.beginPath();
        const y = hazard.y + 22 + i * 34 + Math.sin(state.time * 3 + i) * 8;
        ctx.moveTo(hazard.x + 10, y);
        ctx.bezierCurveTo(hazard.x + 42, y - 18, hazard.x + 76, y + 18, hazard.x + hazard.w - 8, y);
        ctx.stroke();
      }
    } else if (hazard.type === "void") {
      const active = Math.sin(state.time * 4.1 + hazard.phase) > -0.3;
      ctx.fillStyle = active ? chapter.palette.danger : chapter.palette.accent;
      ctx.globalAlpha = active ? 0.64 : 0.2;
      ctx.beginPath();
      ctx.ellipse(hazard.x + hazard.w / 2, hazard.y + hazard.h / 2, hazard.w / 2, hazard.h / 2, 0, 0, TAU);
      ctx.fill();
    }
    ctx.restore();
  }
}

function drawPlatforms(chapter) {
  const asset = assets.chapters[state.chapterIndex];
  for (const platform of [[0, FLOOR, WORLD_W, 120], ...chapter.platforms, ...getShortcutPlatforms(chapter).map(({ x, y, w, h }) => [x, y, w, h])]) {
    const [x, y, w, h] = platform;
    const tile = h >= 90 ? asset.tile : asset.bridge;
    const pattern = isDrawable(tile) ? ctx.createPattern(tile, "repeat") : null;
    ctx.fillStyle = pattern || chapter.palette.ground;
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = chapter.palette.groundAlt;
    ctx.globalAlpha = 0.48;
    ctx.fillRect(x, y, w, 4);
    ctx.globalAlpha = 1;
  }
}

function drawExit(chapter) {
  const active = state.boss?.dead;
  const x = chapter.exit.x;
  const y = chapter.exit.y;
  ctx.save();
  ctx.globalAlpha = active ? 1 : 0.34;
  ctx.strokeStyle = active ? chapter.palette.accent : "rgba(255,255,255,0.35)";
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.ellipse(x + 32, y + 42, 28, 42, 0, 0, TAU);
  ctx.stroke();
  ctx.fillStyle = active ? chapter.palette.mist : "rgba(0,0,0,0.25)";
  ctx.beginPath();
  ctx.ellipse(x + 32, y + 42, 20 + Math.sin(state.time * 5) * 3, 32, 0, 0, TAU);
  ctx.fill();
  ctx.restore();
}

function drawProps(chapter) {
  const asset = assets.chapters[state.chapterIndex];
  for (const key of state.keyPickups) {
    if (key.taken) continue;
    drawSprite(asset.key, key.x, key.y + Math.sin(state.time * 4 + key.x) * 4, 34, 34);
  }
  const lever = chapter.shortcut?.lever || { x: 2390, y: 366 };
  ctx.save();
  ctx.globalAlpha = state.keys >= (chapter.shortcut?.requiresKeys || 3) || state.shortcutOpen ? 1 : 0.46;
  drawSprite(asset.lever, lever.x, lever.y, 48, 62);
  ctx.restore();
  drawSprite(asset.bossGate, chapter.exit.x - 18, chapter.exit.y - 18, 92, 118);
}

function drawGuideArrow(chapter) {
  if (!state.player) return;
  const target = state.boss?.dead ? chapter.exit : (state.boss || chapter.exit);
  const direction = Math.sign((target.x + (target.w || 64) / 2) - (state.player.x + state.player.w / 2)) || 1;
  const x = clamp(state.player.x + direction * 120, state.cameraX + 42, state.cameraX + SETTINGS.width - 42);
  const y = Math.max(72, state.player.y - 56);
  ctx.save();
  ctx.globalAlpha = 0.74 + Math.sin(state.time * 5) * 0.16;
  ctx.fillStyle = state.boss?.dead ? chapter.palette.accent : chapter.palette.danger;
  ctx.strokeStyle = "rgba(0,0,0,0.55)";
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(x + direction * 24, y);
  ctx.lineTo(x - direction * 10, y - 14);
  ctx.lineTo(x - direction * 4, y);
  ctx.lineTo(x - direction * 10, y + 14);
  ctx.closePath();
  ctx.stroke();
  ctx.fill();
  ctx.restore();
}

function drawEnemy(enemy, chapter) {
  if (enemy.dead) return;
  const asset = enemy.kind === "boss"
    ? selectBossSprite(enemy)
    : assets.chapters[state.chapterIndex].enemies[enemy.kind];
  const rect = visualRect(enemy, enemy.kind === "boss" ? "boss" : "enemy");
  ctx.save();
  if (enemy.hitFlash > 0) {
    ctx.shadowColor = "#ffffff";
    ctx.shadowBlur = 22;
  }
  if (enemy.alertTimer > 0) {
    drawEnemyTelegraph(enemy, rect, chapter);
  }
  if (enemy.kind === "boss") {
    drawBossSpecialVfx(enemy, rect, chapter);
  }
  drawSprite(asset, rect.x, rect.y, rect.w, rect.h, enemy.dir < 0);
  if (enemy.kind === "boss") {
    ctx.fillStyle = "rgba(0,0,0,0.45)";
    ctx.fillRect(rect.x - 10, rect.y - 20, rect.w + 20, 6);
    ctx.fillStyle = chapter.palette.danger;
    ctx.fillRect(rect.x - 10, rect.y - 20, (rect.w + 20) * Math.max(0, enemy.hp / enemy.maxHp), 6);
  }
  ctx.restore();
}

function selectBossSprite(boss) {
  const specials = assets.chapters[state.chapterIndex]?.bossSpecials || {};
  const frames = specials[boss.specialAttack] || null;
  if (frames && boss.attackAnimTimer > 0 && boss.attackAnimTotal > 0) {
    const progress = 1 - clamp(boss.attackAnimTimer / boss.attackAnimTotal, 0, 1);
    const frameIndex = clamp(Math.floor(progress * frames.length), 0, frames.length - 1);
    return frames[frameIndex];
  }
  const idleFrames = specials.boss_01_atk_01;
  if (state.chapterIndex === 0 && idleFrames?.length) {
    return idleFrames[Math.floor(state.time * 6) % Math.min(2, idleFrames.length)];
  }
  return assets.chapters[state.chapterIndex].boss;
}

function drawBossSpecialVfx(boss, rect, chapter) {
  if (boss.attackVfxTimer <= 0) return;
  const progress = 1 - clamp(boss.attackVfxTimer / 0.42, 0, 1);
  const color = boss.specialAttackColor || chapter.palette.danger;
  ctx.save();
  ctx.globalAlpha = 0.58 * (1 - progress);
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.shadowColor = color;
  ctx.shadowBlur = 18;
  ctx.lineWidth = 4;
  const cx = rect.x + rect.w / 2;
  const cy = rect.y + rect.h * 0.58;
  if (boss.specialAttack === "boss_01_atk_02") {
    for (let i = 0; i < 4; i += 1) {
      const x = boss.dir > 0 ? rect.x + rect.w + i * 34 : rect.x - i * 34;
      ctx.beginPath();
      ctx.moveTo(x, FLOOR - 6);
      ctx.lineTo(x + boss.dir * 16, FLOOR - 58 - progress * 28);
      ctx.lineTo(x + boss.dir * 34, FLOOR - 6);
      ctx.stroke();
      ctx.fill();
    }
  } else if (boss.specialAttack === "boss_01_atk_03") {
    for (let i = 0; i < 5; i += 1) {
      ctx.beginPath();
      ctx.arc(cx - 92 + i * 46, cy - 80 + Math.sin(state.time * 8 + i) * 8, 9 + progress * 8, 0, TAU);
      ctx.stroke();
    }
  } else {
    ctx.beginPath();
    ctx.arc(cx, cy, 42 + progress * 92, 0, TAU);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx, cy, 74 + progress * 126, 0, TAU);
    ctx.stroke();
  }
  ctx.restore();
}

function drawEnemyTelegraph(enemy, rect, chapter) {
  ctx.save();
  ctx.globalAlpha = clamp(enemy.alertTimer * 4, 0.24, 0.82);
  ctx.strokeStyle = chapter.palette.danger;
  ctx.fillStyle = chapter.palette.danger;
  ctx.lineWidth = 3;
  if (enemy.kind === "shooter") {
    const y = enemy.y + enemy.h * 0.42;
    ctx.beginPath();
    ctx.moveTo(enemy.x + enemy.w / 2, y);
    ctx.lineTo(enemy.x + enemy.dir * 180, y);
    ctx.stroke();
  } else {
    ctx.beginPath();
    ctx.ellipse(rect.x + rect.w / 2, rect.y + rect.h - 18, rect.w * 0.38, 8, 0, 0, TAU);
    ctx.fill();
  }
  ctx.restore();
}

function drawPlayer(chapter) {
  const player = state.player;
  const rect = visualRect(player, "player");
  const sprite = selectPlayerSprite(player);
  ctx.save();
  ctx.globalAlpha = player.invuln > 0 && Math.sin(state.time * 38) > 0 ? 0.52 : 1;
  if (player.dashTimer > 0) {
    ctx.globalAlpha = 0.35;
    drawSprite(sprite, rect.x - player.face * 40, rect.y + 3, rect.w, rect.h, player.face < 0);
    ctx.globalAlpha = 1;
  }
  drawSprite(sprite, rect.x, rect.y, rect.w, rect.h, player.face < 0);
  ctx.strokeStyle = chapter.palette.accent;
  ctx.globalAlpha = 0.5;
  ctx.beginPath();
  ctx.moveTo(player.x + player.w / 2, player.y + 24);
  ctx.quadraticCurveTo(player.x - player.face * 28, player.y + 46, player.x - player.face * 52, player.y + 22);
  ctx.stroke();
  ctx.restore();
}

function visualRect(entity, type) {
  const bounds = VISUAL_BOUNDS[type];
  return {
    x: Math.round(entity.x + entity.w / 2 - bounds.w / 2),
    y: Math.round(entity.y + entity.h - bounds.h + bounds.yOffset),
    w: bounds.w,
    h: bounds.h
  };
}

function selectPlayerSprite(player) {
  if (player.attackCooldown > 0) {
    const frameIndex = clamp(Math.floor((0.24 - player.attackCooldown) / 0.06), 0, PLAYER_ANIMS.attack.length - 1);
    return getPlayerFrame(PLAYER_ANIMS.attack[frameIndex]);
  }
  if (player.dashTimer > 0) return getPlayerFrame("dash_00");
  if (!player.grounded) return getPlayerFrame(player.vy < -40 ? "jump_00" : "fall_00");
  if (Math.abs(player.vx) > 34) {
    return getPlayerFrame(PLAYER_ANIMS.run[Math.floor(state.time * 12) % PLAYER_ANIMS.run.length]);
  }
  return getPlayerFrame(PLAYER_ANIMS.idle[Math.floor(state.time * 4) % PLAYER_ANIMS.idle.length]);
}

function getPlayerFrame(name) {
  return assets.playerFrames?.[name] || assets.playerFrames?.idle_00 || assets.player;
}

function drawAttack(attack, chapter) {
  ctx.save();
  const progress = 1 - clamp(attack.life / attack.maxLife, 0, 1);
  ctx.globalAlpha = Math.max(0, attack.life / attack.maxLife);
  ctx.strokeStyle = chapter.palette.accent;
  ctx.lineWidth = 7;
  ctx.shadowColor = chapter.palette.accent;
  ctx.shadowBlur = 16;
  ctx.beginPath();
  const cx = attack.face > 0 ? attack.x + 16 : attack.x + attack.w - 16;
  const spread = 0.48 + progress * 0.62;
  const start = attack.face > 0 ? -spread : Math.PI - spread;
  const end = attack.face > 0 ? spread : Math.PI + spread;
  ctx.arc(cx, attack.y + 18, 42 + progress * 12, start, end);
  ctx.stroke();
  ctx.fillStyle = chapter.palette.mist;
  ctx.globalAlpha *= 0.32;
  ctx.fillRect(attack.x, attack.y, attack.w, attack.h);
  ctx.restore();
}

function drawProjectile(projectile) {
  ctx.save();
  ctx.fillStyle = projectile.color;
  ctx.shadowColor = projectile.color;
  ctx.shadowBlur = 12;
  ctx.beginPath();
  ctx.arc(projectile.x, projectile.y, projectile.r, 0, TAU);
  ctx.fill();
  ctx.restore();
}

function drawParticles() {
  for (const particle of state.particles) {
    ctx.save();
    ctx.globalAlpha = clamp(particle.life / particle.maxLife, 0, 1);
    ctx.fillStyle = particle.color;
    ctx.fillRect(particle.x, particle.y, particle.size, particle.size);
    ctx.restore();
  }
}

function drawSprite(sprite, x, y, w, h, flip = false) {
  ctx.save();
  if (flip) {
    ctx.translate(x + w, y);
    ctx.scale(-1, 1);
    drawImageOrFallback(sprite, 0, 0, w, h);
  } else {
    drawImageOrFallback(sprite, x, y, w, h);
  }
  ctx.restore();
}

function buildAssets() {
  const fallbackPlayer = makePlayerSprite();
  const playerFrames = Object.fromEntries(
    Object.entries(ASSET_PATHS.playerFrames).map(([name, path]) => [name, loadImage(path, fallbackPlayer)])
  );
  return {
    player: playerFrames.idle_00,
    playerFrames,
    chapters: CHAPTERS.map((chapter, index) => ({
      background: loadImage(ASSET_PATHS.background, makeBackdrop(chapter, index)),
      tile: loadImage(ASSET_PATHS.tile, makeTile(chapter, index)),
      bridge: loadImage(index === CHAPTERS.length - 1 ? ASSET_PATHS.bossTile : ASSET_PATHS.bridge, makeTile(chapter, index)),
      backdrop: loadImage(ASSET_PATHS.backdrop, makeBackdrop(chapter, index)),
      key: loadImage(ASSET_PATHS.key, makeEnemySprite(chapter, index, "crawler")),
      lever: loadImage(ASSET_PATHS.lever, makeEnemySprite(chapter, index, "charger")),
      bossGate: loadImage(ASSET_PATHS.bossGate, makeEnemySprite(chapter, index, "boss")),
      boss: loadImage(ASSET_PATHS.boss, makeEnemySprite(chapter, index, "boss")),
      bossSpecials: buildBossSpecialFrames(index, makeEnemySprite(chapter, index, "boss")),
      enemies: {
        crawler: loadImage(ASSET_PATHS.enemies.crawler, makeEnemySprite(chapter, index, "crawler")),
        flyer: loadImage(ASSET_PATHS.enemies.flyer, makeEnemySprite(chapter, index, "flyer")),
        shooter: loadImage(ASSET_PATHS.enemies.shooter, makeEnemySprite(chapter, index, "shooter")),
        charger: loadImage(ASSET_PATHS.enemies.charger, makeEnemySprite(chapter, index, "charger"))
      }
    }))
  };
}

function makeBossSpecialFramePaths(slug, attackId) {
  return Array.from(
    { length: 6 },
    (_, index) => `godot/assets/sprites/bosses/${slug}/frames/${attackId}/attack_${String(index).padStart(2, "0")}.png`
  );
}

function buildBossSpecialFrames(chapterIndex, fallback) {
  const specials = BOSS_SPECIALS_BY_CHAPTER[chapterIndex] || [];
  return Object.fromEntries(
    specials.map((special) => [special.id, special.frames.map((path) => loadImage(path, fallback))])
  );
}

function loadImage(src, fallback) {
  const image = new Image();
  image.src = src;
  image.fallback = fallback;
  image.assetPath = src;
  return image;
}

function isDrawable(image) {
  if (!image) return false;
  if (image.tagName === "CANVAS") return true;
  return image.complete && image.naturalWidth > 0;
}

function drawImageOrFallback(image, x, y, w, h) {
  if (isDrawable(image)) {
    ctx.drawImage(image, x, y, w, h);
  } else if (image?.fallback && isDrawable(image.fallback)) {
    ctx.drawImage(image.fallback, x, y, w, h);
  }
}

function makeCanvas(width, height, draw) {
  const item = document.createElement("canvas");
  item.width = width;
  item.height = height;
  const itemCtx = item.getContext("2d");
  draw(itemCtx, width, height);
  return item;
}

function makePlayerSprite() {
  return makeCanvas(72, 96, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    g.fillStyle = "#f6f0df";
    g.beginPath();
    g.ellipse(36, 24, 14, 17, 0, 0, TAU);
    g.fill();
    g.fillStyle = "#171821";
    g.beginPath();
    g.ellipse(31, 23, 3, 5, 0, 0, TAU);
    g.ellipse(41, 23, 3, 5, 0, 0, TAU);
    g.fill();
    g.strokeStyle = "#f6f0df";
    g.lineWidth = 5;
    g.beginPath();
    g.moveTo(24, 14);
    g.quadraticCurveTo(18, 2, 10, 6);
    g.moveTo(48, 14);
    g.quadraticCurveTo(54, 2, 62, 6);
    g.stroke();
    g.fillStyle = "#c12f55";
    g.beginPath();
    g.moveTo(26, 40);
    g.quadraticCurveTo(12, 62, 24, 90);
    g.lineTo(48, 90);
    g.quadraticCurveTo(60, 62, 46, 40);
    g.closePath();
    g.fill();
    g.fillStyle = "#742036";
    g.fillRect(24, 54, 24, 9);
    g.strokeStyle = "#ffe6a7";
    g.lineWidth = 4;
    g.beginPath();
    g.moveTo(48, 50);
    g.lineTo(66, 36);
    g.stroke();
  });
}

function makeTile(chapter, index) {
  const rng = seededRandom(chapter.id);
  return makeCanvas(72, 72, (g, w, h) => {
    g.fillStyle = chapter.palette.ground;
    g.fillRect(0, 0, w, h);
    for (let i = 0; i < 34; i += 1) {
      g.fillStyle = i % 3 === 0 ? chapter.palette.groundAlt : chapter.palette.accent;
      g.globalAlpha = 0.16 + rng() * 0.18;
      const size = 2 + rng() * 8;
      g.fillRect(rng() * w, rng() * h, size, size);
    }
    g.globalAlpha = 1;
    g.strokeStyle = `rgba(255,255,255,${0.08 + index * 0.01})`;
    g.strokeRect(0.5, 0.5, w - 1, h - 1);
  });
}

function makeBackdrop(chapter, index) {
  return makeCanvas(160, 120, (g, w, h) => {
    g.fillStyle = "rgba(0,0,0,0)";
    g.clearRect(0, 0, w, h);
    g.fillStyle = chapter.palette.ground;
    g.globalAlpha = 0.72;
    if (index === 0) {
      for (let i = 0; i < 4; i += 1) {
        g.beginPath();
        g.arc(25 + i * 38, 68 - i * 6, 24, 0, TAU);
        g.fill();
      }
      g.strokeStyle = chapter.palette.accent;
      g.lineWidth = 5;
      g.beginPath();
      g.arc(88, 52, 22, 0, TAU);
      g.stroke();
    } else if (index === 1) {
      g.fillStyle = chapter.palette.accent;
      for (let i = 0; i < 5; i += 1) {
        g.beginPath();
        g.moveTo(20 + i * 28, 96);
        g.lineTo(35 + i * 26, 20 + i * 6);
        g.lineTo(54 + i * 20, 96);
        g.closePath();
        g.fill();
      }
    } else if (index === 2) {
      g.fillStyle = chapter.palette.ground;
      g.fillRect(20, 32, 28, 74);
      g.fillRect(64, 16, 36, 90);
      g.fillRect(116, 40, 24, 66);
      g.fillStyle = chapter.palette.danger;
      g.fillRect(24, 38, 20, 9);
      g.fillRect(70, 26, 22, 10);
    } else if (index === 3) {
      g.strokeStyle = chapter.palette.accent;
      g.lineWidth = 8;
      for (let i = 0; i < 4; i += 1) {
        g.beginPath();
        g.arc(32 + i * 36, 82, 30, Math.PI, TAU);
        g.stroke();
      }
    } else if (index === 4) {
      g.strokeStyle = chapter.palette.groundAlt;
      g.lineWidth = 7;
      for (let i = 0; i < 5; i += 1) {
        g.beginPath();
        g.moveTo(20 + i * 28, 108);
        g.lineTo(34 + i * 26, 42);
        g.lineTo(48 + i * 24, 68);
        g.moveTo(34 + i * 26, 42);
        g.lineTo(20 + i * 22, 62);
        g.stroke();
      }
    } else {
      g.strokeStyle = chapter.palette.accent;
      g.lineWidth = 4;
      for (let i = 0; i < 7; i += 1) {
        g.beginPath();
        g.arc(80, 60, 12 + i * 9, 0.2 + i * 0.4, 2.6 + i * 0.3);
        g.stroke();
      }
    }
    g.globalAlpha = 1;
  });
}

function makeEnemySprite(chapter, index, kind) {
  const boss = kind === "boss";
  const size = boss ? 128 : 76;
  return makeCanvas(size, size, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    g.translate(w / 2, h / 2);
    g.fillStyle = boss ? chapter.palette.danger : chapter.palette.groundAlt;
    g.strokeStyle = chapter.palette.accent;
    g.lineWidth = boss ? 7 : 4;
    const scale = boss ? 1.28 : 1;
    g.scale(scale, scale);

    if (index === 0) drawMossEnemy(g, kind);
    if (index === 1) drawGlassEnemy(g, kind);
    if (index === 2) drawEmberEnemy(g, kind);
    if (index === 3) drawTideEnemy(g, kind);
    if (index === 4) drawBoneEnemy(g, kind);
    if (index === 5) drawCoreEnemy(g, kind);

    if (boss) {
      g.strokeStyle = "rgba(255,255,255,0.82)";
      g.beginPath();
      g.arc(0, -3, 33, 0, TAU);
      g.stroke();
    }
  });
}

function drawMossEnemy(g, kind) {
  gear(g, 0, 0, kind === "boss" ? 34 : 24, 10);
  g.fill();
  g.stroke();
  g.fillStyle = "#1b301e";
  g.beginPath();
  g.arc(0, -10, kind === "flyer" ? 20 : 16, Math.PI, TAU);
  g.fill();
  eyePair(g);
}

function drawGlassEnemy(g, kind) {
  polygon(g, 6, kind === "boss" ? 36 : 25, -Math.PI / 2);
  g.fill();
  g.stroke();
  if (kind === "flyer") {
    g.globalAlpha = 0.45;
    polygon(g, 3, 30, 0);
    g.fill();
    g.globalAlpha = 1;
  }
  eyePair(g);
}

function drawEmberEnemy(g, kind) {
  g.beginPath();
  g.moveTo(0, -30);
  g.lineTo(28, 8);
  g.lineTo(13, 30);
  g.lineTo(-18, 28);
  g.lineTo(-30, 4);
  g.closePath();
  g.fill();
  g.stroke();
  g.fillStyle = "#331311";
  g.fillRect(-18, -5, 36, 10);
  eyePair(g);
  if (kind === "charger") {
    g.strokeStyle = "#ffd39c";
    g.beginPath();
    g.moveTo(24, -8);
    g.lineTo(42, -18);
    g.moveTo(24, 8);
    g.lineTo(42, 18);
    g.stroke();
  }
}

function drawTideEnemy(g, kind) {
  g.beginPath();
  g.ellipse(0, 0, 30, 22, 0, 0, TAU);
  g.fill();
  g.stroke();
  g.strokeStyle = "#f6f2cf";
  for (let i = -1; i <= 1; i += 1) {
    g.beginPath();
    g.arc(i * 14, 16, 12, 0, Math.PI);
    g.stroke();
  }
  if (kind === "shooter") {
    g.beginPath();
    g.moveTo(0, -28);
    g.lineTo(10, -6);
    g.lineTo(-10, -6);
    g.closePath();
    g.fill();
  }
  eyePair(g);
}

function drawBoneEnemy(g, kind) {
  g.strokeStyle = "#e7e1c8";
  g.lineWidth = 7;
  g.beginPath();
  g.moveTo(-24, 22);
  g.lineTo(0, -28);
  g.lineTo(24, 22);
  g.moveTo(0, -10);
  g.lineTo(-30, -24);
  g.moveTo(0, -10);
  g.lineTo(30, -24);
  g.stroke();
  g.fillStyle = "#65e0bd";
  g.beginPath();
  g.ellipse(0, 8, 18, 23, 0, 0, TAU);
  g.fill();
  eyePair(g);
}

function drawCoreEnemy(g, kind) {
  g.fillStyle = "#151221";
  g.beginPath();
  g.arc(0, 0, kind === "boss" ? 32 : 25, 0, TAU);
  g.fill();
  g.stroke();
  g.strokeStyle = "#ff5dc8";
  for (let i = 0; i < 3; i += 1) {
    g.rotate(Math.PI / 3);
    g.beginPath();
    g.ellipse(0, 0, 34, 10, 0, 0, TAU);
    g.stroke();
  }
  g.fillStyle = "#7efcff";
  g.beginPath();
  g.arc(0, 0, 6, 0, TAU);
  g.fill();
}

function eyePair(g) {
  g.fillStyle = "#11131b";
  g.beginPath();
  g.arc(-8, -2, 3, 0, TAU);
  g.arc(8, -2, 3, 0, TAU);
  g.fill();
}

function gear(g, x, y, radius, teeth) {
  g.beginPath();
  for (let i = 0; i < teeth * 2; i += 1) {
    const r = i % 2 === 0 ? radius : radius * 0.78;
    const angle = (i / (teeth * 2)) * TAU;
    const px = x + Math.cos(angle) * r;
    const py = y + Math.sin(angle) * r;
    if (i === 0) g.moveTo(px, py);
    else g.lineTo(px, py);
  }
  g.closePath();
}

function polygon(g, sides, radius, rotation) {
  g.beginPath();
  for (let i = 0; i < sides; i += 1) {
    const angle = rotation + (i / sides) * TAU;
    const x = Math.cos(angle) * radius;
    const y = Math.sin(angle) * radius;
    if (i === 0) g.moveTo(x, y);
    else g.lineTo(x, y);
  }
  g.closePath();
}

function waveRect(x, y, w, h, amp) {
  ctx.beginPath();
  ctx.moveTo(x, y + h);
  for (let i = 0; i <= w; i += 16) {
    ctx.lineTo(x + i, y + Math.sin(state.time * 5 + i * 0.12) * amp);
  }
  ctx.lineTo(x + w, y + h);
  ctx.closePath();
  ctx.fill();
}

function spawnParticles(x, y, color, amount) {
  for (let i = 0; i < amount; i += 1) {
    const angle = Math.random() * TAU;
    const speed = 70 + Math.random() * 260;
    const life = 0.35 + Math.random() * 0.45;
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - 80,
      size: 2 + Math.random() * 4,
      color,
      life,
      maxLife: life
    });
  }
}

function getSolids() {
  const chapter = CHAPTERS[state.chapterIndex];
  return [
    { x: 0, y: FLOOR, w: WORLD_W, h: 120 },
    ...chapter.platforms.map(([x, y, w, h]) => ({ x, y, w, h })),
    ...getShortcutPlatforms(chapter)
  ];
}

function getShortcutPlatforms(chapter) {
  if (!state.shortcutOpen || !chapter.shortcut?.bridge) return [];
  const { x, y, w, h } = chapter.shortcut.bridge;
  return [{ x, y, w, h, shortcut: true }];
}

function intersects(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function intersectsCircle(rect, circle) {
  const nearestX = clamp(circle.x, rect.x, rect.x + rect.w);
  const nearestY = clamp(circle.y, rect.y, rect.y + rect.h);
  const dx = circle.x - nearestX;
  const dy = circle.y - nearestY;
  return dx * dx + dy * dy < circle.r * circle.r;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function approach(value, target, step) {
  if (value < target) return Math.min(value + step, target);
  if (value > target) return Math.max(value - step, target);
  return target;
}

function seededRandom(seedText) {
  let seed = 2166136261;
  for (let i = 0; i < seedText.length; i += 1) {
    seed ^= seedText.charCodeAt(i);
    seed = Math.imul(seed, 16777619);
  }
  return () => {
    seed += 0x6d2b79f5;
    let t = seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function renderChapterList() {
  chapterList.innerHTML = "";
  CHAPTERS.forEach((chapter, index) => {
    const button = document.createElement("button");
    button.className = "chapter-button";
    button.disabled = index >= state.unlocked;
    button.innerHTML = `<strong>${chapter.roman} · ${chapter.name}</strong><span>${chapter.motif}</span>`;
    button.addEventListener("click", () => startChapter(index));
    chapterList.appendChild(button);
  });
}

function updateHud() {
  const chapter = CHAPTERS[state.chapterIndex] || CHAPTERS[0];
  chapterMark.textContent = chapter.roman;
  chapterName.textContent = chapter.name;
  const totalKeys = state.keyPickups.length || chapter.keys?.length || 0;
  const keyText = totalKeys ? `钟钥 ${state.keys}/${totalKeys}` : "钟钥 0/0";
  const shortcutText = state.shortcutOpen ? "捷径已开" : "捷径未开";
  const bossText = state.boss?.dead ? "前往出口" : "击败守卫";
  chapterObjective.textContent = state.mode === "playing"
    ? `${keyText} · ${shortcutText} · ${bossText}`
    : chapter.objective;
  const hpRatio = state.player ? state.player.health / state.player.maxHealth : 1;
  hpFill.style.transform = `scaleX(${clamp(hpRatio, 0, 1)})`;
  const bossRatio = state.boss ? state.boss.hp / state.boss.maxHp : 1;
  bossFill.style.transform = `scaleX(${clamp(bossRatio, 0, 1)})`;
  statusPill.textContent = state.mode === "playing"
    ? state.lastEvent
    : state.unlocked >= CHAPTERS.length ? "可终章" : "待启程";
}

function loadUnlocks() {
  try {
    return clamp(Number(localStorage.getItem("crimson-thread-unlocked") || 1), 1, CHAPTERS.length);
  } catch {
    return 1;
  }
}

function saveUnlocks() {
  try {
    localStorage.setItem("crimson-thread-unlocked", String(state.unlocked));
  } catch {
    // Local storage is optional for browser privacy modes.
  }
}

function ensureAudio() {
  if (!audio.ctx) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    audio.ctx = new AudioContext();
  }
  if (audio.ctx.state === "suspended") audio.ctx.resume();
}

function playTone(type) {
  const clip = audio.clips[type];
  if (clip) {
    const instance = clip.cloneNode();
    instance.volume = type === "boss" || type === "bossHit" ? 0.55 : 0.42;
    instance.play().catch(() => playGeneratedTone(type));
    return;
  }
  playGeneratedTone(type);
}

function buildAudioClips() {
  return Object.fromEntries(Object.entries(AUDIO_PATHS).map(([key, src]) => {
    const clip = new Audio(src);
    clip.preload = "auto";
    return [key, clip];
  }));
}

function playGeneratedTone(type) {
  if (!audio.ctx) return;
  const table = {
    start: [220, 0.12, "sine", 0.06],
    jump: [440, 0.08, "triangle", 0.045],
    dash: [160, 0.11, "sawtooth", 0.035],
    attack: [690, 0.06, "square", 0.03],
    hit: [260, 0.05, "triangle", 0.04],
    bossHit: [110, 0.09, "sawtooth", 0.045],
    boss: [92, 0.16, "sine", 0.04],
    hurt: [80, 0.12, "square", 0.04],
    clear: [523, 0.24, "triangle", 0.06]
  };
  const [freq, duration, wave, gainValue] = table[type] || table.hit;
  const oscillator = audio.ctx.createOscillator();
  const gain = audio.ctx.createGain();
  oscillator.type = wave;
  oscillator.frequency.setValueAtTime(freq, audio.ctx.currentTime);
  oscillator.frequency.exponentialRampToValueAtTime(Math.max(30, freq * 1.8), audio.ctx.currentTime + duration);
  gain.gain.setValueAtTime(gainValue, audio.ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.0001, audio.ctx.currentTime + duration);
  oscillator.connect(gain);
  gain.connect(audio.ctx.destination);
  oscillator.start();
  oscillator.stop(audio.ctx.currentTime + duration);
}

function snapshot() {
  return {
    mode: state.mode,
    chapterIndex: state.chapterIndex,
    chapterName: CHAPTERS[state.chapterIndex]?.name,
    unlocked: state.unlocked,
    enemyCount: state.enemies.filter((enemy) => !enemy.dead).length,
    bossHp: state.boss?.hp ?? 0,
    playerHealth: state.player?.health ?? 0,
    playerX: state.player?.x ?? 0,
    cameraX: state.cameraX,
    keys: state.keys,
    totalKeys: state.keyPickups.length,
    shortcutOpen: state.shortcutOpen,
    hitStop: state.hitStop,
    lastEvent: state.lastEvent,
    bossSpecialAttack: state.boss?.specialAttack || "",
    bossSpecialAttackName: state.boss?.specialAttackName || ""
  };
}

function visualMetrics() {
  const player = state.player;
  const heroIdle = assets.playerFrames?.idle_00;
  const bossSpecials = assets.chapters[state.chapterIndex]?.bossSpecials || {};
  const bossSpecialFrames = Object.values(bossSpecials).flat();
  return {
    heroIdlePath: ASSET_PATHS.player,
    heroFrameSize: imageSize(heroIdle),
    loadedHeroFrames: Object.values(assets.playerFrames || {}).filter(isDrawable).length,
    totalHeroFrames: HERO_FRAME_NAMES.length,
    playerVisual: { ...VISUAL_BOUNDS.player },
    enemyVisual: { ...VISUAL_BOUNDS.enemy },
    bossVisual: { ...VISUAL_BOUNDS.boss },
    playerCollision: player ? { w: player.w, h: player.h } : null,
    playerRect: player ? visualRect(player, "player") : null,
    bossSpecialAttackCount: Object.keys(bossSpecials).length,
    loadedBossSpecialFrames: bossSpecialFrames.filter(isDrawable).length,
    totalBossSpecialFrames: bossSpecialFrames.length,
    bossSpecialFrameSize: imageSize(bossSpecialFrames[0]),
    tuning: { ...PLAYER_TUNING },
    shortcutPlatforms: getShortcutPlatforms(CHAPTERS[state.chapterIndex] || CHAPTERS[0]).length
  };
}

function imageSize(image) {
  if (!image) return { width: 0, height: 0 };
  return {
    width: image.naturalWidth || image.width || 0,
    height: image.naturalHeight || image.height || 0
  };
}
