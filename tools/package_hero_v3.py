"""Slice generated source sheets; preserve alpha, shared scale and grounded soles.

No invented tween frames: previews and the runtime use the authored poses.
Run from any directory after sources/*.png have been generated.
"""
import json
from pathlib import Path
from statistics import median
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, find_objects, distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/assets/sprites/player/generated_hero_v3'
SIZE, BASELINE = 384, 280
ROWS = {
    'movement': ['idle', 'run', 'jump', 'landing'],
    'combat': ['attack_1', 'air_attack', 'attack_2', 'down_attack'],
    'traversal': ['dash', 'wall_slide', 'hook_throw', 'phase'],
    'skills': ['heal', 'skill_projectile', 'skill_control', 'skill_defense'],
    'reactions': ['hurt', 'death', 'guard', 'resonance'],
}

def extract_poses(source):
    """Assign complete alpha components before cropping across authored grid rows.

    Touching shapes spanning two columns remain ambiguous and are audited.
    """
    pixels = np.asarray(source).copy()
    components, _ = label(pixels[:, :, 3] > 24)
    boxes = find_objects(components)
    areas = np.bincount(components.ravel())
    owners = np.zeros(components.shape, dtype=np.int16)
    ambiguous = set()
    for number, box in enumerate(boxes, 1):
        if areas[number] < 1000:
            continue
        y, x = box
        row = min(3, int((y.start + y.stop) * 2 / source.height))
        column = min(3, int((x.start + x.stop) * 2 / source.width))
        mask = components == number
        if x.stop - x.start > source.width / 4 * 1.6:
            for col in range(4):
                left, right = round(col * source.width / 4), round((col + 1) * source.width / 4)
                part = mask[:, left:right]
                if part.sum() >= 1000:
                    owners[:, left:right][part] = row * 4 + col + 1
                    ambiguous.add(row * 4 + col)
        else:
            owners[mask] = row * 4 + column + 1
    distance, nearest = distance_transform_edt(owners == 0, return_indices=True)
    assigned = owners[nearest[0], nearest[1]]
    assigned[distance > 48] = 0
    cells, origins = [], []
    for index in range(16):
        pose = pixels.copy()
        pose[assigned != index + 1] = 0
        image = Image.fromarray(pose)
        bounds = image.getbbox()
        if bounds is None:
            raise ValueError(f'Missing authored pose {index}; refuse incomplete pack')
        cells.append(image.crop(bounds))
        origins.append(bounds)
    return cells, origins, ambiguous


def boot_baseline(cell):
    p = np.asarray(cell)
    r, g, b, a = [p[:, :, i].astype(float) for i in range(4)]
    mask = (a > 128) & (r > g * 1.04) & (g > b * 1.1) & (r < 180) & (g > 35)
    mask[:int(cell.height * .55)] = False
    ys = np.flatnonzero(mask.sum(axis=1) >= 5)
    return int(ys[-1]) if len(ys) else cell.getbbox()[3] - 1

def body_height(cell):
    p = np.asarray(cell)
    dark = (p[:, :, :3].max(axis=2) < 80) & (p[:, :, 3] > 128)
    dark[:, :int(cell.width * .35)] = False
    dark[:, int(cell.width * .8):] = False
    ys = np.flatnonzero(dark.sum(axis=1) >= 6)
    return boot_baseline(cell) - int(ys[0]) if len(ys) else cell.height * .7

def package():
    (OUT / 'frames').mkdir(parents=True, exist_ok=True)
    (OUT / 'previews').mkdir(exist_ok=True)
    specs, audit, actions = [], [], {}
    for sheet, names in ROWS.items():
        source = Image.open(OUT / 'sources' / (sheet + '.png')).convert('RGBA')
        cells, origins, ambiguous = extract_poses(source)
        # One scale per sheet, measured from standing bodies, never from swords.
        scale = 128 / median(body_height(cell) for cell in cells[:4])
        for row, name in enumerate(names):
            images, paths = [], []
            # Preserve authored horizontal placement; cape/weapon bounding boxes
            # must never pull the body sideways when the pose changes.
            for col in range(4):
                cell = cells[row * 4 + col]
                foot = boot_baseline(cell)
                scaled = cell.resize((round(cell.width * scale), round(cell.height * scale)), Image.Resampling.LANCZOS)
                frame = Image.new('RGBA', (SIZE, SIZE))
                origin = origins[row * 4 + col]
                body_anchor = (col + .6) * source.width / 4 - origin[0]
                offset = (round(SIZE / 2 - body_anchor * scale), round(BASELINE - foot * scale))
                frame.alpha_composite(scaled, offset)
                bbox = frame.getbbox()
                source_box = cell.getbbox()
                edge = origin[0] < 8 or origin[1] < 8 or origin[2] > source.width - 8 or origin[3] > source.height - 8
                clipped = offset[0] + source_box[0] * scale < 0 or offset[0] + source_box[2] * scale > SIZE or offset[1] + source_box[1] * scale < 0 or offset[1] + source_box[3] * scale > SIZE
                audit.append({'action': name, 'frame': col, 'source_edge_contact': edge, 'output_clipped': clipped,
                              'sheet_scale': round(scale, 6), 'source_foot_y': foot, 'bbox': bbox,
                              'source_bounds': origin, 'ambiguous_connected_pose': row * 4 + col in ambiguous})
                if clipped:
                    raise ValueError(f'{name}/{col}: authored pixels exceed canvas; refuse silent clipping')
                key = f'{name}_{col:02d}'
                path = OUT / 'frames' / (key + '.png')
                frame.save(path)
                paths.append('res://' + path.relative_to(ROOT / 'godot').as_posix())
                images.append(frame)
            actions[name] = (paths, images)
            fps = 12 if name == 'run' else 10
            loop = name in ['idle', 'run', 'wall_slide', 'phase']
            specs.append({'name': name, 'fps': fps, 'loop': loop, 'frames': paths})
            # Checkerboard is preview-only; runtime frames retain generated alpha.
            gif_frames = []
            contact = Image.new('RGB', (SIZE * 4, SIZE + 24), '#15252c')
            for index, im in enumerate(images):
                bg = Image.new('RGB', im.size, '#15252c');bg.paste(im, mask=im.getchannel('A'));gif_frames.append(bg)
                contact.paste(bg, (index * SIZE, 24))
            ImageDraw.Draw(contact).text((8, 5), name, fill='#eadfc3')
            contact.save(OUT / 'previews' / (name + '_contact.jpg'), quality=92)
            gif_frames[0].save(OUT / 'previews' / (name + '.gif'), save_all=True, append_images=gif_frames[1:], duration=round(1000/fps), loop=0)
    for name, source, indices, fps, loop in [
        ('jump_start', 'jump', [1, 2], 18, False), ('jump_loop', 'jump', [3], 8, True),
        ('fall', 'landing', [0], 8, True), ('land', 'landing', [1, 2, 3], 22, False),
        ('skill_melee', 'attack_2', [0, 1, 2, 3], 10, False),
        ('skill_wave', 'skill_control', [0, 1, 2, 3], 10, False),
        ('item_use', 'skill_projectile', [0, 1, 2, 3], 10, False)]:
        specs.append({'name': name, 'fps': fps, 'loop': loop, 'frames': [actions[source][0][i] for i in indices]})
    manifest = {'version': 3, 'source': 'imagegen authored poses', 'frame_size': [SIZE, SIZE],
                'foot_baseline': BASELINE, 'sprite_scale': .66, 'sprite_position': [0, -(BASELINE - SIZE/2)*.66],
                'animations': specs, 'limitations': ['Four authored poses per action family; fall/apex are held poses.',
                'Melee and area-wave skills share family poses; distinct runtime effects and phases remain.',
                'Touching source weapons and outer-source edge contacts need art review; see crop_audit.json.']}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    (OUT / 'crop_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
    print(json.dumps({'animations': len(specs), 'frames': len(audit), 'source_edge_contacts': sum(v['source_edge_contact'] for v in audit), 'ambiguous_poses': sum(v['ambiguous_connected_pose'] for v in audit), 'output_clipped': sum(v['output_clipped'] for v in audit)}))

if __name__ == '__main__':
    package()
