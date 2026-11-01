# R01：普通偏好文件可恢复替换

输入 main：`63981173d0a357c4dc0249d2d8bb0f5546522f43`。认领 #419；不含其他 agent 的未合入功能。

固定 `.pending.tmp` 改为 PID 与随机标记的独立暂存文件。原有 ConfigFile 全字段／InputEvent 回读校验保留。新协议按路径发布非空锁目录，竞争者不覆盖锁；只回收确定已退出的锁拥有者。旧目标先移到备份，安装失败尝试恢复；恢复失败保留备份，下一次读取或写入恢复。安装目标均须不存在，不调用 Windows 的覆盖目标 rename。已完成安装但备份未清理时保留已安装目标，将旧字节另存。

范围补充：`pilgrimage_interface.gd::_load_accessibility` 仅增加读取前恢复调用两行。原认领说明避开界面主文件，但要让中断备份在默认值应用前恢复，此处接线不可省略；没有改界面布局或其他方法。其他开放 PR 未认领此方法。这个小范围扩展在功能 PR 中明确列出。

验证：Godot 4.6.1 原生隔离项目 26 项通过，真实文件／ConfigFile／InputEvent，涵盖错误候选、安装失败、恢复失败、竞争锁、独立暂存名、重试与中断恢复。原 `settings_persistence_validation.gd` 的 `filesystem_checks` 在同样最小项目执行，33 项通过。首轮新夹具 PackedStringArray.filter 解析失败，已改为 Array 后重跑通过。零 SCRIPT ERROR／ERROR。

运行：`python tools/run_reliability_98fd8e2f_r01.py --engine <Godot4.6.1> --log-dir <logs>`。独立 CI 工作流运行同一生产代码夹具，不改变旧回归门禁。

限制：未跑完整 World UI 与旧 UI 验证部分；Linux 本地结果不代替 Windows 故障实测、硬断电或最终发布包验收。锁恢复对不确定平台／PID 存活状态保守拒绝，不以超时强抢活锁。46 项最终验收仍 OPEN。
