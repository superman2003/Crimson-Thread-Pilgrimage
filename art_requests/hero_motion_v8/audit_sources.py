"""Measure the delivered cels and their gutters before any runtime registration."""
from pathlib import Path
from hashlib import sha256
import argparse
import json
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent


def collect():
    plan = json.loads((HERE/'requests.json').read_text(encoding='utf-8'))
    result = {'schema':'hero-motion-v8-source-slices', 'alpha_threshold':96,
              'scope':'source_measurements_only', 'sheets':{}, 'missing':[]}
    for action in plan['actions']:
        name = action['name']
        source = HERE/'sources'/action.get('source_file',name+'.png')
        if not source.exists():
            result['missing'].append(name)
            continue
        image = Image.open(source)
        if image.mode != 'RGBA':
            raise ValueError(f'{name}: expected real RGBA source')
        rgba = np.asarray(image)
        labels, n = ndimage.label(rgba[:,:,3] > 96, structure=np.ones((3,3)))
        counts = ndimage.sum(rgba[:,:,3] > 96, labels, range(1,n+1))
        boxes = []
        for index in np.flatnonzero(counts > 5000):
            ys,xs = np.nonzero(labels == int(index)+1)
            boxes.append([int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1])
        expected = action['target_drawings']
        if len(boxes) != expected:
            raise ValueError(f'{name}: {len(boxes)} separate body silhouettes, expected {expected}')
        columns = expected//2
        regions, ordered = [], []
        for row in range(2):
            y0,y1 = round(row*image.height/2),round((row+1)*image.height/2)
            members = sorted([b for b in boxes if y0 <= (b[1]+b[3])/2 < y1])
            if len(members) != columns or any(b[1] <= y0+3 or b[3] >= y1-3 for b in members):
                raise ValueError(f'{name}: row/body clipping needs manual slicing review')
            boundaries = [0]+[(a[2]+b[0])//2 for a,b in zip(members,members[1:])]+[image.width]
            for index,b in enumerate(members):
                x0,x1 = boundaries[index:index+2]
                if b[0] <= x0+3 or b[2] >= x1-3:
                    raise ValueError(f'{name}: complete figure cannot fit an isolated rectangular cel')
                regions.append([x0,y0,x1-x0,y1-y0])
                ordered.append(b)
        prompt = source.with_suffix('.txt')
        result['sheets'][name] = {'source':'sources/'+source.name,
            'source_sha256':sha256(source.read_bytes()).hexdigest(),
            'prompt_sha256':sha256(prompt.read_bytes()).hexdigest(),
            'image_size':list(image.size), 'regions':regions, 'body_bounds_xyxy':ordered,
            'fully_transparent_fraction':float(np.mean(rgba[:,:,3] == 0))}
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    result = collect()
    text = json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    path = HERE/'source_slices.json'
    if args.check:
        if result['missing'] or not path.exists() or path.read_text(encoding='utf-8') != text:
            raise SystemExit('Source delivery/slicing record is incomplete or stale')
    else:
        path.write_text(text,encoding='utf-8')
    print('HERO_V8_SOURCES sheets=%d poses=%d missing=%d' % (len(result['sheets']),sum(len(s['regions']) for s in result['sheets'].values()),len(result['missing'])))
