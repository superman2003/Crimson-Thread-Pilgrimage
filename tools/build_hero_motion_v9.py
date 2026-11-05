"""Register complete-body idle and heavy-cut artwork, without pose synthesis."""
from hashlib import sha256
from io import BytesIO
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image
from build_hero_motion_v7 import encoded, register

ROOT = Path(__file__).resolve().parents[1]
REQUEST = ROOT/'art_requests/hero_motion_v9'
OUT = ROOT/'godot/assets/sprites/player/generated_hero_motion_v9'
MANIFEST = ROOT/'godot/assets/sprites/player/generated_hero_v3/manifest.json'
RESOURCE = 'res://assets/sprites/player/generated_hero_motion_v9/frames/'
COUNTS = {'idle':8, 'attack_2':6}


def first_difference(actual, expected, path='$'):
    if type(actual) is not type(expected):
        return f'{path}: {type(actual).__name__} != {type(expected).__name__}'
    if isinstance(expected, dict):
        if actual.keys() != expected.keys(): return f'{path}: different keys'
        for key in expected:
            diff = first_difference(actual[key], expected[key], f'{path}.{key}')
            if diff: return diff
    elif isinstance(expected, list):
        if len(actual) != len(expected): return f'{path}: different lengths'
        for index, value in enumerate(expected):
            diff = first_difference(actual[index], value, f'{path}[{index}]')
            if diff: return diff
    elif actual != expected:
        return f'{path}: {actual!r} != {expected!r}'
    return ''


def sole_centers(image):
    """Two disconnected support soles, measured from actual packed alpha."""
    mask = np.asarray(image)[276:282,:,3] > 128
    ys,xs = np.nonzero(mask)
    columns = np.unique(xs)
    if len(columns) < 8:
        raise ValueError('No visible planted boot soles')
    gaps = np.diff(columns)
    split_index = int(np.argmax(gaps))
    if gaps[split_index] < 3:
        raise ValueError('Boot soles do not have a clear separation')
    split = (columns[split_index]+columns[split_index+1])/2
    left, right = xs[xs < split], xs[xs > split]
    if min(left.size,right.size) < 8:
        raise ValueError('One planted boot is missing')
    return [float(left.mean()),float(right.mean())]


def idle_midpoint(image):
    # This is the same independent ROI measured by the real Player validator.
    a = np.asarray(image)[:,:,3]
    centers = []
    for start,end in [(150,185),(185,220)]:
        yy,xx = np.nonzero(a[276:282,start:end] > 128)
        if not len(xx): raise ValueError('Idle support moved outside its reviewed ROI')
        centers.append(float(xx.mean()+start))
    return sum(centers)/2


def ground_register(cell, scale, target_x):
    canvas,entry = register(cell,scale,False)
    before = sum(sole_centers(canvas))/2
    shift = round(target_x-before)
    bounds = canvas.getbbox()
    if bounds[0]+shift <= 0 or bounds[2]+shift >= 384:
        raise ValueError('Support registration would clip the authored pose')
    result = Image.new('RGBA',(384,384))
    result.alpha_composite(canvas,(shift,0))
    entry['output_origin'][0] += shift
    entry['target_anchor'][0] += shift
    entry['source_anchor_kind'] = 'initial dark torso; translated by painted sole registration'
    entry['registration'] = 'two painted boot soles; fixed sheet scale'
    entry['sole_centers'] = sole_centers(result)
    entry['requested_sole_midpoint'] = target_x
    entry['visible_sha256'] = sha256(result.tobytes()).hexdigest()
    return result,entry


def build(check=False):
    source = json.loads((REQUEST/'source_slices.json').read_text(encoding='utf-8'))
    calibration = json.loads((REQUEST/'calibration.json').read_text(encoding='utf-8'))
    previous = json.loads((REQUEST/'previous_animations.json').read_text(encoding='utf-8'))
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if source['missing'] or set(source['sheets']) != set(COUNTS):
        raise ValueError('Selected source delivery is incomplete')
    animations = {a['name']:a for a in manifest['animations']}
    registration = {'schema':'hero-motion-v9-registration', 'new_drawings':14,
                    'frame_size':[384,384], 'ground_row':280, 'animations':{}}
    outputs,unique = {},set()
    idle_centers,idle_images,heavy_centers = [],[],[]
    for name,count in COUNTS.items():
        spec = source['sheets'][name]
        path = REQUEST/spec['source']
        if sha256(path.read_bytes()).hexdigest()!=spec['source_sha256'] or sha256(path.with_suffix('.txt').read_bytes()).hexdigest()!=spec['prompt_sha256']:
            raise ValueError(f'{name}: selected source or actual prompt changed')
        measure = calibration['sheets'][name]
        if measure['source_sha256'] != spec['source_sha256'] or len(spec['regions']) != count:
            raise ValueError(f'{name}: source registration needs review')
        scale = float(measure['shared_scale'])
        sheet = Image.open(path).convert('RGBA')
        entries = []
        for index,(x,y,w,h) in enumerate(spec['regions']):
            canvas,entry = ground_register(sheet.crop((x,y,x+w,y+h)),scale,float(calibration['target_soles_midpoint']))
            entry['source_region'] = [x,y,w,h]
            if entry['visible_sha256'] in unique: raise ValueError('Repeated authored cel')
            unique.add(entry['visible_sha256'])
            if name == 'idle':
                idle_centers.append(idle_midpoint(canvas))
                idle_images.append(canvas)
            else:
                heavy_centers.append(sum(entry['sole_centers'])/2)
            entries.append(entry)
            outputs[OUT/'frames'/f'{name}_{index:02d}.png'] = encoded(canvas)
        registration['animations'][name] = {'source':spec['source'], 'source_sha256':spec['source_sha256'],
            'shared_scale':scale, 'frames':entries}
        frames = [RESOURCE+f'{name}_{index:02d}.png' for index in range(count)]
        expected = dict(previous[name], frames=frames, fps=5.0 if name=='idle' else 15.0)
        if name=='attack_2' and abs(len(previous[name]['frames'])/previous[name]['fps']-count/expected['fps'])>1e-9:
            raise ValueError('Heavy attack nominal playback length changed')
        current = animations[name]
        if check:
            if current != expected: raise ValueError(f'{name}: production animation differs')
        else:
            if current['frames'] not in [previous[name]['frames'],frames]:
                raise ValueError(f'{name}: refusing to overwrite unrelated artwork')
            current.update(expected)
    if check:
        if manifest.get('idle_presentation')!='full_body' or manifest.get('idle_foot_center_x')!=idle_centers or manifest.get('grounded_pose_foot_center_x')!={'attack_2':heavy_centers}:
            raise ValueError('Complete-body idle registration is not active')
    else:
        manifest['idle_presentation'] = 'full_body'
        manifest['idle_foot_center_x'] = idle_centers
        manifest['grounded_pose_foot_center_x'] = {'attack_2':heavy_centers}
        outputs[MANIFEST] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    # Record silhouette/cloth continuity without manufacturing intermediate poses.
    premultiplied = []
    for im in idle_images:
        a = np.asarray(im).astype(float)/255
        a[:,:,:3] *= a[:,:,3:4]
        premultiplied.append(a)
    # This diagnostic reduction can differ in its last floating-point bits across
    # NumPy/SIMD builds. Canonicalize it; all RGBA hashes and anchors stay exact.
    registration['idle_adjacent_pixel_distance'] = [round(float(np.mean(np.abs(premultiplied[(i+1)%8]-a))),12) for i,a in enumerate(premultiplied)]
    registration['idle_foot_center_x'] = idle_centers
    registration['grounded_pose_foot_center_x'] = {'attack_2':heavy_centers}
    outputs[OUT/'registration.json'] = (json.dumps(registration,ensure_ascii=False,indent=2)+'\n').encode()
    for path,content in outputs.items():
        if check:
            if not path.exists(): raise ValueError(f'{path}: missing output')
            if path.suffix=='.png':
                if not np.array_equal(np.asarray(Image.open(path)),np.asarray(Image.open(BytesIO(content)))):
                    raise ValueError(f'{path}: stale pixels')
            elif path.read_bytes()!=content:
                diff = first_difference(json.loads(path.read_bytes()), json.loads(content))
                raise ValueError(f'{path}: stale registration ({diff or "noncanonical JSON formatting"})')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(content)
    print('HERO_MOTION_V9 actions=2 drawings=%d idle_seconds=1.6 heavy_clock=preserved check=%s' % (len(unique),check))


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    build(parser.parse_args().check)
