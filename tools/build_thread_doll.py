"""Package the complete authored thread-doll body. No generated pose interpolation.

Original source pixels are only isolated, cropped, uniformly scaled per sheet,
and registered at the painted soles / chest knot. The short running feet use a
single immutable crop; running upper bodies are separately authored full hems.
"""
import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_requests/thread_doll_motion_v1'
OUT = ROOT / 'godot/assets/sprites/player/thread_doll_v1'
RES = 'res://assets/sprites/player/thread_doll_v1/'
AIR = {'jump_loop', 'fall', 'air_attack', 'air_up_attack', 'down_attack', 'dash', 'wall_slide', 'phase'}
MELEE = {'attack_1', 'attack_2', 'run_attack', 'up_attack', 'ground_down_attack', 'down_attack', 'air_attack', 'air_up_attack', 'skill_melee'}
GROUND = 280
SUPPORT_X = 186.0
EYE = (211.0, 208.0)


def encoded(im):
    b = BytesIO()
    im.save(b, format='PNG')
    return b.getvalue()


def silhouette(cell):
    rgba = np.array(cell.convert('RGBA'))
    solid = rgba[:, :, 3] > 160
    labels, count = ndimage.label(solid, np.ones((3, 3)))
    if not count: raise ValueError('Empty authored cel')
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    body = labels == int(sizes.argmax())
    yy, xx = np.nonzero(body)
    if xx.min() <= 1 or yy.min() <= 1 or xx.max() >= cell.width-2 or yy.max() >= cell.height-2:
        raise ValueError('Authored figure touches cell edge')
    # The generator leaves faint alpha=1 RGB matte in transparent gutters.
    # Keep painted components attached to/near the body and their AA rim only.
    distance = ndimage.distance_transform_edt(~body)
    accepted = [int(sizes.argmax())]
    for k in range(1, count+1):
        if sizes[k] >= 5 and float(distance[labels == k].min()) <= 12:
            accepted.append(k)
    ink = np.isin(labels, accepted)
    keep = ndimage.binary_dilation(ink, iterations=2)
    rgba[~keep] = 0
    rgba[rgba[:, :, 3] <= 8] = 0
    return Image.fromarray(rgba), body


def eye_anchor(im, body):
    a = np.asarray(im).astype(int)
    yy, xx = np.nonzero(body)
    top, bottom = int(yy.min()), int(yy.max())
    mask = body & (a[:,:,0] > 170) & (a[:,:,1] > 100) & (a[:,:,2] < 100) & (a[:,:,0]-a[:,:,1] > 30) & (a[:,:,1]-a[:,:,2] > 35)
    mask[round(top+(bottom-top)*.65):] = False
    labels, count = ndimage.label(mask, np.ones((3, 3)))
    if not count: raise ValueError('Amber eye slit not found')
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    y, x = np.nonzero(labels == int(sizes.argmax()))
    return float(np.median(x)), float(np.median(y))


def hood_span(cell):
    im, body = silhouette(cell)
    yy, _ = np.nonzero(body)
    top, bottom = int(yy.min()), int(yy.max())
    spans = []
    for y in range(top+int((bottom-top)*.2), top+int((bottom-top)*.4)):
        x = np.nonzero(body[y])[0]
        if len(x): spans.append(int(x.max())-int(x.min()))
    return float(np.median(spans))


def register(cell, scale, airborne):
    im, body = silhouette(cell)
    if airborne:
        anchor = eye_anchor(im, body)
        target = EYE
    else:
        a = np.asarray(im).astype(float)
        y, _ = np.nonzero(body)
        floor = int(y.max())
        # A downward needle can be lower than the boots. Locate wide brown
        # wrapped-foot ink, excluding thin metal/red filaments, before taking
        # the actual alpha baseline. Never register a body at its weapon tip.
        rgb = a[:,:,:3]
        feet = body & (rgb[:,:,0] > rgb[:,:,1]*1.05) & (rgb[:,:,0] < rgb[:,:,1]*1.7)
        feet &= (rgb[:,:,1] > rgb[:,:,2]*1.03) & (rgb[:,:,1] < rgb[:,:,2]*1.9) & (rgb.mean(2)>25) & (rgb.mean(2)<135)
        try:
            ex, ey = eye_anchor(im, body)
            hood = 80.0/scale
            xx,yy = np.meshgrid(np.arange(im.width),np.arange(im.height))
            feet &= (yy > ey+hood*.4) & (xx > ex-hood*.8) & (xx < ex+hood*.6)
            feet = ndimage.binary_opening(feet, structure=np.ones((3,3)))
            fy,fx = np.nonzero(feet)
            if len(fx) > 8:
                support = np.zeros_like(body)
                support[max(0,int(fy.max())-6):min(im.height,int(fy.max())+5),max(0,int(fx.min())-4):min(im.width,int(fx.max())+5)] = True
                support &= body
                fy,fx = np.nonzero(support)
                floor = int(fy.max())
                _,x = np.nonzero(support[max(0,floor-3):floor+1])
            else:
                _,x = np.nonzero(body[max(0,floor-3):floor+1])
        except ValueError:
            _,x = np.nonzero(body[max(0,floor-3):floor+1])
        anchor = (float(x.min()+x.max())*.5, float(floor))
        target = (SUPPORT_X, float(GROUND))
    box = im.getbbox()
    crop = im.crop(box)
    size = tuple(max(1, round(v*scale)) for v in crop.size)
    resized = crop.resize(size, Image.Resampling.LANCZOS)
    origin = (round(target[0]+(box[0]-anchor[0])*scale), round(target[1]+(box[1]-anchor[1])*scale))
    if min(origin) <= 1 or origin[0]+size[0] >= 383 or origin[1]+size[1] >= 383:
        raise ValueError(f'Registration clips a complete drawing: origin={origin} size={size}')
    out = Image.new('RGBA', (384, 384))
    out.alpha_composite(resized, origin)
    return out, {'source_anchor':list(anchor), 'target_anchor':list(target), 'origin':list(origin), 'size':list(size)}


def sole_centers(im):
    a = np.asarray(im)[:, :, 3]
    positions = []
    for left, right in [(150, 185), (185, 230)]:
        _, x = np.nonzero(a[276:282, left:right] > 128)
        if not len(x): raise ValueError('A short support foot is missing')
        positions.append(float(x.mean()+left))
    return positions


def awl_anchors(im):
    """Measure the visible awl's bright metal tip, away from hood/amber light.

    The crop's metal and brass are low-chroma bright pixels in the body/hand
    band. A principal axis describes the actual tip; missing tools remain [].
    """
    a = np.asarray(im).astype(float)
    yy, xx = np.indices(a.shape[:2])
    rgb = a[:, :, :3]
    metal = (a[:, :, 3] > 100) & (rgb.mean(2) > 85) & ((rgb.max(2)-rgb.min(2)) < 70)
    metal &= (yy > 190) & (yy < 305) & (xx > 200)
    labels, count = ndimage.label(metal, np.ones((3, 3)))
    best = None
    for k in range(1, count+1):
        y, x = np.nonzero(labels == k)
        if len(x) < 6: continue
        points = np.column_stack([x, y]).astype(float)
        centre = points.mean(0)
        _, _, axes = np.linalg.svd(points-centre, full_matrices=False)
        projection = (points-centre)@axes[0]
        length = float(projection.max()-projection.min())
        if length < 5 or (best is not None and centre[0] <= best[0]): continue
        ends = [centre+axes[0]*projection.min(), centre+axes[0]*projection.max()]
        ends.sort(key=lambda p:p[0])
        best = (centre[0], [[round(float(v), 1) for v in p] for p in ends])
    return best[1] if best is not None else []

def thread_anchor(im):
    a = np.asarray(im).astype(int)
    body = a[:,:,3]>160
    try:
        ex, ey = eye_anchor(im, body)
    except ValueError:
        return [212.0,225.0]
    mask = body & (a[:,:,0]>90) & (a[:,:,0]-a[:,:,1]>35) & (a[:,:,0]-a[:,:,2]>35)
    roi = np.zeros_like(mask)
    roi[max(0,int(ey)+7):min(384,int(ey)+35),max(0,int(ex)-27):min(384,int(ex)+15)] = True
    density = np.round(ndimage.uniform_filter((mask & roi).astype(float), size=7),8)
    if density.max() < .04: return [212.0,225.0]
    y,x = np.unravel_index(int(density.argmax()), density.shape)
    yy,xx = np.nonzero((mask & roi)[max(0,y-5):y+6,max(0,x-5):x+6])
    return [round(float(xx.mean()+max(0,x-5)),6),round(float(yy.mean()+max(0,y-5)),6)]


def build(check=False):
    source = json.loads((SOURCE/'generation_manifest.json').read_text(encoding='utf-8'))
    contract = json.loads((SOURCE/'runtime_contract.json').read_text(encoding='utf-8'))
    sheets, scales = {}, {}
    for id, batch in source['batches'].items():
        path = SOURCE/batch['source']
        if sha256(path.read_bytes()).hexdigest() != batch['source_sha256'] or sha256((SOURCE/batch['prompt']).read_bytes()).hexdigest() != batch['prompt_sha256']:
            raise ValueError(f'{id}: source/provenance changed')
        im = Image.open(path).convert('RGBA')
        first = next(spec for spec in source['actions'].values() if spec['batch'] == id)
        x,y,w,h = first['regions'][0]
        neutral = im.crop((x,y,x+w,y+h))
        try:
            scales[id] = round(80.0/hood_span(neutral), 9)
        except ValueError as e:
            raise ValueError(f'batch {id}: {e}') from e
        sheets[id] = im
    outputs, images, registrations, anchors = {}, {}, {}, {}
    unique = set()
    for action, spec in source['actions'].items():
        entries, cels = [], []
        indices = [0, 1, 2, 3, 5, 7] if action == 'run_attack' else range(len(spec['regions']))
        for index, selected in enumerate(indices):
            x, y, w, h = spec['regions'][selected]
            airborne = action in AIR or action == 'run_upper' or (action == 'jump' and index >= 2)
            if action == 'death': airborne = False
            try:
                im, entry = register(sheets[spec['batch']].crop((x, y, x+w, y+h)), scales[spec['batch']], airborne)
            except ValueError as e:
                raise ValueError(f'{action}[{index}]: {e}') from e
            digest = sha256(im.tobytes()).hexdigest()
            if digest in unique: raise ValueError(f'{action}: duplicate source cel')
            unique.add(digest)
            entry.update(source_region=[x,y,w,h], visible_sha256=digest)
            entries.append(entry); cels.append(im)
            folder = 'upper' if action == 'run_upper' else 'frames'
            name = 'run' if action == 'run_source' else action
            outputs[OUT/folder/f'{name}_{index:02d}.png'] = encoded(im)
        images[action] = cels
        registrations[action] = {'batch':spec['batch'], 'scale':scales[spec['batch']], 'frames':entries}
        if action in MELEE: anchors[action] = [awl_anchors(im) for im in cels]
    # One genuinely painted short foot, copied identically for both sides.
    foot = images['idle'][0].crop((185, 269, 210, 282))
    outputs[OUT/'foot.png'] = encoded(foot)
    animations = []
    thread_points = {}
    for old in contract['animations']:
        name = old['name']
        action = {'run':'run_source','jump_start':'jump','land':'landing'}.get(name,name)
        count = len(images[action])
        frames = [RES+'frames/'+('run' if action == 'run_source' else action)+f'_{i:02d}.png' for i in range(count)]
        fps = count*285.0/float(contract['run_cycle_distance']) if name == 'run' else count/float(old['seconds'])
        animations.append(dict(name=name, fps=fps, loop=bool(old['loop']), frames=frames))
        thread_points[name] = [thread_anchor(im) for im in images[action]]
    supports = [sum(sole_centers(im))*.5 for im in images['idle']]
    planted = {name:[sum(sole_centers(im))*.5 for im in cels] for name,cels in images.items() if name == 'attack_2'}
    manifest = dict(version=1, identity='thread_doll', source='image_gen authored cloth/thread doll; no human fallback',
                    frame_size=[384,384], foot_baseline=280, sprite_scale=.66, sprite_position=[0,-58.08],
                    idle_presentation='full_body', idle_foot_center_x=supports, grounded_pose_foot_center_x=planted,
                    run_presentation='thread_doll_v1', run_cycle_distance=60.0,
                    warm_textures=[RES+'upper/run_upper_'+f'{i:02d}.png' for i in range(8)]+[RES+'foot.png'],
                    thread_origin_px=thread_points,
                    animations=animations)
    outputs[OUT/'manifest.json'] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    outputs[OUT/'blade_anchors.json'] = (json.dumps({'source_size':[384,384],'animations':anchors},indent=2)+'\n').encode()
    outputs[OUT/'registration.json'] = (json.dumps({'schema':'thread-doll-registration-v1','authored_cels':len(unique),
        'per_sheet_fixed_scale':scales,'source_manifest_sha256':sha256((SOURCE/'generation_manifest.json').read_bytes()).hexdigest(),
        'animations':registrations},indent=2)+'\n').encode()
    for path, content in outputs.items():
        if check:
            if path.suffix == '.png':
                if not path.exists() or not np.array_equal(np.asarray(Image.open(path)),np.asarray(Image.open(BytesIO(content)))):
                    raise ValueError(f'{path}: stale/missing runtime pixels')
            elif not path.exists() or path.read_bytes() != content:
                raise ValueError(f'{path}: stale/missing runtime data')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(content)
    print('THREAD_DOLL actions=%d authored_cels=%d human_fallbacks=0 check=%s' % (len(animations),len(unique),check))


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check',action='store_true')
    build(p.parse_args().check)
