from __future__ import annotations

import json
import os
from collections import Counter
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(os.environ.get("CRIMSON_ASSET_OUT", r"D:\CrimsonThreadOdysseyAssets"))
REPORT_PATH = ROOT / "validation" / "reports" / "asset-validation-report.json"


def main() -> None:
    manifest_path = ROOT / "00_manifest" / "asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    items: list[dict[str, Any]] = manifest["items"]

    missing: list[str] = []
    bad_png: list[dict[str, str]] = []
    wrong_size: list[dict[str, Any]] = []
    categories: Counter[str] = Counter()
    png_count = 0

    for item in items:
        path = Path(item["path"])
        categories[item["category"]] += 1
        if not path.exists():
            missing.append(str(path))
            continue
        if path.suffix.lower() != ".png":
            continue
        png_count += 1
        try:
            with Image.open(path) as img:
                img.verify()
            with Image.open(path) as img:
                expected = item.get("size")
                if expected and expected != [0, 0] and [img.width, img.height] != expected:
                    wrong_size.append({
                        "path": str(path),
                        "expected": expected,
                        "actual": [img.width, img.height],
                    })
        except Exception as exc:  # pragma: no cover - diagnostic path
            bad_png.append({"path": str(path), "error": str(exc)})

    all_files = [path for path in ROOT.rglob("*") if path.is_file()]
    report = {
        "status": "PASS" if not missing and not bad_png and not wrong_size and png_count >= 110 else "FAIL",
        "root": str(ROOT),
        "manifest_count": manifest["count"],
        "manifest_items": len(items),
        "total_files": len(all_files),
        "png_count": png_count,
        "categories": dict(sorted(categories.items())),
        "missing": missing,
        "bad_png": bad_png,
        "wrong_size": wrong_size,
        "checks": {
            "manifest_count_matches_items": manifest["count"] == len(items),
            "minimum_png_110": png_count >= 110,
            "all_paths_exist": not missing,
            "all_png_open": not bad_png,
            "dimensions_match_manifest": not wrong_size,
            "all_manifest_paths_on_d_drive": all(str(item["path"]).upper().startswith("D:\\") for item in items),
        },
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if report["status"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
