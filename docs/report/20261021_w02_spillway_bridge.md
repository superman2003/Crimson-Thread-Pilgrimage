# 水轮回程栈桥通道（W01／W02／T04 子项）

铸雨渠水轮回程原有台阶穿进了铁匠前廊的生成地形：`terrain_smith_approach_0_0` 把西侧石台、栈桥和炉前落点连成深 104px 的实心板。真实 Player 从下方跳起，在脚点约 y=3988 时撞到 y=3904 的板底；二段跳也只能再次撞顶。仅查看原有单向平台，不能发现这层生成地形的封堵。

栈桥 `ra_b` 现在是可从下方穿过、可站立行走的金属格栅。两侧石台分别生成实体地形，保留原位置和深度。手工房间脚本和地形构建分组同时更新，临时副本重建地形与洞穴后仍无封堵。没有调整 Player 跳跃参数、解锁条件、敌人或陷阱；原吊锤仍需从下方走过或提前跳过。

## 验证

- 既有 `rain_foundry_experience` 增加正式 World 的定位局部夹具，合计 **294 项**。不授予二段跳或攀壁，用真实单次跳跃逐级穿过栈桥，再步行避开吊锤；检查实际落地和生命未损失。这是局部夹具，不算自然章节通关。
- 仅恢复旧章节 JSON、保留最终检查后，普通跳跃被阻挡，产生 **1 条预期 ERROR**、退出 1；随后修复数据逐字节恢复。源清单和恢复哈希见 `negative_old_terrain`。
- 同步前五套原生 GL 回归通过：铸雨渠体验 294 项、六区路线 270 项、洞穴行走 78 次、通行条件 553 项、地图知识 190 项。六区路线夹具退出有 **1 条 ObjectDB warning**，原样保留；其余四套和完整实际输入续跑均无 ERROR／ObjectDB warning。同步 #181 后另复验铸雨渠体验 294、投罐战斗 194、headless 纹理争用 626 项，全部无 ERROR／ObjectDB warning。
- 可选的正式 World **51 步实际输入续跑**从 #180 正常赚取的渡槽存档原字节开始：穿过泵井与溢流庭、正常投罐、击败原有精英，按 F 打开水轮捷径，经回程台阶返回实际泵房，再走到炉前钟龛按 F 安坐。途中 **4 次扣血、4 次耗能疗伤、0 死亡**，碎钱 **24→94**，炉前恢复到 **5 生命／100 绯线**。伤害开启，不写玩家位置、不授予状态或物品。
- `npm test`、`test:campaign`、两份 Python 编译和手工脚本语法检查通过。同步 main 后默认保持 132 套（128 套常规＋4 套剧情），新续跑作为独立可选命令，不挤掉既有套件。

本批已同步远端 #181 `2fe6c53e`（含 main `6399a443` 的 #179／#180）。同步后先发现回放驱动在溢流庭反复蹬墙，改为提前二段跳；最终续跑 40.67 秒、8736 份源／脚本／种子前后一致，退出无 ERROR／ObjectDB warning。同步前的旧基线续跑为 7 次扣血、6 次疗伤；最终统计以上述新基线为准。

旧封路、定位诊断以及早期路线驱动误选落点／起跳时机的失败日志全部保留，不计为通过。两张画面来自生产 World 的局部夹具；不是新制作的美术，也不是全流程截图。证据位于 [`artifacts/w02_spillway`](../../artifacts/w02_spillway)。

## 复验

```sh
python tools/run_godot_regressions.py --engine /path/to/godot --software-gl --suite rain_foundry_experience --suite chapter_route_regression --suite cave_route_walk --suite world_route_access --suite survey_map_knowledge
python tools/run_waterwheel_route.py --engine /path/to/godot --native-gl --log-dir /tmp/waterwheel-route
```

第二条在 Linux 可省略 `--native-gl`。runner 校验 #180 种子 SHA-256，把它复制到独占的 `test_world_waterwheel_route.json`；冻结所有受版本控制的 Godot 文件及本批脚本、生成器和种子，保留严格 180 秒上限和全部引擎错误。成功后单独保存自然赚取的炉前存档，来源及哈希见 `forge_seed_provenance.json`，供后续 Boss 验证继续使用。

这批只补上水轮回环与炉前抵达证据；尚未完成六位 Boss、后三区、不同探索顺序与构筑、人工体验、发行包或 FPS 验收。46 个任务包的最终复选框保持未关闭。
