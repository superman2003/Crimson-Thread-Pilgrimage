# U06 补充台账：界面快捷键重映射

对应 `docs/UPGRADE_TASK_LEDGER.md` U06 的界面保留键缺口。设置页从 17 个动作增至 20 个，新增行囊、地图和设置；仍保持五行四列。键盘与手柄分别替换，旧设备绑定保留，持久化、冲突提示与恢复默认共用既有策略。

地图中的世界总览切换读取行囊动作，不再硬编码 Tab；地图文字和 HUD 快捷按钮读取实时绑定与输入设备。Esc、F9、B / L3 继续承担关闭、另起旅途与构筑入口。释放的旧快捷键可用于其他动作，当前仍占用的快捷键按动作名称报告冲突。

验证：Godot 4.6.1 原生 GL 下 `settings_remap`、`input_settings_regression`、`input_prompt`、`inventory_map`；原始记录在 `artifacts/u06_overlay_shortcut_remap`。`npm test` 在 `PYTHONUTF8=1` 下通过。旧测试夹具原用 Start 代表不可映射键，现改用仍保留的 L3。

本批只关闭三个界面动作的改键缺口；完整实体手柄手感仍属 T04。未合并到 main 的既有升级由各自 PR 承载，本报告作为独立台账补充，避免改写它们的状态。
