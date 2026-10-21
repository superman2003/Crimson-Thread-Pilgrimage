#!/usr/bin/env python3
"""Build a real, reusable needle-inscribed OpenType font from the OFL serif.

Preserves the source Beziers, metrics and counters. Broad strokes receive one
small diagonal triangular incision; tiny punctuation is left intact. No images
are involved, and every existing game character remains searchable/editable.
"""
from __future__ import annotations
import json
import hashlib
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
    def spans(self, y):
        crossings=[]
        for contour in self.contours:
            for a,b in zip(contour,contour[1:]+contour[:1]):
                if a[1]<=y<b[1] or b[1]<=y<a[1]:
                    crossings.append((a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]),1 if b[1]>a[1] else -1))
        winding=0
        start=None
        result=[]
        for x,direction in sorted(crossings):
            previous=winding
            winding+=direction
            if previous==0 and winding!=0:start=x
            elif previous!=0 and winding==0 and x-start>=35:result.append((start,x))
        return result

def incision(outline, seed):
    for y in [330+(seed%5)*39,570-(seed%3)*45,220]:
        spans=outline.spans(y)
        for a,b in spans[seed%max(1,len(spans)):]+spans[:seed%max(1,len(spans))]:
            x=(a+b)*.5
            triangle=[(x-9,y-12),(x+11,y+13),(x-5,y-12)]
            # An entirely internal counter cannot spill into the surrounding ink.
            if all(outline.contains(px,py) for px,py in triangle):return triangle
    return None

def unicode_ranges(codepoints):
    ranges=[]
    for code in sorted(codepoints):
        if ranges and code==ranges[-1][1]+1:ranges[-1][1]=code
        else:ranges.append([code,code])
    return ranges

def add_ui_symbols(font):
    """Three native monochrome symbols absent from Noto Serif CJK.

    Keep map return/closed-route markers and the lock in this same font instead
    of depending on OS emoji or other installed fonts.
    """
    cff=font['CFF '].cff
    table=cff.topDictIndex[0]
    order=font.getGlyphOrder()
    names=set(order)
    private=table.FDArray[0].Private
    for code in (0x21a9,0x22a3,0x1f512):
        if code in font.getBestCmap():continue
        cid=next(value for value in range(1,65536) if f'cid{value:05d}' not in names)
        name=f'cid{cid:05d}'
        pen=T2CharStringPen(1000-getattr(private,'nominalWidthX',0),None)
        def polygon(points):
            pen.moveTo(points[0])
            for point in points[1:]:pen.lineTo(point)
            pen.closePath()
        def rectangle(x,y,w,h,reverse=False):
            points=[(x,y),(x+w,y),(x+w,y+h),(x,y+h)]
            polygon(points[::-1] if reverse else points)
        if code==0x21a9:
            polygon([(120,360),(350,590),(350,430),(720,430),(720,700),(790,700),(790,360),(350,360),(350,200)])
        elif code==0x22a3:
            rectangle(700,100,65,650)
            rectangle(200,390,500,65)
        else:
            rectangle(250,80,500,360)
            rectangle(320,150,360,220,True)
            pen.moveTo((330,440));pen.lineTo((330,620))
            pen.curveTo((330,850),(670,850),(670,620));pen.lineTo((670,440));pen.lineTo((610,440));pen.lineTo((610,620))
            pen.curveTo((610,765),(390,765),(390,620));pen.lineTo((390,440));pen.closePath()
        charstring=pen.getCharString(private,cff.GlobalSubrs)
        table.CharStrings.charStrings[name]=len(table.CharStrings.charStringsIndex)
        table.CharStrings.charStringsIndex.append(charstring)
        table.charset.append(name)
        table.FDSelect.gidArray.append(0)
        order.append(name)
        names.add(name)
        font['hmtx'].metrics[name]=(1000,0)
        if 'vmtx' in font:font['vmtx'].metrics[name]=(1000,880)
        for cmap in font['cmap'].tables:
            if cmap.isUnicode() and (cmap.format==12 or cmap.format==4 and code<=0xffff):cmap.cmap[code]=name
    font.setGlyphOrder(order)
    font['maxp'].numGlyphs=len(order)

def main():
    source=ROOT/'tmp/inscription/PilgrimageSerif.otf'
    output=ROOT/'tools/font_assets/FengMingInscription.otf'
    font=TTFont(source,recalcTimestamp=False)
    source_codepoints=set(font.getBestCmap())
    add_ui_symbols(font)
    glyphs=font.getGlyphSet()
    cff=font['CFF '].cff
    table=cff.topDictIndex[0]
    edited=0
    processed=set()
    for code,name in font.getBestCmap().items():
        if not (0x2e80<=code<=0x9fff or 0x20000<=code<=0x323af) or name in processed:continue
        processed.add(name)
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
    names={1:'Feng Ming Inscription',2:'Regular',3:'FengMingInscription-Regular-3.0',4:'Feng Ming Inscription Regular',6:'FengMingInscription-Regular'}
    for item in font['name'].names:
        if item.nameID in names:item.string=names[item.nameID].encode(item.getEncoding())
    cff.fontNames=['FengMingInscription-Regular']
    table.FamilyName='Feng Ming Inscription'
    table.FullName='Feng Ming Inscription Regular'
    output.parent.mkdir(parents=True,exist_ok=True)
    font.save(output)
    assert source_codepoints <= set(TTFont(output).getBestCmap()), 'A full Unicode font is required'
    manifest={'name':'缝名刻宋 / Feng Ming Inscription','source':'Full Noto Serif CJK SC Unicode repertoire (via tmp/inscription/PilgrimageSerif.otf)',
              'license':'SIL OFL 1.1','characters':len(font.getBestCmap()),'inscribed_characters':edited,
              'upstream_characters':len(source_codepoints),'required_unicode_ranges':unicode_ranges(font.getBestCmap()),
              'font_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
              'note':'Real OpenType font: original Beziers plus restrained diagonal counters; raster lettering remains decorative artwork.'}
    (ROOT/'godot/assets/fonts/FengMingInscription.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Built {output.name}: {edited} incised Chinese characters; {len(font.getBestCmap())} supported characters')

if __name__=='__main__':main()
