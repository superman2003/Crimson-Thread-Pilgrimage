# 隐藏路线的场景线索（W04）

修订方案 W04 要求：用环境线索引导玩家找到密室、深井、精英与终局支路；隐藏路线可以暂缓，并能安全返回；秘密不提前画进底图。

## 之前的状态

- **地图**：已经满足要求。`cartography_runtime` 不在底图上画秘密、奖励与出口房间，`cartography` 套件也有覆盖。
- **线索**：只写在房间的 `guide` 字段里，例如“上层苔面有一段颜色不对”“井底有人敲三下”。可是正式世界模式的地图面板会用 `_world_exploration_hint()` 盖掉这个字段，所以玩家从来看不到这些提示。
- **#132／#134 的做法**：在这些看不到的字段里再追加“可见线索：…”“安全离开：…”，并加了一套运行时合并逻辑来保住这些文字。#132 还有三组线索房与隐藏房根本不相邻（例如弦室与苔庭暗格相距约 1600 像素）。

本批推倒重做。

## 改动

`world_routes.json` 新增 `hidden_route_plan`，列出六区八处隐藏房间。每一处的线索都放在真正通往它的房间里，位置就在两个房间相接处：

| 地区 | 隐藏房间 | 入口房间 | 玩家走近时的提示 |
|---|---|---|---|
| 苔钟庭 | 顶阁暗格 | 半钟平台 | 半钟平台东角上方的梁缝透出一线光，有风从上面灌下来。 |
| 苔钟庭 | 假苔穴 | 水窖环廊 | 环廊湿苔板上有一段颜色发暗，踩上去发空。 |
| 铸雨渠 | 听潮暗室 | 暗渠走道 | 脚下的水声忽然变空，像下面还有一间屋。 |
| 盐白书库 | 秘阁暗格 | 二层阅览廊 | 左上方书堆后透出一道盐灯的光。 |
| 断弦温室 | 蜂蜡暗屋 | 根须南廊 | 南廊尽头的蜡壁缝里透出暖光。 |
| 黑曜巡礼道 | 巡礼军墓 | 旗桥 | 旗桥西端的栏杆断了，西边的碑林里亮着灯。 |
| 无声王冠 | 苔庭回声暗格 | 盐白回声室 | 右上方苔丛里有一盏不该亮着的回声灯。 |
| 无声王冠 | 钟舌库 | 核心竖井 | 井底托板裂开一道缝，下面传来钟舌的嗡鸣。 |

- **漏光裂缝**（`hidden_route_clue.gd`）：画在场景里的一道暖光裂缝，周围有微光，有尘粒向上飘，表示那边有空气流动。
- **走近提示一次**：玩家走到 260 像素以内时说一次看到了什么，记在存档里，之后不再重复。
- **找到后变暗**：进入隐藏房间后裂缝变暗，离开地区再回来也保持变暗。
- **可选奖励**：顶阁暗格、假苔穴、听潮暗室、苔庭回声暗格各加一份地区材料，放在房内的地板上。其余四处原本就有隐藏存档点或暗灯。

## 实机核对

用真实渲染（`capture_hidden_route_clues.gd`）逐张截图核对了八处线索。数据检查发现不了的三个问题，就是靠截图发现并改正的：

- 秘阁暗格的裂缝原定在地板上方 10 像素，玩家站上去就被角色挡住，而且和“左上方”的提示对不上。已移到阅览廊与暗格相接的墙上。
- 军墓的裂缝原定在旗桥上方 200 像素，一半被界面面板盖住；提示说碑林在“下面”，实际上它在西边同一高度。已移到旗桥西端，提示改为“西边”。
- 苔庭回声暗格的裂缝原定在地面上方 230 像素，被提示面板盖住。已降到 110 像素，提示改为“右上方”，与暗格方位一致。

另外，有三处原定位置落在与入口房间重叠的隐藏房间矩形内。游戏判定房间时，较小的房间优先，所以玩家一到线索处就会被算作“已进入隐藏房间”。已全部移到只属于入口房间的位置。

实拍（玩家初次走到裂缝旁时的画面）：

![ch01_hidden_attic](../../artifacts/hidden_route_clues/ch01_hidden_attic.webp)
![ch01_fake_moss_grotto](../../artifacts/hidden_route_clues/ch01_fake_moss_grotto.webp)
![ch02_tide_listening_cell](../../artifacts/hidden_route_clues/ch02_tide_listening_cell.webp)
![ch03_secret_nook](../../artifacts/hidden_route_clues/ch03_secret_nook.webp)
![ch04_beeswax_nook](../../artifacts/hidden_route_clues/ch04_beeswax_nook.webp)
![ch05_war_graves](../../artifacts/hidden_route_clues/ch05_war_graves.webp)
![ch06_echo_moss](../../artifacts/hidden_route_clues/ch06_echo_moss.webp)
![ch06_bell_tongue_vault](../../artifacts/hidden_route_clues/ch06_bell_tongue_vault.webp)

## 安全返回

隐藏房间能不能空手离开，由 #119 的跳跃可达探针（`tools/probe_shrine_exits.gd`）验证：8 座位于密室或单向坠入房间的钟龛，全部能空手离开。本批不重复这项工作。

## 验证

- 新增 `hidden_routes` 套件（正式 World，111 项、0 失败）。对每一处检查：
  - 入口房间确实连通隐藏房间，线索位于入口房间内、贴着隐藏房间边缘。
  - 线索已画出，且尚未标为找到。
  - 走近时提示一次，第二次不再提示。
  - 进入隐藏房间后线索变暗，找到的状态写入存档。
  - 奖励在隐藏房间内的地板上。
  - 离开地区再回来，已找到的线索保持变暗。
- `cartography`、`inventory_map`、六区体验套件（`first_court_experience`、`rain_foundry_experience`、`salt_archive_experience`、`greenhouse_experience`、`obsidian_experience`、`silent_crown_experience`）、`ch06_workshop_experience`、`world_death_cache_flush` 通过。
- `npm test`、`test:campaign` 通过；工房生成器重跑后数据字节不变。

## 仍待验收

- 实机发现率：玩家是否真的注意到这些线索（T04）。

## 2026-10-19 审查后的联合验证

本 PR 基于修复后的出口审计分支，不再引用横向瞬移采样作为安全返回证据。八座钟龛均有禁用能力拾取、连续移动并从原点重放的输入证书；默认 CI 的 `shrine_exit_routes` 会在正式 World 逐条重放。隐藏线索和工具练习均保留各自的房间进入钩子与区域生成任务。
