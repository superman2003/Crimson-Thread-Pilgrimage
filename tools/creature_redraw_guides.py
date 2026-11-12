"""Render reproducible pose references for checklist frame redraws, not final art.

The recipe freezes the current frame-fit scale/pivot used only in the reference.
Final poses must be redrawn by image_gen; this tool never writes runtime assets.
"""
import argparse
from hashlib import sha256
import math
from pathlib import Path
import statistics
import numpy as np
from PIL import Image
import creature_redraw_art as art


def digest(path):
    return sha256(Path(path).read_bytes()).hexdigest()


def reference_pose(recipe, entry, cache):
    drawing, (x,y) = art.source_drawing(entry['source_frame'], cache)
    width,height = recipe['canvas']
    scale,px,py = entry['reference_fit']
    pivot=(width/2+px,height/2+py)
    if scale != 1:
        drawing=drawing.resize((round(drawing.width*scale),round(drawing.height*scale)),Image.Resampling.LANCZOS)
        x=round(pivot[0]+(x-pivot[0])*scale)
        y=round(pivot[1]+(y-pivot[1])*scale)
    canvas=Image.new('RGBA',(width,height))
    canvas.alpha_composite(drawing,(x,y))
    return canvas


def render(recipe, output):
    baseline=art.ROOT/recipe['baseline']
    if digest(baseline) != recipe['baseline_sha256']:
        raise ValueError('Reference baseline changed')
    for atlas,expected in recipe['atlas_sha256'].items():
        if digest(art.ROOT/'godot'/atlas.removeprefix('res://')) != expected:
            raise ValueError('Reference atlas changed: '+atlas)
    cols,rows=recipe['grid']
    board=Image.new('RGBA',(cols*256,rows*256)); cache={}; heights=[]
    scale=min(210/recipe['canvas'][0],214/recipe['canvas'][1])
    size=tuple(round(v*scale) for v in recipe['canvas'])
    for i,entry in enumerate(recipe['entries']):
        pose=reference_pose(recipe,entry,cache)
        ys,xs=np.nonzero(np.asarray(pose.getchannel('A'))>128)
        if not len(xs): raise ValueError('Empty reference')
        heights.append(int(ys.max()-ys.min()+1))
        pose=pose.resize(size,Image.Resampling.LANCZOS)
        board.alpha_composite(pose,(i%cols*256+(256-pose.width)//2,i//cols*256+(256-pose.height)//2))
    output=Path(output); output.parent.mkdir(parents=True,exist_ok=True); board.save(output)
    return statistics.median(heights)


def prepare(kind,out,max_cells=32):
    baseline,manifest=art.baseline(kind)
    folder=art.fit.CREATURES/kind
    table=art.read(folder/'frame_fit.json')
    active=folder/table['manifest']
    if digest(active) != table['manifest_sha256']:
        raise ValueError('Measure current production before preparing references')
    clips={c['name']:c for c in manifest['animations']}
    progress=art.read(art.REQUEST/'progress.json')
    groups=[]
    for row in progress['items']:
        if row['kind'] != kind or row['status']=='redrawn': continue
        name=row['clip']; clip=clips[name]
        required=art.required_frames(kind,name)
        targets=sorted({j for i in required for j in (i-1,i,i+1) if 0<=j<len(clip['frames'])})
        if len(targets)>max_cells: raise ValueError('One clip exceeds sheet limit')
        groups.append((name,targets))
    batches=[]; current=[]; used=0
    for group in groups:
        if used+len(group[1])>max_cells:
            batches.append(current);current=[];used=0
        current.append(group);used+=len(group[1])
    if current:batches.append(current)
    results=[]
    for part,groups in enumerate(batches,1):
        count=sum(len(targets) for _,targets in groups)
        cols=8 if count>16 else 4; rows=math.ceil(count/cols)
        recipe=dict(schema=1,kind=kind,baseline=baseline.relative_to(art.ROOT).as_posix(),
                    baseline_sha256=digest(baseline),canvas=manifest['canvas'],grid=[cols,rows],
                    frame_fit_reference_sha256=digest(folder/'frame_fit.json'),
                    explanation='Reference only: frozen production scale about canvas-centred pivot; final poses are authored with image_gen',
                    atlas_sha256={},entries=[],targets={},original_frame_counts={})
        for name,targets in groups:
            recipe['targets'][name]=targets;recipe['original_frame_counts'][name]=len(clips[name]['frames'])
            fits=table['frames'].get(name,[[1,0,0]]*len(clips[name]['frames']))
            for index in targets:
                frame=clips[name]['frames'][index]
                recipe['entries'].append(dict(clip=name,frame=index,source_frame=frame,reference_fit=fits[index]))
                atlas=frame['atlas']
                recipe['atlas_sha256'][atlas]=digest(art.ROOT/'godot'/atlas.removeprefix('res://'))
        stem=f'{kind}-actions-{part:02}'
        image=Path(out)/(stem+'.png')
        recipe['reference_height']=render(recipe,image)
        recipe['reference_sha256']=digest(image)
        path=art.REQUEST/'guides'/(stem+'.json');art.write(path,recipe)
        results.append(dict(kind=kind,part=part,recipe=path.relative_to(art.ROOT).as_posix(),ref=image.resolve().as_posix(),
                            source_name=f'actions_{part:02}',count=count,grid=recipe['grid'],targets=recipe['targets']))
    return results


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    choice=parser.add_mutually_exclusive_group(required=True)
    choice.add_argument('--kind');choice.add_argument('--recipe',type=Path)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    if args.recipe:
        render(art.read(args.recipe),args.out)
        print('GUIDE_RENDERED',args.out)
    else:
        results=prepare(args.kind,args.out)
        art.write(args.out/(args.kind+'-actions.json'),results)
        print('GUIDES',[(r['part'],r['count'],list(r['targets'])) for r in results])


if __name__=='__main__':main()
