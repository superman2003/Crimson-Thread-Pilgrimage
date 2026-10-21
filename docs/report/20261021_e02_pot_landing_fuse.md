# 铜铃投罐落地预警与爆炸遮挡（E02／T04 子项）

正常投罐落在同高地面约需 0.9 秒，随后应预警 0.35 秒；旧实现先被 1 秒总寿命截断，已经消耗次数却没有爆炸。此前 `seal_combat` 的投罐夹具直接设置了 `landed`，没有覆盖实际飞行，所以未发现此问题。

现在空中仍按原 1 秒／360px 行程限制回收；有效落地后由原 0.35 秒预警完成爆炸并立即回收玩法对象。伤害、爆圈、投掷速度、消耗和终端装饰均沿用原值。20261020 的 V04 战具美术报告所述“1 秒总寿命不变”是该批历史边界，本批明确修正落地后的寿命行为。

爆炸遮挡射线同时保留碰撞前的空中位置作为起点：物理射线从墙面起算可能漏掉该墙，正式 World 的地形射线又可能在地面碰撞点产生零距离命中。爆圈中心仍为真实碰撞点；射线从已知位于表面外的点检查目标，墙后目标继续受阻。

## 验证

- `seal_combat` 原 138 条检查全部保留，新增 56 条，合计 **194**。七种真实弹道：左右平地、左右低 20px 落点、深落点空中超时、独立行程上限、墙面落点遮挡。测量实际落地至伤害的 0.35 秒预警，检查一次性伤害、回收及无命中回能。没有强制设置落地状态。
- 恢复旧生产实现后，相同最终检查产生 **13 条预期失败**；只保留寿命修复时，墙后目标检查失败。完整修复后全部通过。
- 正式 World 的 **14 步实际输入续跑**：读取 #180 正常赚钱购图流程留下的原字节渡槽存档，经过低顶渠廊、泵房、泵井与溢流庭，用自带投罐击败原有 E08 地面敌人。存量 **3→2**、目标 **2→0**、碎钱 **24→32**；途中真实受伤并耗能疗伤，0 死亡。没有位置、生命、能量或物品授予。只保留寿命修复、撤掉射线修复时，这条相同路线的击杀与收入检查均失败。
- 最终六套原生 NVIDIA GL 回归通过：`seal_combat` 194、`tool_practice` 98（另含既有战具美术检查）、`build_transaction_runtime` 30、`combat_resource_cycle` 149、`combat_visual_budget` 44、`enemy_effect_lifetime` 46。构筑事务夹具退出有 **1 条 ObjectDB warning**，保留待查；其余五套和实际续跑退出均无 ERROR／ObjectDB warning。
- `npm test`、`test:campaign`、新增 Python runner 编译通过。默认回归集合维持 main 原 131 套（127 套常规＋4 套剧情），投罐检查加入既有 `seal_combat`；自然续跑为独立可选命令。

测试基于 main `8467e946` 加本批源码差量。最终源清单、原始日志（无损压缩）、脚本快照、两次反向检查及逐字节恢复记录位于 [`artifacts/t04_pot_fuse`](../../artifacts/t04_pot_fuse)。每个运行均保留严格 180 秒上限、完整错误与源冻结；最终发布提交的 CI 应按其准确提交另核。

## 复验命令与范围

```sh
python tools/run_godot_regressions.py --engine /path/to/godot --software-gl --suite seal_combat --suite tool_practice --suite build_transaction_runtime --suite combat_resource_cycle --suite combat_visual_budget --suite enemy_effect_lifetime
python tools/run_pot_route.py --engine /path/to/godot --native-gl --log-dir /tmp/pot-route
```

第二条命令在 Linux 可省略 `--native-gl` 使用软件 GL。它校验已赚取种子的 SHA-256，并逐字节复制到独占的 `test_world_pot_route.json`，不会替换玩家存档；seed 来源提交、PR 和原验证记录见 [`seed_provenance.json`](../../artifacts/t04_pot_fuse/seed_provenance.json)。源、runner 与 seed 均纳入前后冻结。

首次普通 headless 编辑器导入退出 0，但报告 4 条 RID 泄漏 ERROR，已原样保留，不能算通过。与现有 CI 相同的 `--recovery-mode` 资源导入连续两轮通过；该模式不验证编辑器插件／工具脚本。游戏回归在正常生产运行时执行。

早期两次泵房飞行目标投罐未命中，仅作失败诊断保存，不计通过；最终使用适合投罐的溢流庭地面目标，并用相同路线反向检验射线修复。

这份证据是从已赚取存档继续的源码运行时回放，未重新完成新档全程，不代表发行包、FPS、完整六区、多构筑或人工体验验收。水轮回环、六位 Boss、后三区、实体手柄与实听继续待验收；46 个任务包的最终复选框保持未关闭。
