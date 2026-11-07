# 当前 main 实机界面（2026-11-07）

本组 20 张在 main `1b6cf34` 加上画面文字精简第一批（#565）后，重新运行 Godot 4.6.1 / `World.tscn` 截取：
- 分辨率 1280 × 720，Compatibility 渲染，Mesa llvmpipe；
- 由固定 1280 × 720 的 SubViewport 渲染，桌面窗口宽度受限时也不会被缩放；
- 不是概念图，也不是旧图改名。

使用隔离的展示存档：
- 装备解锁、契印机制、材料、货币、地图所有权和练针架定位由夹具设置；补给、面板与技能都走现有的正式入口。
- 地图只授予底图，不揭示隐藏房间，也不伪造探索进度。
- 构筑页在真实钟龛旁截取，截取时暂停角色物理；玩法取样时恢复物理控制。

这些图片只展示界面与局部场景，不证明自然获得、六区通关或完整测试通过。

## 与 10-15 那组相比

- 各页面改为带书法标题和描金边框的新版式，统一了字号层级（U01）。
- 契印页加入大幅契印图样，构筑页顶部摘要行右端是分阶段训练课程。
- 旅记增加十类筛选、搜索、仅未读／仅收藏和排序，正文右侧可翻页。
- 设定页新增来源与许可、声音输出设备、旅途工作台、设置方案管理、装饰动态、NPC 声音地标、手柄校准、危险字幕辅助和浏览旧旅途。按键表覆盖全部动作的键盘与手柄绑定。
- 地图加入图钉工具栏、归途结、钟龛回访、多站行程和已知地点目录。没有罗盘时不显示自身位置。
- 练习工房的说明已缩为短标签，两个练习对象的说明不再重叠。

## 复现

先导入 Godot 工程资源，再用有图形输出的 Godot 执行：

```sh
godot --headless --path godot --editor --recovery-mode --import --quit
godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script res://scripts/capture_readme_current.gd -- --capture-output=/absolute/path/to/captures
```

使用独立的 `XDG_DATA_HOME` 可以与个人存档完全分开。原始 PNG 以 WebP（quality 90 / method 6）转换后提交，输出目录按日期命名，避免沿用旧版图片 URL。

## World 场景与 HUD

![World 场景与 HUD（2026-11-07）](../../artifacts/readme_current_20261107/world_hud.webp)

## 分类行囊

![分类行囊（2026-11-07）](../../artifacts/readme_current_20261107/inventory.webp)

## 旅记

![旅记（2026-11-07）](../../artifacts/readme_current_20261107/journal.webp)

## 契印

![契印（2026-11-07）](../../artifacts/readme_current_20261107/seal.webp)

## 线技

![线技（2026-11-07）](../../artifacts/readme_current_20261107/skills.webp)

## 战具与付费补给报价

![战具与付费补给报价（2026-11-07）](../../artifacts/readme_current_20261107/tools.webp)

## 战斗铭饰

![战斗铭饰（2026-11-07）](../../artifacts/readme_current_20261107/combat_accessory.webp)

## 行旅铭饰

![行旅铭饰（2026-11-07）](../../artifacts/readme_current_20261107/travel_accessory.webp)

## 构筑方案

![构筑方案（2026-11-07）](../../artifacts/readme_current_20261107/loadout.webp)

## 区域地图

![区域地图（2026-11-07）](../../artifacts/readme_current_20261107/map.webp)

## 六区世界地图

![六区世界地图（2026-11-07）](../../artifacts/readme_current_20261107/world_map.webp)

## 设定

![设定（2026-11-07）](../../artifacts/readme_current_20261107/settings.webp)

## 能力练习工房

![能力练习工房（2026-11-07）](../../artifacts/readme_current_20261107/practice.webp)

## 线技施放

![线技施放（2026-11-07）](../../artifacts/readme_current_20261107/skill_action.webp)

## 六区起点实机画面

![苔钟庭起点（2026-11-07）](../../artifacts/readme_current_20261107/region_ch01_moss_bell_court.webp)

![铸雨渠起点（2026-11-07）](../../artifacts/readme_current_20261107/region_ch02_rain_foundry_canal.webp)

![盐白书库起点（2026-11-07）](../../artifacts/readme_current_20261107/region_ch03_saltwhite_archive.webp)

![断弦温室起点（2026-11-07）](../../artifacts/readme_current_20261107/region_ch04_broken_string_greenhouse.webp)

![黑曜巡礼道起点（2026-11-07）](../../artifacts/readme_current_20261107/region_ch05_obsidian_pilgrim_road.webp)

![无声王冠起点（2026-11-07）](../../artifacts/readme_current_20261107/region_ch06_silent_crown_core.webp)
