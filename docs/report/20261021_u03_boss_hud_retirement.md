# Boss 消散后的 HUD 引用与实际钩索续跑（U03／B03／T04 子项）

绯线执剪者被正常击败后，死亡消散约 0.95 秒才释放对象；World 仍保留该引用。HUD 先把它赋给有类型的 `Node` 变量，再检查有效性，导致对象真正释放后每帧抛出错误，后续旅记刷新也被中断。首轮短回放在消散结束前退出，没有触发问题；继续走钩索路线才把它暴露出来。

现在先验证引用，再赋给 `Node`。没有提前清掉 World 的 Boss 引用，也没有修改 Boss 生命、攻击、消散、奖励或玩家参数。

## 验证

- 既有 `ui_world_integration` 追加 **5 项**局部生命周期检查：正式 World 生成原有 Boss，用夹具致死伤害触发正常奖励与消散，等待实际释放，再验证 Boss 条隐藏、旅记仍刷新。这是组件夹具，不算自然战斗。恢复旧 HUD 后出现 6 条脚本错误和 1 条旅记刷新失败，runner 正确拒绝；源码逐字节恢复。
- 旧 HUD 的完整实际输入路线虽然退出 0、31 步游戏断言均通过，却出现 **1511 条脚本错误**，runner 仍判失败；完整日志和验证记录保留。
- 修复后 **31 步实际输入续跑**从 #182 正常赚取的炉前存档原字节开始：按 F 开 Boss 门，击败完整 **26 HP** 的执剪者。记录了实际 active 出招：合剪 15 次、绯线封路 9 次、结阵 4 次、二阶段跃转 6 次；没有强制选择招式或修改 Boss 状态。为覆盖后两招，回放在半血后暂缓攻击，仍需正常躲避。
- 正常获得铁匠誓牌与 30 碎钱（**94→124**）、解除场地封门，走钟摆长井取得回声钩索；用真实向上钩索输入拉向原铜环，通过能力门取得工牌，再返回门西侧。全段 **2 次扣血、2 次耗能疗伤、0 死亡**，没有位置写入、无敌、物品或能量授予。
- 独立新引擎进程从实际炉前检查点恢复，钱包 **124**、14 种物品及各自数量完整保留，Boss 不重复生成或奖励，钩索能力与能力门继续有效。正确证明通过；错钱包、小数物品数量、缺失原进程编号三种反向证明均被拒绝。重启校验复用既有 `_inventory_matches`，逐项比较数值，不截断数量。首轮直接比较 JSON 字典造成的类型误报保留，不计通过。
- 最终整轮含重启 **104.25 秒**，8737 份源／脚本／种子前后一致，两进程均无 ERROR／ObjectDB warning。每个进程仍有严格 180 秒上限。
- 四套相关原生 GL 断言通过：UI 整合、UI 重构、构筑无障碍、Boss 试炼。UI 整合和 Boss 试炼退出各有 **1 条 ObjectDB warning**，保留待查；UI 整合另在 headless 模式通过，退出无 ERROR／warning。`npm test`、`test:campaign` 与 Python 编译通过。默认仍为 132 套，新自然续跑独立可选。

代码基于 #182 `521aeaae` 的追加差量。原始日志、源清单、旧代码反向检查和路线驱动失败均位于 [`artifacts/t04_smith_hud`](../../artifacts/t04_smith_hud)。正常赚取的新种子、输入种子的 SHA-256 和来源见 `seed_provenance.json`，供后续区域续跑。

## 复验与范围

```sh
python tools/run_godot_regressions.py --engine /path/to/godot --software-gl --suite ui_world_integration --suite ui_redesign --suite ui_build_accessibility --suite boss_trial
python tools/run_smith_route.py --engine /path/to/godot --native-gl --log-dir /tmp/smith-route
```

第二条在 Linux 可省略 `--native-gl` 使用软件 GL。runner 仅把已校验的种子复制到独占 `test_world_smith_route.json`；第二进程直接加载该路线的真实保存结果。不会替换玩家存档。

这份证据覆盖一位 Boss 的四招、战后能力与奖励回环，并非新档六区、多探索顺序、多契印、实体手柄、FPS、发行包或人工体验验收。其余五位 Boss、六位重试成本及人工可读性仍需验证。六区开发用完成横幅也仍需单独清理。46 项最终验收复选框保持未关闭。
