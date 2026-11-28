## 2026-11-27：修复工具链可移植性、导出包冗余素材、许可声明与 CI 卫生问题

- **目标**：清理全仓库工具脚本中的本机绝对路径与 UTF-8 BOM 缺陷，加速导出审查并排除未引用冗余素材，补齐第三方许可声明与 macOS 玩家指南，收紧 CI 权限/超时并为 `push: main` 合约补齐路径过滤以降低无效 runner 消耗。
- **关键改动**：
  - **音频构建工具可移植性**：`tools/generate_music_pack.py`、`tools/generate_ambience_pack.py`、`tools/generate_sfx_pack.py` 移除硬编码桌面 `ffmpeg.exe` 路径，改为按 `CTP_FFMPEG` 环境变量与 `PATH` 解析并在缺失时给出明确报错。
  - **Python 源码编码卫生**：去除 `tools/build_boss05_directional_assets.py` 与 `tools/validate_boss05_directional_assets.py` 的 UTF-8 BOM，并在 `tools/audit_python_text_encoding.py` 中新增 BOM 禁止校验。
  - **地图蓝图校验可移植性**：将 `artifacts/map_blueprints/silksong_scale/map_blueprint_index.json` 中的个人绝对路径替换为仓库相对路径并补齐 6 张房间细节图册条目；`tools/validate_silksong_scale_map_blueprints.py` 支持相对路径解析并兼容现行蓝图结构。
  - **导出审查提速与打包瘦身**：`tools/audit_export_contents.py` 预编译联合 `class_name` 正则与 `filter_matches()` 缓存正则，并扩展 `DYNAMIC` 检测至 `journey/`；`tools/build_release.py` 复用 `export_presets.cfg` 公共排除规则避免 staging 复制与导入已排除文件；`godot/export_presets.cfg` 三平台排除已实测未被引用的 7 个 NPC 旧 `motion_expanded.png`（15.91 MiB）、`bronze_moth/motion_v8_01.png`（0.70 MiB）、`assets/sprites/demo/*` 与非运行期 `*_generation.json`/`generation_manifest.json`（合计瘦身约 22.3 MiB）。
  - **第三方许可与玩家指南同步**：修正 `THIRD_PARTY_NOTICES.md` 与 `godot/assets/NOTICE.md` 中失效路径并补齐 Kenney 音频包、Beehave/MetroidvaniaSystem/Godot Platformer 2D、Noto Serif CJK、ElevenLabs 音乐与战斗音效、印记与虫语语音条目；运行 `tools/build_credits_catalog.py` 同步 `godot/data/credits/`；在 `docs/RELEASE_PLAYER_GUIDE.md` 补充实验性 macOS 通用包说明与存档路径。
  - **CI 卫生与成本优化**：扩展 `tools/ci/contracts.py` 的 `godot_installer()` 检测并在 `tools/ci/workflow_allowlist.json` 登记 `ledger-u06-build-shortcut.yml`；将 `.github/workflows/ledger.yml` 的 `contents: write` 收紧至 `render` 任务并补充 `timeout-minutes`；修复 `ledger-u06-audio-volume-save.yml` 在 Ubuntu/Windows 矩阵的 Python 命令并补齐 `push.paths`；为 58 份带 `push` 的合同镜像 `pull_request.paths`，并为 10 份 `reliability-98fd8e2f-r01..r10.yml` 合同补充 `timeout-minutes: 10`。
- **验证**：本地通过 `contracts.py lint`、`test_contracts.py`、`audit_python_text_encoding.py`（含 `--self-test`）、`test_export_audit.py`、`audit_export_contents.py`、`test_release_builder.py`、`test_build_macos_candidate.py`、`test_credits_catalog.py`、`build_credits_catalog.py --check`、`test_lfs_cache_workflows.py`、`test_integration_workflow.py`、`test_build_shortcut_runner.py`、`validate_silksong_scale_map_blueprints.py`、`build_ledger.py --validate`、`test_build_ledger.py` 与 `build_release.py --check`。

发布门复验：Kenney 插件示例主题、场景及其未用贴图一并从三端暂存／导出排除，只保留运行时用到的 `Symbols/Save.png` 及其导入配置。按真实文件树测试三个预设及发行暂存，不压低导出审计。行程交接夹具的后台加载等待另开提交。
