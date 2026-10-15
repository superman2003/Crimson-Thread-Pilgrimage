# 玩家战斗手柄反馈与清理

2026-10-15；U06 / V04 子项。核对当前 main `4b6ab8d` 后，本批沿上一交付
[PR #70](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/70)
`4e1f8d5380295026b1b1466285b456baaa9f1142` 继续堆叠，保留 #69 / #70 的连续工作。
相对该基线只占用 `player_controller.gd`、`player_haptics.gd`、
`player_haptics_validation.gd`、`player_state_cleanup_validation.gd` 和本说明。
不修改并行敌人攻击预警、地图图钉或 CH05 工房文件；不包含独立 PR #68。

## 反馈规则

现有设置已经保存 `vibration_enabled`，此前没有实际硬件输出。
新增 Player 子节点从同一玩家 accessibility 元数据读取开关，不增加设置字段或存档版本。
只有最后主动使用的已连接手柄能接收反馈；按键/鼠标按钮输入停止震动并清除手柄归属。
启动、断连后重连或没有使用手柄时，不自动选择任意设备。摇杆小幅噪声不取得归属。

| 触发 | 弱马达 | 强马达 | 秒 | 优先级 |
|---|---:|---:|---:|---:|
| 已确认普通命中 | 0.16 | 0.04 | 0.045 | 1 |
| 已确认击杀 | 0.30 | 0.12 | 0.075 | 2 |
| 实际非致死受伤 | 0.45 | 0.60 | 0.14 | 3 |

同级/更弱命中不重新开始或延长当前脉冲；更高优先级可替换，受伤反馈优先。
每次原生请求都有明确时长，服务同时以单调真实时间截止，不随 hitstop/time_scale 延长。
不改变伤害、攻击判定、资源消耗、技能时序或现有视觉反馈。格挡/忽略伤害不触发受伤脉冲。

菜单输入锁、死亡、重生/定位、休息与切区交接同步停止；节点离树时停止。
设置关闭、全树暂停及漏报断连在下一次服务处理停止；服务使用 ALWAYS 模式，暂停仍能清理。
断连信号立即清理；重新开启开关或重新连接不重放旧脉冲。

## 验证

Godot 4.6.1 / Mesa llvmpipe 真实 GL；沿现有 `player_state_cleanup` 入口接入专项，
没有修改共享回归登记。新增 **31 项**，与原清理测试合计 **40 项、0 失败**；
headless 同样通过。测试创建真实生产 Player 并检查子节点接入，随后使用真实 Player
确认命中/受伤/输入锁/重生/交接方法；仅硬件枚举、原生输出边界及单调时钟用记录适配器。
设置关闭与暂停清理使用实际处理帧验证，不只直接调用服务方法。

在 #70 基线上的 8 套不同相关真实 GL 回归通过：`player_state_cleanup`、
`player_upgrade_regression`、`player_action_buffer`、`melee_recovery`、
`seal_combat`、`input_settings_regression`（93）、`world_resume_regression`、`world_host`。
`npm test`、`npm run test:campaign`、两轮恢复模式资源导入与差异空白检查通过。
反向移除震动设置开关判断后，专项检测到 2 项失败；恢复后 40 项复验通过。

首轮在资源导入尚未结束时启动测试，断言虽通过但出现 MetSys 资源缺失/引擎错误，严格运行器判失败；
资源就绪后复跑通过。早期直接诊断使用已失效的显示服务，也未计为成功。
专项一度出现 ObjectDB 警告；verbose 列出的泄漏对象为 Ogg 音频/播放对象，
不是新增震动节点。对既有“表现禁用”测试夹具关闭声音后，专项复跑未再出现警告；
没有借此改动运行时音频或声称其长期稳定。
其它玩家/近战/世界宿主回归仍有 ObjectDB 退出警告，保持记录。

## 继承的失败与实机边界

CH05 `obsidian_experience` 本批真实 GL 仍为 **176 项、11 失败**，11 条失败标签与
此前未修改的 #69 基线逐项一致（见 `INPUT_REMAP_RECOVERY_UPGRADE.md`）；未计为通过，工房文件未动。
远端完整 CI 需要按最终提交单独判定。

记录适配器验证的是输出指令、调度与停止契约，不能证明实体手柄确实震动或震感舒适。
Windows/Linux 实体手柄的驱动支持、强弱马达体验与长期切换仍待人工验收；未运行六区自然通关或全套回归。
本地逐套记录保留在工作区 `haptics-logs/`。复验命令：

```sh
python3 tools/run_godot_regressions.py --engine <Godot-4.6.1> --software-gl \
  --suite player_state_cleanup --suite player_upgrade_regression \
  --suite player_action_buffer --suite melee_recovery --suite seal_combat \
  --suite input_settings_regression --suite world_resume_regression --suite world_host
```
