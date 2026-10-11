# PR #6 与当前 main 的核对及处理

审计日期：2026-10-11。核对对象为远端代码和实际 Godot 运行结果，不以旧审查意见直接推断当前故障。

最终处理状态：PR #6 已关闭且未合并，替代修复 PR #7 已合入 main；随后六章地图与美术 PR #8 也已合入，合并提交为 `b0326e62491140a9fe089706d692f5d09ca30354`。以下审计数字、地图配置和“main”比较均以审计起点 `7a6b96c` 为准，不代表改版后的当前 main。最终整合验证及新增待处理审查见[六章地图整合记录](20261011_flat_map_integration.md)。

## 结论

[PR #6](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6) 的四份地图已被 main 的独立地图、剧情、NPC、收集物及运行时配置替代，不适合通过解决 JSON 冲突来重新引入。采用基于当前 main 的独立修复 PR 替代旧 PR；旧分支保留以供追溯，不合并旧地图或其生成脚本。

在审计起点确认运行时仍有三类相关问题：拉杆捷径被清怪自动打开、重叠二维房间被列表中的外层房间抢先识别，以及交互使用过期的区域进入目标。修复这三类问题，同时补齐旧 Boss 挡墙命名的兼容性。当前六章地图没有旧 PR 的出口挡墙，因此兼容性修复不等于确认 main 存在第四至第六章无法离开的 P1 故障。

六份 `godot/data/demo_ch0*.json`（不含 Boss trial）与审计起点 main **逐字节相同**；地图、剧情、NPC 位置、背包目录、Boss 数据与音频素材均不从旧 PR 覆盖。

## 分支、历史及实际冲突

| 对象 | 固定提交 |
| --- | --- |
| 审计起点 main | [`7a6b96cf8ed54dc31e7e58d963372324ffbd579e`](https://github.com/superman2003/Crimson-Thread-Pilgrimage/commit/7a6b96cf8ed54dc31e7e58d963372324ffbd579e) |
| PR #6 最新 head | [`3354377a0f8af7110c3eb066ebe1ce808860a388`](https://github.com/superman2003/Crimson-Thread-Pilgrimage/commit/3354377a0f8af7110c3eb066ebe1ce808860a388) |
| 共同祖先 | [`3ecd08a28c14c816f89767aaf422c0b58e74b689`](https://github.com/superman2003/Crimson-Thread-Pilgrimage/commit/3ecd08a28c14c816f89767aaf422c0b58e74b689) |

Git 提交比较确认 main 独有 10 个提交，PR 独有 4 个。PR 仅修改第三至第六章四份 JSON，并增加两个 Python 工具，共 6 个文件，5,387 行增加、2,153 行删除。`git merge-tree --write-tree --name-only main pr6/head` 实际产生四份章节 JSON 的内容冲突。

main 相对共同祖先已改变这四章的 `platforms`、`map_rooms`、`connections`、`map_topology`、`runtime_geometry`、出生点、敌人位置、NPC、背包、收集物、环境块和出口数据；第六章还新增结局门与愿板。冲突涉及运行时数据契约和内容，不能只按坐标字段接受旧版本。

| 章节 | 旧 PR 世界尺寸 / 房间 / 平台 | main 世界尺寸 / 房间 / 平台 |
| --- | --- | --- |
| 第三章 | 18800 × 2400 / 18 / 167 | 7580 × 2842 / 15 / 56 |
| 第四章 | 18800 × 2000 / 18 / 78 | 7610 × 2718 / 16 / 65 |
| 第五章 | 18800 × 1900 / 18 / 88 | 7150 × 3262 / 14 / 64 |
| 第六章 | 18800 × 2800 / 18 / 42 | 5550 × 3412 / 15 / 46 |

在独立临时目录中将旧 `build_unique_chapter_maps.py` 放到当前配置上运行，立即以 `room spans sum to 18800, expected width 7580` 退出；未让它写入工作分支的数据。

## 全部 11 条审查逐项核实

下表中的 main 均指上述固定提交，修复指替代 PR 的变更。

| 审查 | PR 最新版本核实 | 当前 main 核实与处理 |
| --- | --- | --- |
| [3488031459：奖励门能力不可得](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488031459) | 最新 ch03 仍保留 `ch03_reward_gate`，要求 `rift_hook`；起始工具中没有它，也没有该章收集物提供它。 | ch03 已无旧门，`locked_gates` 为空。后续运行时已在换章前传递背包并与起始工具按最大计数合并。验证五次换章的已取得 `echo_hook`、钱币和剧情 flag；未重新增加无法获得的门。 |
| [3488031461：奖励门切断主廊](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488031461) | 评论中的 `well_alcove` / `well_gallery` 和 `[2760,300,36,110]` 已被后续 PR 地形重做替代；最新奖励门矩形为 `[6030,300,36,120]`。 | main 不含这组旧地形和旧奖励门，故不移植旧坐标修补。 |
| [3488031462：清怪自动打开拉杆捷径](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488031462) | 仍依赖原运行时：清怪调用 `_open_all_shortcuts()`，拉杆此前被 combat goal 拦截。 | 问题仍在。六章拉杆各自绑定 `shortcut_id`。现在手动捷径由对应拉杆开启；最后一个普通敌人仍解锁 Boss 路线，但不会顺带打开手动捷径。提前拉杆也不会跳过 Boss 的清怪条件。保留未绑定拉杆的旧清怪捷径、钥匙模式与调试全开行为。 |
| [3488031464：ch03 井内上下层房间混淆](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488031464) | 旧井被重做，但最新 PR 的房间仍只有 x `range`，没有二维范围。 | main 的全部 140 个房间已有二维范围；ch03 旧层级缺失已被替代。另确认当前嵌套区域仍有顺序抢占：按最小包含矩形选择具体房间，并限制 x 回退只用于无二维范围的旧房间。 |
| [3488065742：ch03 Boss 后方墙不可越过](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488065742) | 最新墙名是准确的 `boss_back_wall`，该 PR 运行时已识别此名，且 Boss 死亡会调用解除路线函数。不能把早期评论直接当作最新 PR 的持续故障。 | main 没有旧墙；实际 Boss 死亡开放出口与解除封房通过。另通过真实碰撞体夹具验证旧命名兼容。 |
| [3488065746：ch03 Boss 活动边界过时](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488065746) | 最新 PR 仍保留旧标量边界，与新 Boss 地板不符。 | 已修复／被替代：`mantis_floor` 为 x=5620..6260，Boss 标量边界 5650..6230。实际 Actor 左右越界后夹回边界通过；不恢复旧 16370..17790。 |
| [3488085707：P1 前缀挡墙无法解除](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488085707) | ch04–ch06 生成 `c4_boss_back_wall` 等名称，原谓词不匹配，确有旧 PR 风险。 | 当前地图没有这些墙，未确认 main 出口堵塞；运行时谓词确实仍不兼容。增加 `_boss_back_wall` 后缀识别；六章均注入实际 `StaticBody2D` 与碰撞形状，在真实 Boss 死亡后检查墙被删除、Boss 地板保留。普通封房墙和带尾饰的装饰名不误删。 |
| [3488085708：生成器遗漏标量 Boss 边界](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488085708) | 生成器只在旧数据已有 `arena` 数组时写数组，没有更新实际使用的 `arena_min_x/max_x`。 | 六章已有与当前地板相符的标量范围，实际 Actor 边界验证均通过。旧生成器不进入替代 PR，无需给弃用工具添加一个会覆盖新地图的“修好版”。 |
| [3488085709：生成器缺少 y 房间范围](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488085709) | 最新 PR 全部生成房间缺少 `layout_rect/visit_rects`。 | main 已有二维范围，但嵌套优先级仍需修复，见上。11 个真实房间定位用例、同 x 上下层、范围外位置和旧 x-only 地图回退均通过。 |
| [3488085711：ch06 核心交互重叠](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488085711) | 最新 PR 将拉杆、隐藏存档及六印 NPC 放到 `[8900,2560]`。 | 原三重同点已消失，但当前还有两组距离仅 40px / 30px 的 NPC 与存档点；运行时沿用过期区域进入目标。现在每次 F 都重新按当前位置选择目标，保留出口的既有优先级；两组对象的交谈、恢复及远距离过期缓存验证通过，不改动作者的 NPC 坐标。 |
| [3488085713：换章出生点仍在旧高度](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/6#discussion_r3488085713) | PR ch03–ch06 的 `entry_from_previous.position` 仍是 `[520,500]`，与其新起点不一致。 | main ch03..ch06 的 entry 分别为 `[300,2580]`、`[330,1740]`、`[300,2720]`、`[2710,660]`，与现有起点一致。六章落地范围依据实际 Player 跳跃参数核验；五次换章均验证场景 active spawn 及 Player 实际 respawn target。 |

## 尚有价值的差异及取舍

旧 PR 的独立纵向章节意图有价值，但当前 main 已有独立拓扑和二维房间，其具体 JSON 不能作为缺失内容重新合入。旧脚本固定世界宽度、房间数和实体锚点；同时遗漏入口、房间二维范围和 Boss 标量边界，不保留为现行地图生成入口。

保留的收益是针对真实玩家运动参数、Boss 出口阻挡和手动捷径建立可执行约束。本次把这些收益落实为 `chapter_route_regression_validation.gd`：检查默认六章的出生落地与活动边界，执行 Boss 进场／死亡、碰撞体解除、交互和跨章背包流程。已有 `validate_generated_godot_runtime.py` 也读取实际运动参数；不再重复加入旧生成器的简单固定距离 BFS。

旧 `render_chapter_layout_preview.py` 用 x 范围画房间条带，不能呈现当前二维房间。现有 `render_demo_visuals.py` 已按 world height 和 `layout_rect` 绘制六章，因此该旧预览工具也不带入。

## 验证与限制

Godot 使用 4.6.1。回归从真实场景调用运行时；不是人工通关或完整路线可达性证明。

```sh
godot --headless --path godot --script res://scripts/chapter_route_regression_validation.gd
```

- 同一份最终回归在**未修改 main** 上失败 **37 / 175** 项、0 个脚本错误；修复后 **175 / 175 通过**、0 个脚本或引擎错误。
- 原 `inventory_map_validation.gd` 在 main 上失败两项：环庭回廊定位与名称。修复后通过。
- 10 套既有 Godot 检查通过：`inventory_map`、`demo`、`ch02_demo`、`story_guidance`、`chinese_story`、`metsys`、`boss_trial`、`combat`、`generated_runtime`、`chapter_registry`。
- 6 份既有验证脚本改为把玩家移动到交互对象后按 F，避免通过手填 `nearby_interactable` 绕过目标选择。MetSys 验证另移除已废弃 Gear Lift 坐标，使用当前 Bell Stair Well；累加断言失败，避免最后 `quit(0)` 掩盖之前的错误。
- `npm run check`、`game-data`、`static-smoke`、`runtime-smoke`、`validate_campaign_chapters.py`、`validate_chapter_files.py` 通过。`git diff --check` 通过。

以下是审计起点即存在的失败，未声称全量全绿，也未以扩大地图／素材改动的方式掩盖它们：

| 检查 | 未修改 main | 修复后 |
| --- | --- | --- |
| `npm test` | 三个 Node 套件通过后，因仓库缺少 `tools/audit_platform_geometry.py` 失败；同一 npm 命令还引用缺失的 `audit_map_uniqueness.py`。 | 相同失败；package.json 未修改。 |
| `all_chapters_demo_validation.gd` | 66 项 `original_map/<theme>` 平台／背景素材路径不存在的断言失败。 | **逐项相同的 66 项失败**；实际章节运行时、Boss 及换章检查通过，没有新增断言或脚本错误。 |
| `validate_story_runtime_consistency.py` | `ch04_broken_string_greenhouse: boss name mismatch`。 | 数据未修改，既有名称差异保留并列明。 |

旧 PR 声称通过的多层地图与节奏校验以旧宽度、水平连续房间和旧平台 ID 为前提，不能当作当前 main 的质量证据。无需重新套用旧地图来让这些旧前提成立。

## 替代 PR #7 的审查补充

[自动审查 4240218122](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/7#discussion_r4240218122) 指出：默认地图只有手动拉杆捷径时，清怪已经打开 Boss 路线，但聚合状态 `shortcut_open` 仍为 false。已有逐捷径测试添加了自动捷径夹具，未覆盖这个默认配置状态。新增用例先在未添加夹具的六章配置上清怪，再读取实际 `get_demo_state()`；提交 `9504934` 在这六项断言上全部失败（6 / 187），没有脚本错误。

现在由 `_unlock_boss_route()` 同步设置聚合标志为 true；各个捷径是否开放仍由 `opened_shortcuts` 独立记录。扩展回归 **187 / 187 通过**；`demo`、`ch02_demo`、`generated_runtime`、`boss_trial` 四套相关既有检查再次通过，没有脚本错误。测试仍检查清怪不会开启手动拉杆捷径。

[后续审查 4240241756](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/7#discussion_r4240241756) 另确认 HUD 把逐捷径计数当成 Boss 路线状态。现在战斗模式分别显示 `Boss Route Open/Closed`（取决于 `boss_unlocked`）和 `Shortcuts n/m`。新增六章在“先开手动捷径”及“先清怪”两种顺序下的实际 HUD 断言；未修复提交 `0e4ad88` 在这 12 项断言上失败（12 / 199），没有脚本错误。

HUD 修复后扩展回归 **199 / 199 通过**，没有脚本错误。

## 并行地图／美术分支的合并核对

2026-10-11 另一个会话正在上传 `codex/flat-2d-map-art`。以其本地固定提交 `4f3d0169f4312544ac230c64037e2d49a6c663b9` 和本 PR 的 `9504934f2c91acc2391b05c91105261217baca94` 运行 `git merge-tree --write-tree --name-only`，确有两份文件内容冲突：`godot/scripts/main_level.gd` 和 `godot/scripts/all_chapters_demo_validation.gd`。前者在 F 键交互函数，后者在 NPC 对话及交互测试。

GitHub 对本 PR 相对当前 main 的 `clean` 状态不代表这两个并行分支彼此兼容。集成时需保留地图／美术分支的手动拾取、对话处理以及本 PR 的目标距离判定和路径修复，针对改写后的地图重新运行回归；不能整份选择 ours/theirs。这段并行检查发生在合并前，当时未修改另一个会话的工作树或合并 PR。后续已通过 PR #8 逐项整合这些冲突，保留双方历史并重新验证改写后的地图；最终结果见上述整合记录。
