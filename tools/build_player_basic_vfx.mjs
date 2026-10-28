// Authoring helper: use the separately downloaded Scenario renderer, keeping
// its source outside this repository. Generated PNG pixels are unmodified.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const renderer = process.argv[2] && path.resolve(process.argv[2]);
if (!renderer || !fs.existsSync(renderer)) {
  console.error('Usage: node tools/build_player_basic_vfx.mjs /path/to/scenario-pixel-vfx/scripts/render.mjs');
  process.exit(2);
}
const { decodePNG } = await import(pathToFileURL(path.join(path.dirname(renderer), 'lib/node-image.js')));
const folder = path.join(root, 'godot/assets/vfx/player_basic_attack');
const previews = path.join(root, 'artifacts/player_basic_vfx/effects');
fs.mkdirSync(previews, { recursive: true });
const keys = ['right', 'left', 'up', 'down', 'air_up', 'air_down'];
const resources = [];
const animations = [];
const manifest = { generator: 'Scenario Pixel VFX Forge', renderer_sha256: crypto.createHash('sha256').update(fs.readFileSync(renderer)).digest('hex'), effects: {} };
for (const key of keys) {
  const recipePath = path.join(folder, 'recipes', `slash_${key}.recipe.json`);
  const recipe = JSON.parse(fs.readFileSync(recipePath, 'utf8'));
  const stem = recipe.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const destination = path.join(folder, 'generated', `slash_${key}`);
  const result = spawnSync(process.execPath, [renderer, recipePath, '--out', destination, '--frames', '--force'], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout);
  process.stdout.write(result.stdout);
  const atlas = JSON.parse(fs.readFileSync(path.join(destination, `${stem}.json`), 'utf8'));
  const sheetPath = path.join(destination, `${stem}.png`);
  const sheet = decodePNG(fs.readFileSync(sheetPath));
  const source = `res://assets/vfx/player_basic_attack/generated/slash_${key}/${stem}.png`;
  const id = `sheet_${key}`;
  resources.push(`[ext_resource type="Texture2D" path="${source}" id="${id}"]`);
  const visible = [];
  for (let index = 0; index < atlas.frames.length; index++) {
    const { x, y, w, h } = atlas.frames[index].frame;
    let coverage = 0;
    for (let py = y; py < y + h; py++) for (let px = x; px < x + w; px++) {
      if (sheet.rgba[(py * sheet.w + px) * 4 + 3]) coverage++;
    }
    if (coverage) visible.push(index);
  }
  if (visible.length < 3) throw new Error(`${key}: too few drawable frames`);
  // Trim only transparent leading/trailing cels; keep the source atlas intact.
  const first = visible[0], last = visible.at(-1);
  const frames = [];
  for (let index = first; index <= last; index++) {
    const { x, y, w, h } = atlas.frames[index].frame;
    const frameId = `${key}_${index}`;
    frames.push({ id: frameId, x, y, w, h });
  }
  animations.push({ key, id, frames, fps: atlas.meta.fps });
  // The runtime maps this one Forge texture sector onto the actual blade's
  // previous/current pose. Its bright leading edge must end at the steel tip.
  const peak = Math.min(2, last);
  const layer = recipe.layers.find(item => item.type === 'slash');
  const localTime = (peak / (recipe.frames - 1) - (layer.t0 ?? 0)) / ((layer.t1 ?? 1) - (layer.t0 ?? 0));
  const head = 1 - (1 - Math.max(0, Math.min(1, localTime / layer.sweep))) ** 3;
  const afterT = Math.max(0, Math.min(1, (localTime - layer.sweep) / (1 - layer.sweep)));
  const after = afterT * afterT * (3 - 2 * afterT);
  const tail = Math.max(0, head - layer.trail * (1 - after));
  const radians = degrees => degrees * Math.PI / 180;
  const ribbon = {
    atlas_frame: atlas.frames[peak].frame,
    center: [recipe.w / 2, recipe.h / 2],
    start_angle: radians(layer.a0 + (layer.a1 - layer.a0) * tail + (layer.angle ?? 0)),
    end_angle: radians(layer.a0 + (layer.a1 - layer.a0) * head + (layer.angle ?? 0)),
    outer_radius: layer.r * Math.min(recipe.w, recipe.h) / 2,
    inner_ratio: Math.max(0.35, (layer.r - layer.th * 2.2) / layer.r)
  };
  manifest.effects[key] = { sheet: source, recipe: `recipes/slash_${key}.recipe.json`, first_frame: first, last_frame: last, frame_count: frames.length, frame_size: [recipe.w, recipe.h], ribbon, sha256: crypto.createHash('sha256').update(fs.readFileSync(sheetPath)).digest('hex') };
  const gif = `${stem}@4x.gif`;
  fs.copyFileSync(path.join(destination, gif), path.join(previews, gif));
  fs.unlinkSync(path.join(destination, gif));
  const duplicate = path.join(destination, `${stem}.recipe.json`);
  if (fs.existsSync(duplicate)) fs.unlinkSync(duplicate);
}
const frameCount = animations.reduce((sum, item) => sum + item.frames.length, 0);
let tres = `[gd_resource type="SpriteFrames" load_steps=${1 + keys.length + frameCount} format=3]\n\n${resources.join('\n')}\n\n`;
for (const item of animations) for (const frame of item.frames) {
  tres += `[sub_resource type="AtlasTexture" id="${frame.id}"]\natlas = ExtResource("${item.id}")\nregion = Rect2(${frame.x}, ${frame.y}, ${frame.w}, ${frame.h})\nfilter_clip = true\n\n`;
}
tres += '[resource]\nanimations = [\n' + animations.map(item => `{"frames": [${item.frames.map(frame => `{"duration": 1.0, "texture": SubResource("${frame.id}")}`).join(', ')}], "loop": false, "name": &"${item.key}", "speed": ${item.fps}.0}`).join(',\n') + '\n]\n';
fs.writeFileSync(path.join(folder, 'basic_slashes.tres'), tres);
fs.writeFileSync(path.join(folder, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`PLAYER_BASIC_VFX_BUILD effects=${keys.length} visible_frames=${frameCount}`);
