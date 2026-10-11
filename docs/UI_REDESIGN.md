# 归途手札界面重制

## 风格与覆盖

沿用绯线巡礼的遗物技艺、铜钟、针线、失声契约和找回名字的设定。使用墨青织物底、旧铜边线、骨白正文、绯红刻印；不改变已有契印名称、配装规则、获得条件、永久能力门或存档格式。

重制生命／能量／治疗／Boss 条、当前契印与四槽战斗 HUD、交互提示、拾取通知、分类背包、旅记、六页构筑、NPC 对话、地图外框、愿板、声音与无障碍、重映射和存档控件。框体和生命刻印由原创 Godot 绘图生成；沿用现有物品、肖像和契印图标。新旅途确认框继承公共主题。

## 布局与行为

- 1280×720 设计坐标按窗口等比居中；宽屏与 4:3 窗口覆盖全视口的暗幕，不拉伸图标。
- 生命刻印按实际最大生命生成；低生命以绯红线表示，数字保留精确读数。
- 四槽图标显示实际装备、当前槽、独立冷却及战具剩余次数。切换契印同步 HUD 图标。
- 菜单隐藏战斗卡片和快捷入口，保留运行时已有输入锁；关闭恢复。鼠标、键盘与手柄焦点沿用真实按钮路径。
- 详情、旅记及长对话保持滚动；字幕字号上限 26px。设置页用可读键名替代引擎事件字符串，完整重映射不删减。
- 能量、治疗和 Boss 条清除默认最小高度与内边距，保持细条布局。地图使用实际绘图区高度，避免与页脚相交。

## 验证

`npm test` 通过。Godot 4.6.1 隔离回归 7 组通过：ui_redesign、seal_ui、ui_build_accessibility、ui_world_integration、inventory_map、world_map、tests/verify_narrative_ui。新 UI 套件共 30 项，涵盖四种窗口比例、生命、细能量条、暗幕和输入锁；已加入默认 CI 列表。

实机捕获 17 张界面与状态截图，含六页构筑、背包、旅记、地图、设置、普通与 26px 对话、低血量、超宽窗口及动作。捕获采用隔离展示状态；图册见 [全部实机图](gallery/20261011_ui_redesign.md)。

额外尝试旧 map_readability 套件时，它在 start_ground 不存在处失败并发生空节点调用；用未修改的 main 基线复现同一失败。该旧测试不是当前 CI 默认套件，本改动未宣称它通过。截图进程退出偶有 ObjectDB 泄漏警告；七组隔离功能回归无 SCRIPT ERROR／ERROR。完整硬件手柄试玩与所有区域的人工审美验收尚未执行。

## 复现

```sh
godot --headless --path godot --editor --import
python3 tools/run_godot_regressions.py --engine godot --suite ui_redesign --suite seal_ui --suite ui_build_accessibility --suite ui_world_integration --suite inventory_map --suite world_map --suite tests/verify_narrative_ui
godot --path godot --audio-driver Dummy --script res://scripts/capture_ui_redesign.gd -- --capture-output=/absolute/output/directory
```

捕获脚本需图形显示环境，不支持 headless 截图。生成 PNG 原图；提交图册为 JPEG。
