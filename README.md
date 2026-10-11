# Crimson Thread Pilgrimage / 绯线巡礼

一个 Godot 4.6 2D 动作平台游戏原型。当前 main 包含六章洞穴地图、实心岩层、连续地形与斜坡、普通洞道完整视野、特殊暗穴局部视野和物理升降笼、40 种小怪和 6 位 Boss 的 104 套攻击序列，以及分类背包、NPC 对话与交付、手动拾取、音量设置、存档和 Metroidvania 地图。

> 本项目是学习与原型用途的独立工程，不包含任何第三方商业 IP 资源。代码按 MIT 发布；第三方素材分别遵守各自许可证。

## 当前状态（2026-10-11）

[PR #8](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/8) 已合入 main，合并提交为 [b0326e6](https://github.com/superman2003/Crimson-Thread-Pilgrimage/commit/b0326e62491140a9fe089706d692f5d09ca30354)。六章地图、美术、战斗和界面已可从 main 使用；原分支保留供历史追溯。

[PR #7](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/7) 的运行时修复也已合入；旧 [PR #6](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6) 已关闭，其旧地图没有覆盖新内容。

[合入版本的 CI](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38117357448) 通过 15 个 Godot 套件、三个 Node 测试和两项章节结构检查，其中章节回归 270 项、物理与减速 12 项、复审回归 133 项。最新自动代码与安全复审均已结束；合并后的两条 P2 意见仍待处理：跨章携带物品的分类，以及攻击打断后的警示线清理。详见[整合与验证记录](docs/report/20261011_flat_map_integration.md)。

## 洞穴探索升级（2026-10-11）

洞穴升级由 [PR #9](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/9) 整合；该 PR 的合并状态与 CI 结果可在链接中查看。新增六章升降笼正常玩家物理上行回归，洞穴套件共 170 项检查。

地图现以实心岩层围出洞道，普通通道有洞顶和洞壁，大厅与 Boss 场保留战斗空间。普通洞道、升降井和 Boss 场完整显示，岩层外围仍为不透明黑色；只有显式标记的黑暗区域启用局部视野，目前为第一章“假苔穴”。离开后恢复正常视野；39 条新增地面连接可双向步行，每章有一座可呼叫的物理升降笼。找到并接通捷径拉杆即可开启 Boss 通路，清空全图小怪也仍可开门。

下方为洞穴升级初版的 Godot 实机渲染，不是概念图；其中旧的普遍局部视野效果已改为仅在特殊暗穴启用。按 **F** 呼叫/乘坐升降笼，**M** 查看已探索地图。保留攀爬和少量跳跃路段，主线增加步行、洞道探索与升降通路。

![六章洞穴实机总览](artifacts/cave_exploration/six_chapter_caves.jpg)

[调研、改动与验证记录](docs/report/20261011_cave_exploration_upgrade.md) · [完整地图及怪物图册](docs/gallery/20261011_current_assets.md)

| 章节 | 洞穴画面 | 升降笼画面 |
| --- | --- | --- |
| 第 1 章 | [实机画面](artifacts/cave_exploration/ch01_cave.jpg) | [升降笼](artifacts/cave_exploration/ch01_lift.jpg) |
| 第 2 章 | [实机画面](artifacts/cave_exploration/ch02_cave.jpg) | [升降笼](artifacts/cave_exploration/ch02_lift.jpg) |
| 第 3 章 | [实机画面](artifacts/cave_exploration/ch03_cave.jpg) | [升降笼](artifacts/cave_exploration/ch03_lift.jpg) |
| 第 4 章 | [实机画面](artifacts/cave_exploration/ch04_cave.jpg) | [升降笼](artifacts/cave_exploration/ch04_lift.jpg) |
| 第 5 章 | [实机画面](artifacts/cave_exploration/ch05_cave.jpg) | [升降笼](artifacts/cave_exploration/ch05_lift.jpg) |
| 第 6 章 | [实机画面](artifacts/cave_exploration/ch06_cave.jpg) | [升降笼](artifacts/cave_exploration/ch06_lift.jpg) |

## 怪物素材与完整地图

40 种小怪与 6 位 Boss 的当前素材在下方直接展示；[完整图册](docs/gallery/20261011_current_assets.md)提供各章高清地图、小怪分章图册、实机画面，以及全部 46 类敌人的原始动画图集链接。

地图总览由当前章节配置按世界坐标比例生成，展示完整布局及关键对象位置，属于布局图。实机画面见下方预览及完整图册。

![40 种小怪素材总览](artifacts/current_gallery/monsters_all.jpg)

![6 位 Boss 素材总览](artifacts/current_gallery/bosses_all.jpg)

![六章完整地图布局总览](artifacts/current_gallery/map_overview.jpg)

| 章节 | 完整地图 | 小怪图册 | 实机画面 |
| --- | --- | --- | --- |
| 第 1 章 · 苔钟庭 | [查看全图](artifacts/current_gallery/demo_ch01_moss_bell_court_full_map.jpg) | [6 种小怪](artifacts/current_gallery/ch01_enemies.jpg) | [截图](artifacts/pilgrimage_overhaul/demo_ch01_moss_bell_court.png) |
| 第 2 章 · 铸雨渠 | [查看全图](artifacts/current_gallery/demo_ch02_rain_foundry_canal_full_map.jpg) | [7 种小怪](artifacts/current_gallery/ch02_enemies.jpg) | [截图](artifacts/pilgrimage_overhaul/demo_ch02_rain_foundry_canal.png) |
| 第 3 章 · 盐白档案馆 | [查看全图](artifacts/current_gallery/demo_ch03_saltwhite_archive_full_map.jpg) | [6 种小怪](artifacts/current_gallery/ch03_enemies.jpg) | [截图](artifacts/pilgrimage_overhaul/demo_ch03_saltwhite_archive.png) |
| 第 4 章 · 断弦温室 | [查看全图](artifacts/current_gallery/demo_ch04_broken_string_greenhouse_full_map.jpg) | [6 种小怪](artifacts/current_gallery/ch04_enemies.jpg) | [截图](artifacts/pilgrimage_overhaul/demo_ch04_broken_string_greenhouse.png) |
| 第 5 章 · 黑曜巡礼路 | [查看全图](artifacts/current_gallery/demo_ch05_obsidian_pilgrim_road_full_map.jpg) | [7 种小怪](artifacts/current_gallery/ch05_enemies.jpg) | [截图](artifacts/pilgrimage_overhaul/demo_ch05_obsidian_pilgrim_road.png) |
| 第 6 章 · 无声王冠 | [查看全图](artifacts/current_gallery/demo_ch06_silent_crown_core_full_map.jpg) | [8 种小怪](artifacts/current_gallery/ch06_enemies.jpg) | [截图](artifacts/pilgrimage_overhaul/demo_ch06_silent_crown_core.png) |

## 预览

2026-10-11 改版：[第一章实机画面](artifacts/pilgrimage_overhaul/demo_ch01_moss_bell_court.png)、[分类背包](artifacts/pilgrimage_overhaul/inventory.png)、[NPC对话](artifacts/pilgrimage_overhaul/dialogue.png)。[六章截图目录](artifacts/pilgrimage_overhaul)。本轮包含46类敌人的104个招式、六章手绘地图与连续地形，详见[改版记录与验证](docs/release/20261011_pilgrimage_overhaul.md)。

![第一章当前洞道实机画面](artifacts/cave_exploration/ch01_cave.jpg)

![新版分类背包](artifacts/pilgrimage_overhaul/inventory.png)

## 运行 Godot 项目

需要：

- Godot 4.6.x
- Python 3.10+，用于素材/数据验证脚本
- Node.js 18+，仅用于旧版浏览器原型和 smoke test

启动：

```powershell
godot --path godot
```

主场景：

```text
godot/scenes/Main.tscn
```

常用验证：

```powershell
godot --headless --path godot --script res://scripts/demo_validation.gd
godot --headless --path godot --script res://scripts/ch02_demo_validation.gd
godot --headless --path godot --script res://scripts/combat_validation.gd
godot --headless --path godot --script res://scripts/all_chapters_demo_validation.gd
godot --headless --path godot --script res://scripts/cave_exploration_validation.gd
godot --headless --path godot --script res://scripts/cave_route_walk_validation.gd
godot --headless --path godot --script res://scripts/chapter_route_regression_validation.gd
godot --headless --path godot --script res://scripts/pilgrimage_merge_regression_validation.gd
godot --headless --path godot --script res://scripts/pilgrimage_review_regression_validation.gd
godot --headless --path godot --script res://scripts/pilgrimage_overhaul_validation.gd

python tools\validate_chapter_files.py
python tools\validate_open_asset_policy.py
python tools\validate_itch_enemy_assets.py
python tools\render_current_gallery.py
```

旧版浏览器原型：

```powershell
npm run check
node tests/game-data.test.mjs
node tests/static-smoke.test.mjs
node tests/runtime-smoke.test.mjs
npm start
```

然后打开 `http://127.0.0.1:5173/`。

全量 `npm test` 仍引用缺失的 `tools/audit_platform_geometry.py` 和 `tools/audit_map_uniqueness.py`；旧章节规划与新 campaign 的 Boss 名称一致性检查也尚未通过。上述 CI 成功不表示这两类检查已修复。

## 当前内容

- 六章试玩数据：`godot/data/demo_ch01_*.json` 到 `godot/data/demo_ch06_*.json`
- 章节策划数据：`godot/data/chapters`
- Godot 主逻辑：`godot/scripts/main_level.gd`
- 玩家控制器：`godot/scripts/player_controller.gd`
- 敌人/Boss AI：`godot/scripts/enemy_actor.gd`
- Metroidvania System 插件：`godot/addons/MetroidvaniaSystem`
- 素材处理和验证脚本：`tools`
- 设计、决策、发布记录：`docs`

## 素材授权边界

可随本仓库发布的主要素材：

- Kenney assets: CC0
- GothicVania Cemetery / Ansimuz: Public Domain / 商用友好记录
- OpenGameArt Dark Fantasy Platformer Bestiary: CC-BY 系列来源，已在项目 NOTICE 中记录署名
- Godot Platformer 2D: MIT
- Metroidvania System: MIT
- 项目自制/生成运行资源：主角关键帧、部分 UI/验证产物和脚本生成图

不会随公开仓库发布的本地受限素材：

- Maaot / Mossy Cavern
- Arhimed122 / Abyss Bug Sprite Pack
- MonoPixelArt / Forest Monsters 2D Pixel Art FREE

详细清单见：

- [不可再分发素材包清单与开源边界](docs/decision/20260616162014251_不可再分发素材包清单与开源边界.md)
- [Third Party Notices](THIRD_PARTY_NOTICES.md)
- [Godot asset notice](godot/assets/NOTICE.md)

这些受限素材可能存在于本地开发缓存或历史文档中，但已从公开运行时引用中移除，并由 `.gitignore` 排除。

## 开源发布范围

提交范围包括：

- Godot 工程核心文件
- 运行所需且可再分发的素材
- 文档、验证脚本、展示图
- Web 原型和 smoke tests

提交范围排除：

- `artifacts/source_repos`
- `artifacts/source_assets`
- `artifacts/third_party`
- `artifacts/debug`
- `godot/.godot`
- `tmp`
- 本地受限素材目录和对应导入脚本

## License

项目代码使用 MIT License。第三方素材、插件、音频和字体等按各自许可证使用，详见 `THIRD_PARTY_NOTICES.md` 和各素材目录下的 NOTICE/LICENSE 文件。
