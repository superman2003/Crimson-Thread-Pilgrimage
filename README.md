## 最新续接：固定世界坐标旅册（2026-10-13）

世界总览按六区固定原点与真实房间矩形统一比例绘制，替换原区域卡片。购图、途中笔记、钟龛补绘、隐藏房间规则保留；实体钟管与尚未实体化的旧路端点关系分开显示。PR #27流式地形旧夹具已修复并推送c61b822。本地定向回归/三种GL地图夹具通过，完整回归及远端CI仍在运行；W00c、共享洞口、邻区玩法驻留与T03/T04未完成。

# Crimson Thread Pilgrimage / 绯线巡礼

## 当前升级：首条步行排水钟管（2026-10-13 素材修正）

承接 PR #26 的邻区平台、岩层和斜坡预建，本批推进 W00c：苔钟庭与铸雨渠之间的排水钟管新增 8540 像素可往返实体路面。朝出口方向踏进入口即可进入，F 也可打开管道；需要实际走到另一端，途中可向来路折返，Esc 返回入口。原有能力门、另一侧闩门与源区存档恢复点保留。

管道采用同一苔岩材质绘制顶板、地板和背墙；支撑架采用完整苔石拱架与同图集吊灯；拱架与岩壁共用石材采样和苔褐色调，置于中景并由岩层遮挡柱脚与拱顶，补上接触阴影，人物保持前景可读。原区内容在管道内暂时隐藏、停止处理并隔离碰撞；出口仍执行可取消的分帧整区装载，保留宿主、玩家和构筑，完成时按固定世界坐标换算落点。**这是一条独立通道内容块，尚不是两区共用物理空间的无缝大世界。** 其它跨区连接仍是成对落点；连续世界地图、邻区角色/交互驻留和复杂提交预算仍待完成。

本地 58 套 Godot 全量门禁零失败；随后最终受影响三套再次零失败，通道扩展到 52 项检查。免伤导航 25 步/3728 物理帧通过，不能计为六区带伤通关。真实 Mesa llvmpipe 的三处管道取样通过，新增人物显隐像素对照；原有岩壁接缝 12 项图形检查通过。退出 RefCounted 警告与编辑器导入 RID 问题继续列入 T03。远端 CI 以最终提交为准。

![排水钟管实机取样，展示夹具定位](artifacts/world_passage/pipe_4200.jpg)

[本批报告与验收边界](docs/report/20261012_first_walkable_passage.md) · [全部升级进度](docs/UPGRADE_PROGRESS.md) · [阶段计划](docs/STAGED_UPGRADE_PLAN.md) · [验证摘要](artifacts/world_passage/verification.json)

## 游戏界面 · 归途手札

统一针线、旧铜、骨白与墨青的界面风格，重制生命刻印、四槽战斗 HUD、行囊、旅记、六页契印构筑、对话、地图与设置。菜单暗化世界并保留实际输入锁，适配不同窗口比例与 26px 对话。

![归途手札 HUD](artifacts/ui_redesign/world_hud.jpg)
![分类行囊](artifacts/ui_redesign/inventory.jpg)

[查看 17 张实机界面与状态图](docs/gallery/20261011_ui_redesign.md) · [实现、验证与复现](docs/UI_REDESIGN.md)

## 最新升级与实机画面（2026-10-11）

[PR #12](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/12) 已合入 main：六区跨区侧路、20 个能力练习／回访空间，以及按策划实现的 **契印系统**。缝名、司铸、校录通过线势、钟压和盐记形成不同打法；六个技能与四种战具各装备两个，六件铭饰消耗契印容量。获得接入既有 NPC 支线，永久探索能力独立保留。契印与铭饰在钟龛调整，战具在钟龛免费补给；换装和恢复方案不刷新生命、能量、次数或冷却。

下图由 **Godot 4.6.1 实际运行 `World.tscn`** 截取，包含游戏场景、人物、HUD 和实际构筑界面。截图采用隔离的展示存档，预置获得进度与配装，用于展示功能；不作为正常流程获得或带伤通关证明。旧的灰背景大字号 UI 测试截图另保留为布局验收资料。

![当前 World 场景与双槽 HUD](artifacts/seal_world/world_hud.png)

![实际 World 场景中的契印页面](artifacts/seal_world/seal.png)

![实际能力练习工房与练针架](artifacts/seal_world/practice.png)

[查看全部 9 张最新实机图：六页面、HUD、练习与技能动作](docs/gallery/20261011_seal_world.md) · [契印验收与剩余项](docs/SEAL_VALIDATION.md) · [获得事件与剧情核对](docs/SEAL_LORE.md) · [六区升级范围](docs/SIX_REGION_UPGRADE.md)

默认操作：**B** 构筑，**L** 施放当前技能，**C** 切换技能，**T** 使用战具，**G** 切换战具；**K/X** 保留钩索。手柄 **Y** 技能、**L2/R2** 切换技能／战具、**十字键下** 使用战具。设置页支持重新绑定；技能和战具尚未获得时会显示条件。

验证覆盖 41 个不同 Godot 套件，最终受影响套件与新增契印套件串行复验通过；完整记录见验收文档。远端状态以 [GitHub Actions](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions) 为准。完整手柄体验、逐帧角色动画、混音试听和六区多构筑带伤通关仍待人工验收。

## 互联世界可玩版本（2026-10-11）

直接运行 Godot 工程现在进入 `World.tscn`：苔钟庭 → 铸雨渠取得攀壁 → 盐白书库取得双线跃 → 返回苔钟庭打开盐风封门 → 收取失名证词并接通永久归庭索道。途中不必先清空全图小怪或击败每区 Boss；受阻时仍有可走的水道和庭内支线。

世界按区域保存拾取、捷径、探索、Boss 和钟龛；跨区保持当前生命与能量，重启回到当前区域已记住的钟龛。**M** 打开地图，在地图内按 **Tab** 切换六区互联图；**F** 交谈、收取证词和穿过入口；**F9** 确认后开始新旅途并保留旧旅途备份。**K/X** 朝向铜环可用回声钩索位移，需先在雨渠取得既有钩索；空中再按跳跃使用已获得的双线跃。

五位 NPC 的“把名字带回来”支线跨越前三地区。完整听完才推进，F/鼠标先补全字幕再继续，返回学徒可获得一次性奖励。原创短拟声配中文字幕；保留原有区域音乐、战斗/命中/死亡音效，增加小怪交战叫声限频及跨场景混音保护。

**范围**：前三地区已用真实输入走通能力回访闭环；最新版本增加后三地区侧向支路与能力回访工坊，原房间逐间重构和非线性路线体验仍待打磨。运书索道目前使用明确的交互入口与成对落点，沿用的洞穴升降笼仍为真实物理交通。导航测试使用免伤，并不代表完整六区人工战斗通关。

独立试玩 `Main.tscn`、生成地图场景及 `--demo-config=...` 保持原配置，不读写新世界记录。[本轮实现与验证](docs/report/20261011_interconnected_world_implementation.md)。

## 历史整合记录（2026-10-11）

[PR #8](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/8) 已合入 main，合并提交为 [b0326e6](https://github.com/superman2003/Crimson-Thread-Pilgrimage/commit/b0326e62491140a9fe089706d692f5d09ca30354)。六章地图、美术、战斗和界面已可从 main 使用；原分支保留供历史追溯。

[PR #7](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/7) 的运行时修复也已合入；旧 [PR #6](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6) 已关闭，其旧地图没有覆盖新内容。

[合入版本的 CI](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38117357448) 通过 15 个 Godot 套件、三个 Node 测试和两项章节结构检查，其中章节回归 270 项、物理与减速 12 项、复审回归 133 项。此处记录当时的整合检查；最新版本另扩展了构筑、状态清理与剧情回归。详见[整合与验证记录](docs/report/20261011_flat_map_integration.md)。

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
godot/scenes/World.tscn
```

`Main.tscn` 保留为独立章节试玩入口。

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

`npm test` 已包含活动地图几何、唯一性和运行器负面检查，`npm run test:campaign` 校验当前战役、剧情和世界路线。旧生成地图的 54 处恢复点缺陷仍由单独的严格检查报告；它不等同于活动六区地图。详见 [验证范围](docs/VALIDATION.md)。

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

## 逐批关卡升级

[W02 第一批：苔钟庭五间原房间重构](docs/CH01_ROOM_RECONSTRUCTION.md) · [实机前后对比](docs/gallery/20261011_ch01_rooms.md)。全清单仍分批推进，验收范围见文档。

[六区岩壁与整块结构材质修复：实机对比](docs/WORLD_MATERIALS.md)。
