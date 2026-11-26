## 2026-11-26：修复 WS-1 显存驱逐、导出瘦身、开源合规与存档原子回滚（G-01 / G-02 / G-03 / G-05）

- **目标**：关闭 1.0 上线审计中的四项阻断/高危缺口：跨区切换显存只增不减（G-01）、导包携带 ~682 MiB 废弃素材与 MetSys 编辑器插件（G-02）、字体/第三方署名冲突与 macOS 候选包合规缺口（G-03）、Windows 原子覆盖失败回滚（G-05）。
- **改动**：
  - **G-01 显存驱逐与真实统计**：在 `godot/scripts/hand_drawn_assets.gd` 新增 `collect_region_assets` / `evict_unused_region_assets` / `cache_stats` / `clear_caches`；在 `loader_region_state.gd` / `loader_transitions.gd` / `loader_staging.gd` 发布新区域后保留当前区、预构建区与预取区贴图并驱逐已离开区域的生物/NPC/技能特效图集与帧缓存；在 `application_close.gd` 退出时清空静态缓存；扩展 `world_residency_inventory_validation.gd` 拆解 `AtlasTexture` 与 `AnimatedSprite2D` 并验证六区遍历后缓存有界。
  - **G-02 导出瘦身与审计扩展**：清理 `godot/scripts/main_level.gd` 与 `godot/data/demo_ch*.json` 中残留的旧版图集路径；三端 `godot/export_presets.cfg` 与 `tools/build_release.py` 同步排除废弃生物图集、历史生成目录、旧第三方图集与 MetSys 编辑器/未用主题资源；扩展 `tools/audit_export_contents.py` 覆盖 `addons/MetroidvaniaSystem` 脚本/场景并拦截废弃素材进入导出包。
  - **G-03 许可合规与 macOS 对齐**：统一 `THIRD_PARTY_NOTICES.md`、`godot/assets/NOTICE.md` 并以字节精确模式重建 `godot/data/credits/`；`tools/build_release.py` 自动收录 `OFL-NotoSerifCJK.txt` 并在烟测中隔离 `HOME`；`tools/build_macos_candidate.py` 补齐 `Contents/Resources/legal/` 许可文件、引擎许可证、ad-hoc `codesign`、`ditto` 归档与 `smoke_package` / `smoke_save_contract` 校验；`.github/workflows/release-candidate.yml` macOS 任务同步运行导出与存档合同测试。
  - **G-05 Windows 覆盖失败回滚**：在 `godot/scripts/world_state.gd` 的 `_write_candidate_locked` 中新增 `_rollback_primary_from_backup()`，当主档替换失败且主档丢失或受损时自动由已校验的 `.bak` 还原；在 `godot/scripts/save_recovery_validation.gd` 增加 `install_failure_rollback` 回归测试。
- **验证**：
  - Python & npm：`audit_export_contents.py`、`test_export_audit.py`、`build_credits_catalog.py --check`、`test_credits_catalog.py`、`test_release_builder.py`、`test_build_macos_candidate.py`、`test_release_save_contract.py`、`build_release.py --check`、`npm test`、`npm run test:campaign`、`npm run test:runtime-assets`、`tools/ci/contracts.py lint` 全部通过。
  - Godot 回归套件：`world_residency_inventory`、`world_staged_build`、`world_streaming`、`world_passage`、`save_recovery`、`character_art_prewarm`、`audio_retirement`、`application_close`、`boss_behavior` 全部通过（0 失败）。
