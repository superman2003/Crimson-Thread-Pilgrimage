from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "artifacts" / "map_blueprints" / "silksong_scale"
INDEX_PATH = OUT_DIR / "map_blueprint_index.json"


def fail(message: str) -> None:
    raise SystemExit(f"验证失败：{message}")


def load_json(path: Path) -> Any:
    if not path.exists():
        fail(f"缺少 JSON：{path}")
    return json.loads(path.read_text(encoding="utf-8"))


def image_stats(path: Path) -> dict[str, Any]:
    if not path.exists():
        fail(f"缺少 PNG：{path}")
    with Image.open(path) as img:
        rgb = img.convert("RGB")
        w, h = rgb.size
        bg = rgb.getpixel((0, 0))
        sample_step = max(1, min(w, h) // 600)
        sampled = 0
        non_bg = 0
        for y in range(0, h, sample_step):
            for x in range(0, w, sample_step):
                sampled += 1
                if rgb.getpixel((x, y)) != bg:
                    non_bg += 1
        return {"width": w, "height": h, "non_bg_ratio": non_bg / max(1, sampled)}


def validate_layout_naturalness(chapter_id: str, rooms: list[dict[str, Any]], clusters: list[dict[str, Any]]) -> dict[str, Any]:
    x_buckets = {round(float(room["rect"]["x"]) / 180.0) * 180 for room in rooms}
    y_buckets = {round(float(room["rect"]["y"]) / 180.0) * 180 for room in rooms}
    if len(x_buckets) < len(rooms) * 0.42:
        fail(f"{chapter_id} layout x variety too low: {len(x_buckets)} buckets for {len(rooms)} rooms")
    if len(y_buckets) < 6:
        fail(f"{chapter_id} layout y variety too low: {len(y_buckets)} buckets")
    wide_clusters = 0
    tall_clusters = 0
    for cluster in clusters:
        bounds = cluster.get("bounds", {})
        width = float(bounds.get("w", 0))
        height = float(bounds.get("h", 0))
        if width <= 0 or height <= 0:
            fail(f"{chapter_id} invalid cluster bounds: {cluster.get('id')}")
        if width / height >= 1.15:
            wide_clusters += 1
        if height / width >= 1.15:
            tall_clusters += 1
    if wide_clusters < 3:
        fail(f"{chapter_id} needs at least 3 wide clusters, got {wide_clusters}")
    if tall_clusters < 2:
        fail(f"{chapter_id} needs at least 2 tall clusters, got {tall_clusters}")
    return {"x_buckets": len(x_buckets), "y_buckets": len(y_buckets), "wide_clusters": wide_clusters, "tall_clusters": tall_clusters}


def validate_chapter(chapter_id: str, item: dict[str, Any]) -> dict[str, Any]:
    json_path = Path(item["json"])
    png_path = Path(item["png"])
    bp = load_json(json_path)
    stats = image_stats(png_path)
    rooms = bp.get("rooms", [])
    clusters = bp.get("clusters", [])
    points = bp.get("points", {})
    connections = bp.get("connections", {})
    placements = bp.get("placements", [])
    palette = bp.get("palette")
    legend = bp.get("legend")

    if len(rooms) < 55:
        fail(f"{chapter_id} 房间数不足：{len(rooms)} < 55")
    if len(rooms) > 75:
        fail(f"{chapter_id} 房间数超出目标上限：{len(rooms)} > 75")
    if len(clusters) < 8:
        fail(f"{chapter_id} 区域簇不足：{len(clusters)} < 8")
    if len(connections.get("main_route", [])) < 27:
        fail(f"{chapter_id} 主线连接不足")
    if len(connections.get("shortcuts", [])) < 5:
        fail(f"{chapter_id} 捷径不足")
    if len(connections.get("ability_gates", [])) < 5:
        fail(f"{chapter_id} 能力门不足")
    if len(points.get("saves", [])) < 5:
        fail(f"{chapter_id} 存档点不足")
    if len(points.get("npcs", [])) < 5:
        fail(f"{chapter_id} NPC 不足")
    if len(points.get("rewards", [])) < 8:
        fail(f"{chapter_id} 奖励点不足")
    if len(points.get("minibosses", [])) < 2:
        fail(f"{chapter_id} 精英战不足")
    if len(points.get("bosses", [])) != 1:
        fail(f"{chapter_id} Boss 数量必须为 1")
    if not placements:
        fail(f"{chapter_id} 缺少 placements 平铺点位")
    if not palette or not legend:
        fail(f"{chapter_id} 缺少 palette 或 legend")

    layout_stats = validate_layout_naturalness(chapter_id, rooms, clusters)
    room_by_id = {room["id"]: room for room in rooms}
    for room in rooms:
        for key in ["id", "name", "chapter", "rect", "role", "intensity", "exits", "placements"]:
            if key not in room:
                fail(f"{chapter_id} 房间 {room.get('id')} 缺字段 {key}")
        micro = room.get("micro_layout")
        if not micro:
            fail(f"{chapter_id} 房间 {room.get('id')} 缺少 micro_layout")
        for key in ["doors", "platforms", "hazards", "enemies", "pickups", "design_note"]:
            if key not in micro:
                fail(f"{chapter_id} 房间 {room.get('id')} micro_layout 缺字段 {key}")
        if not micro["doors"]:
            fail(f"{chapter_id} 房间 {room.get('id')} 缺少门位")
        if not micro["platforms"]:
            fail(f"{chapter_id} 房间 {room.get('id')} 缺少平台")
    for placement in placements:
        for key in ["type", "kind", "x", "y", "label", "visible_on_map", "room"]:
            if key not in placement:
                fail(f"{chapter_id} 点位缺字段 {key}")
        if placement["room"] not in room_by_id:
            fail(f"{chapter_id} 点位引用不存在房间：{placement['room']}")

    boss_room = points["bosses"][0]["room"]
    boss_index = room_by_id[boss_room]["index"]
    save_indices = [room_by_id[p["room"]]["index"] for p in points["saves"]]
    if min(abs(boss_index - idx) for idx in save_indices) > 3:
        fail(f"{chapter_id} Boss 前 3 房间内没有存档点")

    if stats["width"] < 10000 or stats["height"] < 6000:
        fail(f"{chapter_id} PNG 尺寸不足：{stats['width']}x{stats['height']}")
    if stats["non_bg_ratio"] < 0.08:
        fail(f"{chapter_id} PNG 非背景覆盖率过低：{stats['non_bg_ratio']:.3f}")

    detail_path_value = item.get("detail_sheet_png")
    if not detail_path_value:
        fail(f"{chapter_id} 索引缺少 detail_sheet_png")
    detail_stats = image_stats(Path(detail_path_value))
    if detail_stats["width"] < 9000 or detail_stats["height"] < 4000:
        fail(f"{chapter_id} 房间细节图册尺寸不足：{detail_stats['width']}x{detail_stats['height']}")
    if detail_stats["non_bg_ratio"] < 0.08:
        fail(f"{chapter_id} 房间细节图册非背景覆盖率过低：{detail_stats['non_bg_ratio']:.3f}")

    return {
        "chapter": chapter_id,
        "rooms": len(rooms),
        "clusters": len(clusters),
        "shortcuts": len(connections.get("shortcuts", [])),
        "ability_gates": len(connections.get("ability_gates", [])),
        "saves": len(points.get("saves", [])),
        "npcs": len(points.get("npcs", [])),
        "rewards": len(points.get("rewards", [])),
        "png": f"{stats['width']}x{stats['height']}",
        "non_bg_ratio": round(stats["non_bg_ratio"], 3),
        "detail_sheet": f"{detail_stats['width']}x{detail_stats['height']}",
        "detail_non_bg_ratio": round(detail_stats["non_bg_ratio"], 3),
        "layout": layout_stats,
    }


def main() -> None:
    index = load_json(INDEX_PATH)
    chapters = index.get("chapters", {})
    if len(chapters) != 6:
        fail(f"索引章节数量不是 6：{len(chapters)}")
    overview = Path(index.get("overview_png", ""))
    overview_stats = image_stats(overview)
    if overview_stats["width"] < 7680 or overview_stats["height"] < 4320:
        fail(f"总览图尺寸不足：{overview_stats['width']}x{overview_stats['height']}")
    if overview_stats["non_bg_ratio"] < 0.08:
        fail(f"总览图非背景覆盖率过低：{overview_stats['non_bg_ratio']:.3f}")

    results = [validate_chapter(chapter_id, item) for chapter_id, item in sorted(chapters.items())]
    print(json.dumps({"ok": True, "overview": overview_stats, "chapters": results}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
