## 2026-11-27：修复暂停菜单/首领连战软锁、标题页选槽与退出存盘完整性及显存/音频生命周期缺陷

- **目标**：修复深度审计发现的暂停菜单同帧重开、长按 Esc 退出首领连战永久暂停软锁、重复写档覆毁 `.bak` 前置备份、标题页槽位时长与切槽缺陷、首领连战退出丢失 2/3 号槽位、异步退场竞态及未使用贴图/缓存驻留问题。
- **改动**：
  - **暂停菜单与首领连战防软锁**：在 `godot/scripts/pause_menu.gd` 增加 `holding_pause`、`_exit_tree()` 兜底释放暂停、`closed_frame`/`pause_suppress_frame` 同帧防重开与输入清零、`JOY_BUTTON_START` 关闭支持及 `bgm_player` 暂停保活；在 `godot/scripts/main_level.gd` 阻止同帧重开与首领连战期间弹出暂停菜单；在 `godot/scripts/boss_rush.gd` 退出时强制清除暂停、保留并返回原 `world_slot`/`world_save_path`、为结算窗挂载 `dialog_focus_bridge` 并聚焦确认按钮、切换与退出时回收未使用角色贴图。
  - **存档与退出完整性**：在 `godot/scripts/world_state.gd` 先判断 `unchanged` 再决定是否覆写 `.bak`，保护有效前置备份；在 `godot/scripts/application_close.gd` 新增 `request_close(skip_save)` 并跳过 `TitleCard` 在场时的退出存盘，杜绝退出双写档、“不保存直接退出”仍写盘及标题页退出误建 1 号空槽；在 `godot/scripts/level_save_slots.gd`、`level_world_travel.gd`、`journey_progress.gd`、`level_journey_data.gd` 修复 `restore_save_backup` 未记 `last_slot`、`select_save_slot` 缺空指针守卫与启动选槽误写 1 号槽、坏格式游玩时长被覆写为 0 以及 `new_journey_dialog` 默认聚焦破坏性确认键问题。
  - **标题页显示与语言引导**：在 `godot/scripts/title_card.gd` 修复 `_slot_summary` 读取 `play_seconds` 与紧凑两行格式（不再恒显 `0:00` 或 3 行溢出/英文漏中），中文态语言按钮增加 `/ EN` 提示，保持 `bgm_player` 在标题页持续播放；在 `godot/scripts/audio_game_state.gd` 暂停时冻结音频状态轮询。
  - **异步退场与显存/缓存回收**：在 `godot/scripts/world_passage.gd`、`level_travel_async.gd`、`loader_transitions.gd`、`loader_staging.gd`、`loader_startup.gd`、`world_region_loader.gd` 修复 `_exit_tree()` 期间未守卫的 `await` 唤醒、回滚失败误恢复 `process_mode`、启动与取消预建后释放 `region_texture_hold` 并补齐手柄 B 取消切区；移除 `godot/scripts/chapter_terrain.gd` 未使用的 `terrain_atlas.png` 加载并避免空数组排序；清理 `hand_drawn_assets.gd` `texture_failures`、为 `world_atlas.gd`/`world_rock_material.gd` 增加安全解析与 `clear_caches()`，并在 `level_activation.gd` 切章前释放旧场景音频。
- **验证**：本地执行 `title_card_validation.gd`、`boss_rush_validation.gd`、`audit_ui_translations.py`、`test_ui_text_colors.py`、`audit_export_contents.py`、`build_ledger.py --validate`、`npm run test:campaign` 均通过。

CI 复验：补齐首领连战、标题页和成就隔离工程的脚本依赖。切区不再预热仅供内容审计的旧地形图集；运行时仍要求复用实际渲染材质。
后续集成复验：六区运行时的岩体使用共享墨绘材质，不预热按区的旧岩体贴图。保留背景、平台和装饰三个真实区域资源，并分别核对建区复用、两邻区缓存和旧请求退场。云机定向运行 `world_async_loading` 479 项、`world_streaming` 3218 项均通过。

连战在目的场景正式发布后才释放旧角色贴图；连战退回异步世界也保留新目的区域，不依赖结果窗是否已关闭。标题语言切换的双语文案正式登记。
