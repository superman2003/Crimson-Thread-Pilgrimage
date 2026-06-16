from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

from PIL import Image


ROOT = Path(r"D:\CrimsonThreadOdysseyAssets_v2")
MANIFEST_DIR = ROOT / "00_manifest"
REPORT_DIR = ROOT / "validation" / "reports"


def main() -> None:
    MANIFEST_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    items = []
    for path in sorted(ROOT.rglob("*.png")):
        if "00_manifest" in path.parts or "validation" in path.parts:
            continue
        with Image.open(path) as img:
            items.append({
                "id": path.stem,
                "category": path.parent.name,
                "path": str(path),
                "size": [img.width, img.height],
                "bytes": path.stat().st_size,
                "source": "built-in image generation fallback; game-studio plugin unavailable in this session",
            })

    categories = Counter(item["category"] for item in items)
    manifest = {
        "version": "20260615_v2_painted_restart",
        "root": str(ROOT),
        "note": "v2 是推倒重来的具象美术素材包；旧的程序化抽象包不作为最终使用对象。",
        "count": len(items),
        "categories": dict(sorted(categories.items())),
        "items": items,
    }
    (MANIFEST_DIR / "asset_manifest_v2.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    report = validate(items)
    (REPORT_DIR / "asset-validation-report-v2.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if report["status"] != "PASS":
        raise SystemExit(1)


def validate(items: list[dict]) -> dict:
    bad = []
    missing = []
    for item in items:
        path = Path(item["path"])
        if not path.exists():
            missing.append(str(path))
            continue
        try:
            with Image.open(path) as img:
                img.verify()
            with Image.open(path) as img:
                if [img.width, img.height] != item["size"]:
                    bad.append({"path": str(path), "reason": "size mismatch"})
        except Exception as exc:
            bad.append({"path": str(path), "reason": str(exc)})
    return {
        "status": "PASS" if items and not missing and not bad else "FAIL",
        "root": str(ROOT),
        "asset_count": len(items),
        "missing": missing,
        "bad": bad,
        "checks": {
            "all_paths_on_d_drive": all(str(item["path"]).upper().startswith("D:\\") for item in items),
            "all_png_open": not bad,
            "all_paths_exist": not missing,
            "minimum_v2_asset_count_50": len(items) >= 50,
        },
    }


if __name__ == "__main__":
    main()
