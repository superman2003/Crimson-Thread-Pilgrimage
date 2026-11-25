# 当前正式关卡实机（2026-11-25）

26 张截图取自 Godot 4.6.1 的正式 `World.tscn`，使用 Compatibility 渲染器和 1280 × 720 的独立展示档。11 月 25 日更新了后门升梯井、水窖深廊、溢洪道和高位水塔路线。六处路线取景均使用经过关卡回归的落点。

## 路线

![中央钟庭的实体石坡与升降笼前落台](../../artifacts/readme_current_20261123/central_court.webp)

![铸雨渠从检修缝到泵房的两段坡](../../artifacts/readme_current_20261123/rain_service_ramp.webp)

![后门升梯井左右错开的实体踏台](../../artifacts/readme_current_20261123/court_stairwell.webp)

![水窖深廊的侧跳回程与冲刺门](../../artifacts/readme_current_20261123/cistern_return.webp)

![铸雨渠溢洪道两侧的实体落台](../../artifacts/readme_current_20261123/rain_spillway.webp)

![高位水塔侧踏台、观景廊与门后落点](../../artifacts/readme_current_20261123/high_water_tower.webp)

## 界面和工房

![World 场景与 HUD](../../artifacts/readme_current_20261123/world_hud.webp)

![分类行囊](../../artifacts/readme_current_20261123/inventory.webp)

![旅记](../../artifacts/readme_current_20261123/journal.webp)

![契印](../../artifacts/readme_current_20261123/seal.webp)

![线技](../../artifacts/readme_current_20261123/skills.webp)

![战具与付费补给](../../artifacts/readme_current_20261123/tools.webp)

![战斗铭饰](../../artifacts/readme_current_20261123/combat_accessory.webp)

![行旅铭饰](../../artifacts/readme_current_20261123/travel_accessory.webp)

![构筑方案](../../artifacts/readme_current_20261123/loadout.webp)

![区域地图](../../artifacts/readme_current_20261123/map.webp)

![世界地图](../../artifacts/readme_current_20261123/world_map.webp)

![设定](../../artifacts/readme_current_20261123/settings.webp)

![能力练习工房](../../artifacts/readme_current_20261123/practice.webp)

![线技施放](../../artifacts/readme_current_20261123/skill_action.webp)

## 六区起点

![苔钟庭起点](../../artifacts/readme_current_20261123/region_ch01_moss_bell_court.webp)

![铸雨渠起点](../../artifacts/readme_current_20261123/region_ch02_rain_foundry_canal.webp)

![盐白书库起点](../../artifacts/readme_current_20261123/region_ch03_saltwhite_archive.webp)

![断弦温室起点](../../artifacts/readme_current_20261123/region_ch04_broken_string_greenhouse.webp)

![黑曜巡礼道起点](../../artifacts/readme_current_20261123/region_ch05_obsidian_pilgrim_road.webp)

![无声王冠起点](../../artifacts/readme_current_20261123/region_ch06_silent_crown_core.webp)

## 复现

导入工程资源后，从仓库根目录运行图形版 Godot。Linux 可设置独立的 `XDG_DATA_HOME`，Windows 可向截图进程传入独立的 `APPDATA`。

```sh
godot --headless --path godot --editor --recovery-mode --import --quit
godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script res://scripts/capture_readme_current.gd -- --capture-output=/absolute/path/to/captures
```

截图脚本输出 PNG。README 采用 quality 90、method 6 的 WebP。六章布局和素材图由 `python -X utf8 tools/render_current_gallery.py` 生成。只更新地图时加上 `--maps-only`。

[六章完整地图与素材图册](20261011_current_assets.md) · [路线与验证范围](../VALIDATION.md)
