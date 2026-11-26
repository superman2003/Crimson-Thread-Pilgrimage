## 2026-11-26：补齐 WS-2 暂停菜单、手柄设置入口、标题/结局体验与工作台按需惰性化（G-04 / G-06 / G-07 / G-12）

- **目标**：关闭 1.0 玩家体验与运行态性能四项核心缺口：缺乏暂停菜单/手柄设置入口/关窗自动存盘（G-04）、标题页与结局体验粗糙（G-06）、设置页方向键误触音量/多手柄连战退出缺失（G-07）、`JourneyWorkbench` 后台常驻开销（G-12）。
- **改动**：
  - **G-04 暂停菜单与纯手柄闭环**：新增 `godot/scripts/pause_menu.gd`（`CanvasLayer` `layer=59`、`PROCESS_MODE_ALWAYS`，暂停 `SceneTree` 同时保持音乐播放且不触发 `ui_input_locked`，避免中断治疗引导），提供继续、设置、新旅途、保存并返回标题、保存并退出；在 `main_level.gd` 接入 `Esc` 呼出暂停菜单；在 `interface_bag.gd` 顶栏新增“设置 / 暂停菜单”按钮（手柄 `Start` 可达），在 `interface_settings.gd` 新增“新旅途 / 暂停退出”，并更新 `pilgrimage_interface.gd` 手柄快捷提示与布局宽度；在 `application_close.gd` 关窗前自动落盘活动世界存档与旅途计时。
  - **G-06 标题页、上次槽位与结局收束**：在 `title_card.gd` 增加存档槽 1–3 切换栏（显示地区/时长/状态）、底栏快捷入口（设置/语言/来源与许可）、主题化成就弹窗与平滑关闭；在 `level_save_slots.gd` / `level_world_start.gd` 记录并恢复玩家在界面显式切换的上次存档槽（无头模式与命令行 `--save-slot=` 不受影响）；在 `ending_story_desk.gd` 终幕尾页追加旅途摘要（完成度、游玩时长、守门者计数）与“来源与许可”按钮；在 `level_hud.gd` / `main_level.gd` 为 `win_label` 增加 5 秒后渐隐收起，不再永久遮挡画面。
  - **G-07 交互细节与多手柄修复**：在 `main_level.gd` 限定设置页 WASD/摇杆仅在焦点为空或位于音量滑条时调音量；在 `boss_rush.gd` 轮询全部 `Input.get_connected_joypads()` 并新增独立的 `QuitHint` 长按退出提示；在 `pilgrimage_interface.gd` 将 `tutorial_hints` 默认值统一为 `true`。
  - **G-12 `JourneyWorkbench` 惰性初始化与退出休眠**：在 `godot/journey/workbench.gd` 新增 `activated` 与 `background_recording`（默认 `false`，工作台顶栏提供“探索时后台记录”显式开关），启动及常规探索零模块加载、零 10 Hz 深拷贝采样、零附带磁盘写入，关闭工作台且无录制会话时自动停止轮询。
  - **双语与测试**：在 `godot/data/ui_en_game.json` 补齐 14 条新增 UI 英文译文；在 `godot/scripts/title_card_validation.gd` 增加暂停菜单不打断治疗与 `win_label` 自动渐隐回归验证。
- **验证**：
  - `npm test`、`npm run test:campaign`（`UI_TRANSLATIONS entries=12094 problems=0`、`EXPORT_AUDIT_PASS`）、`tools/build_ledger.py --validate`。
  - Godot 回归套件：`save_desk`、`settings_construction`、`settings_remap`、`input_prompt`、`ui_world_integration`、`first_court_experience`、`application_close`、`title_card_validation.gd`、`boss_rush_validation.gd`、`narrative_closure_validation.gd`、`journey/tests/world.gd`、`journey/tests/i_live_world.gd` 全部通过（0 失败）。
