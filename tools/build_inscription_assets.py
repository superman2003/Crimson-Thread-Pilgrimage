#!/usr/bin/env python3
"""Build the game's redistributable serif subset and outlined inscription marks.

Source: notofonts/noto-cjk, Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf.
Pass the upstream OTF as the first argument. fontTools is required. The subset
keeps the upstream outlines; the project lettering adds vector cuts and thread.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

from fontTools import subset
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot/assets/ui/inscription"
FONT_OUT = ROOT / "godot/assets/fonts/PilgrimageSerif.otf"
WORDS = {"pilgrimage": "绯线巡礼", "seal": "契印", "inventory": "行囊",
         "journal": "旅记", "map": "地图", "settings": "设定"}


def wordmark(font: TTFont, word: str) -> str:
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    width = 34 + len(word) * 210
    elements = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="236" viewBox="0 0 {width} 236">',
                '<defs><linearGradient id="bone" x2="0.25" y2="1"><stop stop-color="#b69a73"/><stop offset="0.4" stop-color="#e0cdb0"/><stop offset="1" stop-color="#f2e2c5"/></linearGradient></defs>']
    for index, char in enumerate(word):
        pen = SVGPathPen(glyphs)
        glyphs[cmap[ord(char)]].draw(pen)
        x = 19 + index * 210
        elements.append(f'<path d="{pen.getCommands()}" transform="translate({x},190) scale(.196,-.196)" fill="url(#bone)"/>')
        # Incised diagonals and bronze-rimmed eyelets, drawn in the UI ink.
        cut_x = x + (112 if index % 2 == 0 else 73)
        elements.append(f'<path d="M{cut_x-19} 164 l40 -15 -32 22 Z" fill="#0a191b"/>')
        elements.append(f'<circle cx="{cut_x}" cy="168" r="4.6" fill="#071416" stroke="#af8b60" stroke-width="1.2"/>')
    # Red thread passes through every eyelet; smaller headings use the same mark.
    holes = [(19 + i * 210 + (112 if i % 2 == 0 else 73), 168) for i in range(len(word))]
    path = f'M7 181 Q45 199 {holes[0][0]} 168'
    for (x1, _), (x2, _) in zip(holes, holes[1:]):
        path += f' C{x1+43} 206 {x2-50} 137 {x2} 168'
    path += f' Q{width-18} 196 {width-8} 153'
    elements.append(f'<path d="{path}" fill="none" stroke="#6a2226" stroke-width="4.2"/>')
    elements.append(f'<path d="{path}" fill="none" stroke="#c9514c" stroke-width="1.7"/>')
    elements.append('</svg>')
    return '\n'.join(elements)


def main() -> None:
    source = Path(sys.argv[1])
    font = TTFont(source, recalcTimestamp=False)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, word in WORDS.items():
        (OUT / f"{name}.svg").write_text(wordmark(font, word), encoding="utf-8")
    # Text content from runtime sources, plus Latin, numerals, and punctuation.
    # Font fallback in Godot covers characters introduced by future content.
    chars = set(chr(value) for value in range(32, 127))
    chars.update(''.join(WORDS.values()))
    for folder, directories, files in os.walk(ROOT / "godot"):
        directories[:]=[name for name in directories if name not in (".godot","addons")]
        for name in files:
            path=Path(folder)/name
            if path.suffix in (".gd",".json",".tscn"):
                chars.update(path.read_text(encoding="utf-8-sig", errors="replace"))
    options = subset.Options()
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    options.name_legacy = True
    options.name_languages = [0x409]
    options.recalc_timestamp = False
    job = subset.Subsetter(options=options)
    job.populate(unicodes=[ord(c) for c in chars])
    job.subset(font)
    for entry in font["name"].names:
        names = {1: "Pilgrimage Serif", 2: "Regular", 3: "PilgrimageSerif-Regular-1.0",
                 4: "Pilgrimage Serif Regular", 6: "PilgrimageSerif-Regular"}
        if entry.nameID in names:
            entry.string = names[entry.nameID].encode(entry.getEncoding())
    if "CFF " in font:
        cff = font["CFF "].cff
        cff.fontNames = ["PilgrimageSerif-Regular"]
        cff.topDictIndex[0].FamilyName = "Pilgrimage Serif"
        cff.topDictIndex[0].FullName = "Pilgrimage Serif Regular"
    font.save(FONT_OUT)
    manifest = {"upstream": "https://github.com/notofonts/noto-cjk/blob/main/Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf",
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "font": "PilgrimageSerif.otf", "license": "SIL OFL 1.1",
                "glyphs": len(font.getBestCmap()), "wordmarks": WORDS,
                "note": "Renamed serif subset with unchanged source outlines; project lettering adds cuts, eyelets, and red thread in SVG."}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding="utf-8")
    print(f'Built {len(WORDS)} vector marks; {manifest["glyphs"]} serif characters, {FONT_OUT.stat().st_size:,} bytes')


if __name__ == "__main__":
    main()
