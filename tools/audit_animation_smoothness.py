#!/usr/bin/env python3
"""V02: measure why hero and enemy motion reads as choppy (report only).

Reads the runtime animation data the game actually loads and prints:

- hero: frames, distinct images, fps and duration per action
  (godot/assets/sprites/player/generated_hero_v3/manifest.json);
- enemies: for every ordinary/elite command of every creature, the frames the
  phase plays and the effective rate after enemy_actor._fit_animation_duration
  stretches them over the command's windup/active/recover time, plus the
  phases that end in a short hold loop (POSE_LOOP_LEAD in enemy_actor.gd);
- frame-to-frame change: how much of the silhouette differs between
  consecutive frames (1 - overlap / union of the alpha masks). Very small
  changes read as sliding or a frozen pose; very large ones as a jump (a limb
  or prop popping to a new place with nothing in between).

It never fails; it records a baseline so art and engine changes can be
compared. --sheets DIR also writes contact sheets of the worst cases.
"""
import argparse
import functools
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / 'godot'
HERO = GODOT / 'assets/sprites/player/generated_hero_v3/manifest.json'
COMBAT = GODOT / 'data/original_creature_combat.json'
CREATURES = GODOT / 'assets/sprites/original_creatures'
# enemy_actor.gd POSE_LOOP_LEAD: a phase longer than lead + 0.12 s fits its main
# animation into the lead and then loops the follow-up animation.
LOOP_LEAD = {'windup': 0.42, 'active': 0.2, 'recover': 0.18}
LOW_FPS = 8.0
JUMP = 0.5     # half the silhouette replaced between two adjacent frames


def res(path):
    return GODOT / str(path).replace('res://', '').replace('godot/', '', 1)


def animations(manifest):
    anims = manifest.get('animations', {})
    if isinstance(anims, list):
        return {a.get('name'): a for a in anims}
    return anims


def find(anims, name):
    return anims.get(name) or anims.get(name + '_right') or anims.get(name + '_left')


def phase_animation(anims, command, phase):
    """Mirror of enemy_actor._pose_sprite: (main animation, follow-up loop)."""
    own = str(command.get('id', ''))
    base = own if own and (find(anims, own) or find(anims, own + '_windup')) else str(command.get('animation', 'attack'))
    if phase == 'windup':
        name = base + '_windup' if find(anims, base + '_windup') else 'windup'
        return name, base + '_charge' if name != 'windup' else 'charge'
    if phase == 'active':
        name = base if find(anims, base) else 'attack'
        return name, base + '_travel' if name != 'attack' else 'travel'
    name = base + '_recover' if find(anims, base + '_recover') else ('recover' if find(anims, 'recover') else 'idle')
    if name == 'recover' and find(anims, base + '_bridge'):
        return base + '_bridge', 'recover'
    if name == 'recover' and find(anims, base + '_settle'):
        return base + '_settle', 'idle'
    return name, ''


def creature_manifest(kind):
    for name in ('motion_manifest.json', 'manifest.json'):
        path = CREATURES / kind / name
        if path.exists():
            return json.loads(path.read_text(encoding='utf-8'))
    return None


def enemy_phases():
    combat = json.loads(COMBAT.read_text(encoding='utf-8'))
    rows = []
    for kind, profile in combat.items():
        manifest = creature_manifest(kind)
        if manifest is None:
            continue
        anims = animations(manifest)
        for command in profile.get('attacks', []) + profile.get('elite', {}).get('attacks', []):
            for phase in ('windup', 'active', 'recover'):
                name, loop = phase_animation(anims, command, phase)
                anim = find(anims, name)
                if not anim:
                    continue
                duration = float(command.get(phase, 0.3))
                frames = len(anim.get('frames', []))
                looped = bool(loop) and find(anims, loop) is not None and duration > LOOP_LEAD[phase] + 0.12
                main = LOOP_LEAD[phase] if looped else duration
                loop_frames = len(find(anims, loop).get('frames', [])) if looped else 0
                rows.append({'kind': kind, 'command': command.get('id', ''), 'phase': phase, 'animation': name,
                             'frames': frames, 'seconds': round(main, 3), 'effective_fps': round(frames / max(0.01, main), 1),
                             'loop': loop if looped else '', 'loop_frames': loop_frames,
                             'loop_seconds': round(duration - main, 3) if looped else 0.0})
    return rows


@functools.lru_cache(maxsize=8)
def atlas_image(path):
    from PIL import Image
    return Image.open(res(path)).convert('RGBA')


def frame_images(manifest, anim):
    from PIL import Image
    images = []
    canvas = manifest.get('canvas')
    for frame in anim.get('frames', []):
        if isinstance(frame, dict):
            atlas = atlas_image(frame['atlas'])
            x, y, w, h = frame['region']
            crop = atlas.crop((x, y, x + w, y + h))
            sheet = Image.new('RGBA', tuple(canvas), (0, 0, 0, 0))
            sheet.alpha_composite(crop, (int(frame['margin'][0]), int(frame['margin'][1])))
            images.append(sheet)
        else:
            images.append(Image.open(res(frame)).convert('RGBA'))
    return images


def mask(image):
    import numpy
    return numpy.asarray(image.getchannel('A')) > 40


def change(a, b):
    """Silhouette change (0..1): 1 - overlap / union of the two alpha masks."""
    union = (a | b).sum()
    return 0.0 if union == 0 else 1.0 - float((a & b).sum()) / float(union)


def frame_changes(names=('idle', 'walk', 'windup', 'attack', 'recover')):
    rows = []
    for path in sorted(CREATURES.iterdir()):
        manifest = creature_manifest(path.name)
        if manifest is None:
            continue
        anims = animations(manifest)
        for name in names:
            anim = find(anims, name)
            if not anim or len(anim.get('frames', [])) < 2:
                continue
            images = [mask(im) for im in frame_images(manifest, anim)]
            steps = [change(images[i - 1], images[i]) for i in range(1, len(images))]
            # Reference: the first frame against itself moved 2px sideways, the
            # change a perfectly held pose would show from a small step.
            shifted = images[0].copy()
            shifted[:, 2:] = images[0][:, :-2]
            shifted[:, :2] = False
            rows.append({'kind': path.name, 'animation': name, 'frames': len(images),
                         'mean_change': round(statistics.mean(steps), 3), 'max_change': round(max(steps), 3),
                         'shift_2px': round(change(images[0], shifted), 3)})
    return rows


def hero_rows():
    manifest = json.loads(HERO.read_text(encoding='utf-8'))
    rows = []
    for anim in manifest['animations']:
        frames = anim.get('frames', [])
        fps = float(anim.get('fps', 8))
        rows.append({'animation': anim['name'], 'frames': len(frames), 'distinct': len(set(frames)),
                     'fps': fps, 'seconds': round(len(frames) / fps, 2), 'loop': bool(anim.get('loop', False))})
    return rows


def write_sheets(directory, changes):
    from PIL import Image
    directory.mkdir(parents=True, exist_ok=True)
    walks = [r for r in changes if r['animation'] == 'walk']
    picks = sorted(walks, key=lambda r: r['mean_change'])[:3] + sorted(changes, key=lambda r: -r['max_change'])[:3]
    for row in picks:
        manifest = creature_manifest(row['kind'])
        images = frame_images(manifest, find(animations(manifest), row['animation']))
        height = 160
        scaled = [im.resize((max(1, im.width * height // im.height), height)) for im in images]
        sheet = Image.new('RGBA', (sum(im.width for im in scaled), height), (36, 46, 52, 255))
        x = 0
        for im in scaled:
            sheet.alpha_composite(im, (x, 0))
            x += im.width
        sheet.convert('RGB').save(directory / f"{row['kind']}_{row['animation']}.png")


def summary(hero, phases, changes):
    lines = ['HERO actions=%d frames=%d distinct=%d held_loops=%s' % (
        len(hero), sum(r['frames'] for r in hero), sum(r['distinct'] for r in hero),
        [r['animation'] for r in hero if r['loop'] and r['frames'] <= 2])]
    for phase in ('windup', 'active', 'recover'):
        values = [r['effective_fps'] for r in phases if r['phase'] == phase]
        lines.append('ENEMY %s phases=%d effective_fps median=%.1f min=%.1f below_%d=%d' % (
            phase, len(values), statistics.median(values), min(values), LOW_FPS, sum(1 for v in values if v < LOW_FPS)))
    loops = [r for r in phases if r['loop']]
    lines.append('ENEMY loops=%d two_frame=%d two_frame_over_0.5s=%d' % (
        len(loops), sum(1 for r in loops if r['loop_frames'] <= 2),
        sum(1 for r in loops if r['loop_frames'] <= 2 and r['loop_seconds'] > 0.5)))
    if changes:
        medians = ' '.join('%s=%.2f' % (name, statistics.median(r['mean_change'] for r in changes if r['animation'] == name))
                           for name in ('idle', 'walk', 'windup', 'attack', 'recover'))
        lines.append('ENEMY frame_change cycles=%d median %s shift_2px_reference=%.2f jumpy_over_%.1f=%d' % (
            len(changes), medians, statistics.median(r['shift_2px'] for r in changes), JUMP,
            sum(1 for r in changes if r['max_change'] > JUMP)))
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--json', type=Path, help='write all rows to this file')
    parser.add_argument('--no-images', action='store_true', help='skip the pixel comparison (no Pillow needed)')
    parser.add_argument('--sheets', type=Path, help='write contact sheets of the stillest walks and jumpiest cycles here')
    args = parser.parse_args()
    hero, phases = hero_rows(), enemy_phases()
    changes = [] if args.no_images else frame_changes()
    for line in summary(hero, phases, changes):
        print(line)
    if args.json:
        args.json.write_text(json.dumps({'hero': hero, 'enemy_phases': phases, 'frame_changes': changes},
                                        ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    if args.sheets and changes:
        write_sheets(args.sheets, changes)
    return 0


if __name__ == '__main__':
    sys.exit(main())
