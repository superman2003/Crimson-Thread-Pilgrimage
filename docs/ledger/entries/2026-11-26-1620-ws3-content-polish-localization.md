## 2026-11-26：完成 WS-3 世界内容收敛、结局门原创美术升级与英文译文精校守卫（G-08 / G-09 / G-11）

- **目标**：关闭 1.0 审计中内容穿帮（G-08）、结局三门旧占位图（G-09）与英文机翻硬伤/术语分裂/硬编码中文标题（G-11）三项体验缺口。
- **改动**：
  - **G-08 世界内容一致性与 CH06 愿板闭环**：
    - 移除 `demo_ch02..06_*.json`、`world_routes.json`、`progression_plan.json` 中的玩家可见“试玩章”字样；修正 CH04↔CH05 传送门与 CH02 炉底重复的“铸渣滑道”命名（改为“断根栈道”）；清理 CH01 悬空的 `npc_bellway_weaver` 引用，将 CH01/CH02 封存钟骨站与废弃滑道文案收敛为“已停运/已塌封”遗迹口径，并同步 `tools/handcraft_ch01_*` / `handcraft_ch02_*` 生成脚本；清理 CH04 剧情与 Boss 提示中未实现的“花粉风/花粉过滤器”穿帮描述。
    - 为 CH06 两条原不可完成愿板接入真实逻辑：在 `world_narrative.json` 为 `npc_crown_tongue` 新增 `tongue_pain` 证词状态置位 `quest_tongue_pain_done`（+200 碎钱）；在 `level_hud.gd` 与 `level_rooms.gd` 新增 CH06 五间回声室无伤通过追踪置位 `quest_echo_perfect_done`。
    - 在 `tools/validate_world_narrative.py` 新增内容防回归断言（零“试玩章”、零 `npc_bellway_weaver`、所有 `wish_board` 的 `target_flag` 必须有运行期置位方）。
  - **G-09 结局三门原创美术升级**：
    - `godot/scripts/ending_gates.gd` 改为调用 `_apply_original_prop` 使用原创手绘拱门图集 `original_interactables/atlas.png`（不再直接加载旧 `gothicvania/demo/boss_gate.png`），并为重鸣 / 断冠 / 绯线改写三扇门分别绘制独立徽纹（`EndingGateCrest`）与光环轮廓；`level_props.gd` 同步优先使用原创图集，避免冗余加载旧占位图。
  - **G-11 英文精校、术语统一、动态窗口标题与审计守卫**：
    - 精校 `ui_en_{hints,journal,story,game}.json` 中所有反义/机翻条目（4 处 `Invincible group`、“不推定为空槽”反义译文、13 处钟误译为 `clock`、`Candle Caster`/`spork master`、`bell fingers`、`Slow subtitles for large characters`、全角中文标点），移除被正则抓取的 `"长按 E(?![A-Za-z0-9_])"` 脏键（同步拆分 `authored_control_hints.gd:15`），并全表统一 `Rain Foundry`、`Saltwhite`、`Bell Shrine`、`Tool slot`、`charm`、`Matriarch` 核心术语。
    - 在 `ui_language.gd::apply()` 接入 `DisplayServer.window_set_title()` 动态切换中/英 OS 窗口标题；修复 `journey/fieldwork/vector.gd` SVG 报告 `<title>` 英文翻译键；更新 `main_level.gd` 过时的旧版英文兜底操作说明。
    - 在 `tools/audit_ui_translations.py` 新增语义反义、机翻黑名单、全角标点与术语漂移守卫及 `--self-test` 覆盖；在 `ending_aftermath_validation.gd` 新增结局门原创图集与 CH06 双愿板闭环断言。
- **验证**：
  - `python tools/audit_ui_translations.py --self-test`、`python tools/audit_ui_translations.py`（`entries=12104 problems=0`）、`npm test`、`npm run test:campaign`、`npm run test:trap-free`、`npm run test:runtime-assets`、`python tools/build_ledger.py --validate` 全部通过。
  - Godot 回归套件：`ending_aftermath`、`narrative_closure`、`map_directory`、`world_integration`、`world_passage`、`ch02_demo`、`all_chapters_demo`、`ch06_hidden_route_validation.gd`、`display_settings_validation.gd` 全部通过。
