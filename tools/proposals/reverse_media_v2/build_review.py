#!/usr/bin/env python3
"""Build an offline review page from the three independent resource manifests.

No runtime assets, controllers, project settings, or game saves are changed.
Python 3.10+, standard library only. Run from any directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct
from urllib.parse import quote
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
PACKS = ("reverse_motion_v2", "reverse_scenery_v2", "reverse_music_v2")
KINDS = {"animation", "layers", "audio"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def positive(value, name: str, maximum: float = 100000) -> float:
    require(type(value) in (int, float) and math.isfinite(value)
            and 0 < value <= maximum, f"Invalid {name}: {value!r}")
    return value


def integer(value, name: str, maximum: int = 10000) -> int:
    positive(value, name, maximum)
    require(type(value) is int, f"{name} must be an integer")
    return value


def resource(pack: Path, raw: str, extensions: set[str]) -> Path:
    require(isinstance(raw, str) and bool(raw) and "\\" not in raw,
            "Asset path must be a nonempty POSIX relative path")
    parts = PurePosixPath(raw)
    require(not parts.is_absolute() and ".." not in parts.parts,
            f"Asset escapes pack: {raw}")
    path = pack / raw
    require(not any(p.is_symlink() for p in [path, *path.parents]),
            f"Symlink asset is not allowed: {raw}")
    require(path.resolve().is_relative_to(pack.resolve()), f"Asset escapes pack: {raw}")
    require(path.suffix.lower() in extensions and path.is_file(), f"Missing/unsupported asset: {raw}")
    require(path.stat().st_size <= 8 * 1024 * 1024, f"Review asset too large: {raw}")
    with path.open("rb") as stream:
        require(not stream.read(128).startswith(b"version https://git-lfs.github.com/spec/"),
                f"Unhydrated LFS pointer: {raw}")
    return path


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        data = stream.read(24)
    require(len(data) == 24 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR",
            f"Not a PNG: {path.name}")
    return struct.unpack(">II", data[16:24])


def check_svg(path: Path) -> None:
    data = path.read_text(encoding="utf-8")
    require("<!DOCTYPE" not in data.upper() and "<!ENTITY" not in data.upper(), "SVG entities are not supported")
    root = ET.fromstring(data)
    require(root.tag.split("}")[-1] == "svg", "Expected SVG root")
    for node in root.iter():
        require(node.tag.split("}")[-1] not in {"script", "foreignObject", "iframe"}, "Active SVG is not allowed")
        for key, value in node.attrib.items():
            name = key.split("}")[-1].lower()
            require(not name.startswith("on"), "SVG event attributes are not allowed")
            if name in {"href", "src"}:
                require(value.startswith("#"), "SVG must not reference external files")
    require(not re.search(r"url\(\s*['\"]?(?!#)[^\s'\")]", data, re.I), "External SVG CSS URL")


def read_pack(root: Path, pack_id: str) -> tuple[dict, list[dict]]:
    pack = root / "assets" / "proposals" / pack_id
    manifest_path = resource(pack, "manifest.json", {".json"})
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(manifest.get("schema_version") == 1 and manifest.get("pack_id") == pack_id,
            f"Unsupported manifest: {pack_id}")
    require(isinstance(manifest.get("title"), str) and isinstance(manifest.get("items"), list)
            and bool(manifest["items"]), f"Empty or invalid pack: {pack_id}")
    files: dict[str, dict] = {}
    seen: set[str] = set()

    def register(raw: str, extensions: set[str]) -> tuple[Path, str]:
        path = resource(pack, raw, extensions)
        relative = path.relative_to(root).as_posix()
        files[relative] = {"path": relative, "bytes": path.stat().st_size,
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        return path, "../../../" + quote(relative, safe="/")

    items = []
    for original in manifest["items"]:
        require(isinstance(original, dict), "Manifest item must be an object")
        item = original.copy()
        item_id = item.get("id")
        require(isinstance(item_id, str) and bool(re.fullmatch(r"[a-z0-9_-]+", item_id)), "Invalid item id")
        require(item_id not in seen, f"Duplicate item id: {item_id}")
        seen.add(item_id)
        require(isinstance(item.get("title"), str) and item.get("type") in KINDS, "Invalid item title/type")
        require(isinstance(item.get("description", ""), str), "Description must be text")
        if item["type"] == "animation":
            path, item["url"] = register(item["file"], {".png"})
            fw, fh = integer(item["frame_width"], "frame width"), integer(item["frame_height"], "frame height")
            count, columns = integer(item["frame_count"], "frame count", 256), integer(item["columns"], "columns", 256)
            require(columns <= count, "Columns exceed frame count")
            positive(item["fps"], "fps", 120)
            require(type(item.get("loop")) is bool, "Animation loop must be boolean")
            require(png_size(path) == (fw * columns, fh * math.ceil(count / columns)), "Atlas dimensions do not match manifest")
            for event in item.get("events", []):
                require(type(event.get("frame")) is int and 0 <= event["frame"] < count
                        and isinstance(event.get("name"), str), "Animation event outside frame range")
        elif item["type"] == "layers":
            integer(item["width"], "scene width")
            integer(item["height"], "scene height")
            require(isinstance(item.get("layers"), list) and len(item["layers"]) >= 2, "Scene needs independent layers")
            item["layers"] = [layer.copy() for layer in item["layers"]]
            layer_ids = set()
            for layer in item["layers"]:
                require(isinstance(layer.get("id"), str) and layer["id"] not in layer_ids, "Duplicate/missing layer id")
                layer_ids.add(layer["id"])
                require(isinstance(layer.get("title"), str), "Layer title must be text")
                parallax = layer.get("parallax", 0)
                require(type(parallax) in (int, float) and math.isfinite(parallax) and 0 <= parallax <= 1,
                        "Parallax must be 0..1")
                path, layer["url"] = register(layer["file"], {".svg", ".png"})
                if path.suffix.lower() == ".svg":
                    check_svg(path)
            if item.get("preview"):
                _, item["preview_url"] = register(item["preview"], {".png"})
        else:
            path, item["url"] = register(item["file"], {".ogg"})
            with path.open("rb") as stream:
                require(stream.read(4) == b"OggS", "Expected an OGG stream")
            positive(item["duration_seconds"], "duration", 600)
            positive(item["bpm"], "bpm", 300)
            require(item.get("role") in {"exploration", "boss"} and type(item.get("loop")) is bool,
                    "Invalid music role/loop")
        item["pack_id"] = pack_id
        items.append(item)
    register("manifest.json", {".json"})
    return {"id": pack_id, "title": manifest["title"], "items": items}, list(files.values())


def build(root: Path = ROOT) -> dict:
    packs, files = [], []
    for pack_id in PACKS:
        pack, records = read_pack(root, pack_id)
        packs.append(pack)
        files.extend(records)
    data = {"schema_version": 1, "status": "candidate_not_integrated", "packs": packs}
    target = root / "docs" / "proposals" / "reverse_media_v2"
    target.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
    # Safe both as an external JS file and if later embedded in HTML.
    payload = payload.replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    (target / "catalog.js").write_text("window.MEDIA_CATALOG = " + payload + ";\n", encoding="utf-8")
    report = {"pack_count": len(packs), "item_count": sum(len(p["items"]) for p in packs),
              "files": sorted(files, key=lambda f: f["path"]),
              "checks": ["schema", "unique ids", "pack-local files", "no LFS pointers", "atlas dimensions",
                         "animation event bounds", "passive SVG", "OGG container signature", "SHA256"],
              "not_covered": ["natural gameplay", "subjective listening", "game integration", "codec waveform analysis"]}
    (target / "catalog_validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        result = build(args.root.resolve())
    except (ValueError, KeyError, OSError, json.JSONDecodeError, ET.ParseError) as error:
        parser.exit(1, f"Media review build failed: {error}\n")
    print(json.dumps({"packs": result["pack_count"], "items": result["item_count"], "files": len(result["files"])}, ensure_ascii=False))
