#!/usr/bin/env python3
"""Build a real, reusable needle-inscribed OpenType font from the OFL serif.

Preserves the source Beziers, metrics and counters. Broad strokes receive one
small diagonal triangular incision; tiny punctuation is left intact. No images
are involved, and every existing game character remains searchable/editable.
"""
from __future__ import annotations
import json
from pathlib import Path
from fontTools.pens.basePen import BasePen
from fontTools.pens.areaPen import AreaPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]

class Outline(BasePen):
    def __init__(self, glyphs):
        super().__init__(glyphs)
        self.contours = []
        self.points = []
    def _moveTo(self, p): self.points = [p]
    def _lineTo(self, p): self.points.append(p)
    def _curveToOne(self, a, b, c):
        p = self.points[-1]
        for i in range(1, 13):
            t = i / 12
            u = 1 - t
            self.points.append(tuple(u*u*u*p[j]+3*u*u*t*a[j]+3*u*t*t*b[j]+t*t*t*c[j] for j in (0,1)))
    def _closePath(self):
        self.contours.append(self.points)
        self.points=[]
    _endPath = _closePath
    def contains(self, x, y):
        winding=0
        for contour in self.contours:
            if len(contour)<3: continue
            for a,b in zip(contour,contour[1:]+contour[:1]):
                cross=(b[0]-a[0])*(y-a[1])-(x-a[0])*(b[1]-a[1])
                if a[1]<=y<b[1] and cross>0:winding+=1
                if b[1]<=y<a[1] and cross<0:winding-=1
        return winding!=0

def incision(outline, seed):
    for y in [330+(seed%5)*39,570-(seed%3)*45,220]:
        spans=[]
        start=None
        for x in range(50,951,5):
            inside=outline.contains(x,y)
            if inside and start is None:start=x
            if not inside and start is not None:
                if x-start>=35:spans.append((start,x))
                start=None
        for a,b in spans[seed%max(1,len(spans)):]+spans[:seed%max(1,len(spans))]:
            x=(a+b)*.5
            triangle=[(x-9,y-12),(x+11,y+13),(x-5,y-12)]
            # An entirely internal counter cannot spill into the surrounding ink.
            if all(outline.contains(px,py) for px,py in triangle):return triangle
    return None

def main():
    source=ROOT/'godot/assets/fonts/PilgrimageSerif.otf'
    output=ROOT/'godot/assets/fonts/FengMingInscription.otf'
    font=TTFont(source,recalcTimestamp=False)
    glyphs=font.getGlyphSet()
    cff=font['CFF '].cff
    table=cff.topDictIndex[0]
    edited=0
    for code,name in font.getBestCmap().items():
        if code<0x2e80 or code>0x9fff:continue
        trace=Outline(glyphs)
        glyphs[name].draw(trace)
        cut=incision(trace,code)
        if cut is None:continue
        original=table.CharStrings[name]
        width=font['hmtx'][name][0]
        private=original.private
        operand=None if width==getattr(private,'defaultWidthX',0) else width-getattr(private,'nominalWidthX',0)
        pen=T2CharStringPen(operand,glyphs)
        shape=TransformPen(pen,(1,0,.018,1,0,0))
        glyphs[name].draw(shape)
        area=AreaPen(glyphs)
        glyphs[name].draw(area)
        # CFF counters wind opposite to the outer ink contours.
        if area.value<0:cut.reverse()
        shape.moveTo(cut[0])
        for point in cut[1:]:shape.lineTo(point)
        shape.closePath()
        table.CharStrings[name]=pen.getCharString(private,cff.GlobalSubrs)
        edited+=1
    names={1:'Feng Ming Inscription',2:'Regular',3:'FengMingInscription-Regular-2.0',4:'Feng Ming Inscription Regular',6:'FengMingInscription-Regular'}
    for item in font['name'].names:
        if item.nameID in names:item.string=names[item.nameID].encode(item.getEncoding())
    cff.fontNames=['FengMingInscription-Regular']
    table.FamilyName='Feng Ming Inscription'
    table.FullName='Feng Ming Inscription Regular'
    font.save(output)
    manifest={'name':'缝名刻宋 / Feng Ming Inscription','source':'PilgrimageSerif.otf (Noto Serif CJK SC derivative)',
              'license':'SIL OFL 1.1','characters':len(font.getBestCmap()),'inscribed_characters':edited,
              'note':'Real OpenType font: original Beziers plus restrained diagonal counters; raster lettering remains decorative artwork.'}
    output.with_suffix('.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Built {output.name}: {edited} incised Chinese characters; {len(font.getBestCmap())} supported characters')

if __name__=='__main__':main()
