# 输入重映射与配置恢复一致性

2026-10-15；基线为 [PR #69](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/69)
`d446606a525c2968e19bbf3213b9d4e5589e7ba9`。本批推进 U06 子项。
仅占用本说明、`input_binding_policy.gd`、`pilgrimage_interface.gd` 和
`input_settings_regression_validation.gd`。不修改 CH05 工房、地图图钉、存档业务或全局反馈。
PR #68 不在本批基线内；不借本批覆盖或撤销该独立改动。

## 玩家行为

- 现场重映射与配置加载共用输入规范化、保留键和玩法冲突检查。逻辑键码与物理键码均检查界面保留键；Esc 仍用于取消。
- 键盘、鼠标、手柄分别替换；鼠标按钮现在也可在现有重映射入口捕获。替换其中一类时保留其余类别。提示文字同步列出鼠标输入。
- 配置中的有效事件先按类别分组。无效事件不会抹掉该类别原有绑定；缺少的类别和空/损坏数组保留当前可用控制。配置恢复提示显示在现有状态行。
- 冲突检查基于完整候选映射，允许有效按键互换，避免顺序加载将正常配置误判为冲突。两个动作争用同一输入时，双方对应类别均回退；回退后出现的新冲突继续检查到稳定。
- 固定移动/能力动作同样参与冲突检查；UI 导航及关闭面板动作沿用现有豁免。手柄按钮与轴属于同一替换类别，但轴的正负方向分别比较。
- 保存的有效手柄绑定规范化为任意设备编号；保留的现有绑定不被改写。实体设备断连取消与当前帧输入闸沿用。
- 加载不自动重写用户配置；下次正常保存才写入当前安全映射。设置文件格式与游戏存档格式不变。

## 验证结果

Godot 4.6.1、Mesa llvmpipe/OpenGL；使用现有默认 `input_settings_regression` 入口，
未增加共享套件登记文件。输入专项从 32 项扩展至 **93 项，0 失败**。
覆盖逻辑/物理保留键、手柄保留按钮、混合损坏配置、类别保留、现有设备编号保留、
有效互换及重载、重复配置冲突与级联回退、逻辑/物理同键冲突、重复事件去重、
鼠标现场替换及重载、手柄设备变化与轴方向。原取消、断连、焦点恢复和非有限值测试保留。

最终 6 套相关真实 GL 回归全部通过：
`input_settings_regression`、`ui_build_accessibility`、`ui_redesign`（30）、
`player_action_buffer`（32）、`player_upgrade_regression`（46）、`ui_world_integration`。
输入专项另以 headless 运行 93 项通过；该模式按物理键码回退比较，不调用不存在的键盘布局服务，
不能代表真实桌面键盘布局验证。两轮恢复模式资源导入、`npm test`、
`npm run test:campaign` 和差异空白检查通过。

反向验证：仅移除配置加载时的保留键拦截，输入专项出现 19 处失败；恢复实现后最终专项通过。
首轮新增夹具将原绑定限制为手柄设备 0，却用其他编号断言其保留，导致 5 项失败；
夹具已改用通配设备，并新增单独断言保证特定设备的既有绑定原样保留。
首次 headless 试跑因调用不受支持的布局转换 API 出现 3 条引擎错误；
已增加 headless 分支，最终真实 GL/headless 均无该错误。严格运行器未放宽。

## PR #69 基线失败，未计为通过

候选分支与恢复全部已修改既有脚本后的原始 PR #69，分别运行真实 GL
`obsidian_experience`，均得到 **176 项、11 失败**；11 条失败标签逐项一致。
包含上层平台/第二缓存移动 2 项、奖励/货币/返程持久性 5 项、房间/地图矩形与入口出口契约 4 项。
这不是通过结果，也没有据此声明工房可玩验收完成。工房文件归原批次处理，本批不修改。

早期相关玩家套件与上述 CH05 套件曾报告 ObjectDB 退出警告；最终六套相关复验未出现该警告，
不据此声明长期内存稳定。未执行全套回归、Windows 实体手柄操作或多语言键盘布局人工验收。
远端完整 CI 必须按新 PR 的最终提交独立判定；本批不自动合并。

本地逐套日志保留于工作区 `remap-logs/`。复验命令：

```sh
python3 tools/run_godot_regressions.py --engine <Godot-4.6.1> --software-gl \
  --suite input_settings_regression --suite ui_build_accessibility \
  --suite ui_redesign --suite player_action_buffer \
  --suite player_upgrade_regression --suite ui_world_integration
```
