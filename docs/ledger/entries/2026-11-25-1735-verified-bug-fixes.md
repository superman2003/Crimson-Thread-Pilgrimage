## 2026-11-25：修复实机与全仓审查发现的游戏、世界加载、本地化与工具缺陷（跨任务缺陷修复）

建立跨章节的缺陷修复 PR，覆盖以下已核实并附带回归验证的缺陷：

- **玩家与战斗系统**：修复冲刺/技能取消后的无敌与碰撞残留、`shockwave` 钟压叠加覆盖分支 B `0.4s` 硬直、`cleave` 误继承上下瞄准方向、`try_resonance` 误继承 `attack_2` 伤害、Boss 试炼重置与半血转阶段时 `vault` 滞空悬停、敌人攻击/追踪弹地形检测未排除全部 `"player"` 分组节点、盐雾遗漏 `"mortar"` 类型、小怪 `"blink"` 未经地形扫描防穿墙，以及模拟训练场治疗回血被误计入受击次数。
- **世界切换、异步加载与存档安全**：修复分段预加载取消时异步卸载覆盖玩家后续 `world_state`/`build_system` 状态、预加载期间子 `AudioDirector` 抢占全局单例及退场误静音源区域音频、`world_region_loader` 空闲时残留 `process_frame` 监听、`manifest_refresh_running` 竞态与取消检查、`config_read_job` 重复预取、`level_region_build` 误调私有 `_data()`；修复 `level_journey_data` 删除主存档先于归档 `.bak` 备份的顺序风险、`F9` 新旅途快捷键在打开其他界面时穿透触发，以及 `settings_profiles_desk` 应用旧版设置方案未传递补全后快照。
- **本地化与文本**：全面修复 `godot/data/ui_en_game.json`（`milestones/model.gd` 38 条）与 `godot/data/ui_en_story.json`（`demo_ch01`/`demo_ch02`/`demo_ch05`/`world_routes` 及残留条目共 90 条）整批错位/残缺的英文译文，并在 `tools/audit_ui_translations.py` 增补语义回归守卫。
- **工具与 CI 健壮性**：修复 `tools/godot_suite_success_markers.json` 重复 `"achievements"` 键、补齐 Windows Python 文本 UTF-8 编码审计、修复 `tools/ci/contracts.py` 无 `--include` 的 `hydrate_runtime_assets.py` 默认全仓拉取 LFS 问题及 Windows 8.3 短路径兼容（同步更新 `map-group-framing.yml` / `spatial-ambience.yml` 显式 `--include`）、修复 `validate_demo_geometry.py` / `validate_generated_godot_runtime.py` 解析 `GROUND_MOTION.GRAVITY`，并使 `test_contracts.py` 与 `test_credits_catalog.py` 在 Windows 无符号链接权限环境下正确跳过 POSIX 专属测试。
