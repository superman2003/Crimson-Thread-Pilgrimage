## 2026-11-27：优化 60Hz 运行期性能热点与旅途工作台手柄焦点/右摇杆滚动

- **目标**：消除深度审计定位的 60Hz 整棵 `story_flags` 深拷贝、HUD 战术卡与置顶条每帧清空回写导致的中文字形重排、发行版每帧同步磁盘 `stat()`、Boss AI 单帧多次重复射线扫描与离屏高频重绘，并补齐旅途工作台的手柄初始聚焦与右摇杆滚动支持。
- **改动**：
  - **NPC 世界态零冗余深拷贝**：在 `godot/scripts/world_narrative.gd` 的 `npc_world_state()` 中先检查 `world_states` 非空再调用 `_effective_flags()`，消除闲置游玩时 240–300 次/秒的全量 `story_flags` 深拷贝。
  - **HUD 与字幕零每帧重排/主题抖动**：在 `godot/scripts/interface_hud.gd`、`pilgrimage_interface.gd`、`heal_resource_readout.gd`、`danger_caption_groups.gd`、`danger_captions.gd` 中改为先算局部值再按需更新文本/提示/颜色覆写/元数据，并在关闭危险字幕时跳过 60Hz `enemy` 群组扫描。
  - **发行版零 60Hz 磁盘 `stat()` 与空数组排序清理**：在 `godot/scripts/world_routes.gd` 与 `world_prefetch.gd` 中对 `standalone` 发行版跳过 `res://` 的 `FileAccess.get_modified_time()` 轮询，去除同帧重复 `gameplay.synchronize()`；在 `world_gameplay_residency.gd` 与 `world_platform_residency.gd` 中跳过长度 ≤1 数组的 `sort_custom()` 闭包分配。
  - **Boss AI、房间查表与暗室/暗道绘制优化**：在 `godot/scripts/boss_behavior_brain.gd` 缓存单物理帧 LOS 与 `eligible_commands()`/`overdue_command()` 结果；在 `godot/scripts/map_overlay.gd` 为 `map_room_by_id()` 建 O(1) 字典索引；在 `godot/scripts/cave_world.gd` 复用单份 `PhysicsRayQueryParameters2D`；在 `godot/scripts/hidden_route_clue.gd` 常量化材质表并剔除离屏重绘。
  - **旅途工作台优化与手柄可达**：在 `godot/journey/workbench.gd` 用原始 `attached_save_path` 替换 10Hz `sha256_text()`、打开工作台时为当前侧栏模块按钮设置初始焦点；在 `godot/scripts/reading_scroll.gd` 将 `JourneyWorkbenchWindow` 纳入右摇杆滚动目标。
- **验证**：本地执行 `audit_ui_translations.py`、`test_ui_text_colors.py`、`audit_export_contents.py`、`build_ledger.py --validate`、`npm run test:campaign` 均通过。

CI 复验：更新负对照替换点，禁用重构后的材质分支，保留真实 GL 正向检查和语义失效验证。
