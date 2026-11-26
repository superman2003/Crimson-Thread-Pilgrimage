# 全项目 v1.0 发布差距与欠缺审查清单（2026-11-26）

- **审查基线**：`origin/main`（`44c84b100`）
- **审查范围**：核心玩法与内容完备度、玩家主流程与本地化、架构与显存/帧时性能、发行打包合规与 CI/测试治理
- **已由在途 PR 覆盖、本文不再重复列为阻断的事项**：
  - **PR #693**（`codex/verified-bug-fixes-20261125`）：128 条整批错位英文译文、分段预加载音频单例与取消回滚、战斗/Boss/存档顺序修复、`map-group-framing.yml`/`spatial-ambience.yml` 裸调 `hydrate_runtime_assets.py`、`godot_suite_success_markers.json` 重复键、`validate_generated_godot_runtime.py` `GROUND_MOTION.GRAVITY` 解析等。
  - **PR #695**（`fix/ci-hardening-and-release-safety`）：工作流超时加固、`prune_unreferenced_artifact_logs.py` 保护 `artifacts/**/*.json` 引用。
  - **PR #698**（`chore/prune-unreferenced-artifact-logs`）：清理 2,012 个未引用诊断日志/归档（163.26 MiB）。

---

## 执行分工总览（按优先级拆分为 5 条独立工作流，可直接指派 Agent 并行推进）

| 工作流 | 优先级 | 涵盖条目 | 核心交付物 | 预计收益 / 风险消除 |
|---|---|---|---|---|
| **WS-1 显存与发行包体/合规瘦身** | **P0** | `G-01`, `G-02`, `G-03`, `G-05` | `hand_drawn_assets` 切区淘汰 + VRAM 压缩；清理/排除 ~700 MiB 死素材与编辑器插件；补齐 macOS 许可与 `OFL-NotoSerifCJK.txt`；修复 Windows 写档回滚 | 6 区峰值显存 **2.87 GiB → <200 MiB**；发行 PCK 减重 **~700 MiB**；CI 冷导入缩短约一半；消除许可合规与 Windows 丢档风险 |
| **WS-2 玩家主循环、手柄闭环与工作台懒加载** | **P0–P1** | `G-04`, `G-06`, `G-07`, `G-12` | 独立标题/选槽/语言/制作人员入口；`Esc` 暂停菜单与关闭自动保存；手柄设置键绑定与重映射；`JourneyWorkbench` 改为默认隐藏 + 懒加载（消除后台 10 Hz 深拷贝/写盘）；结局演出与通关横幅收口 | 解决手柄/Steam Deck 无法进设置、关窗口丢进度、主线程每 0.1s 卡顿写盘及玩家 UI 暴露开发者工具问题 |
| **WS-3 内容穿帮清理、美术占位替换与英文精修** | **P1** | `G-08`, `G-09`, `G-10`, `G-11` | 清除 5 章/门标签“试玩章”；闭环或移除 CH06 两条死愿板、CH02 封存通道矛盾与花粉风文案冲突；替换结局门旧贴图与关键纯代码占位；清扫英文机翻反义与术语分裂 | 消除明显穿帮文案、不可完成任务、旧占位素材与英文反义翻译 |
| **WS-4 W00 Stage 7 + T04 真机长跑与六章实机收口** | **P1** | `G-13`, `G-14`, `G-15` | 消除切房 293 KB 深拷贝与无效 JSON 准备作业；Windows 实机 GPU + 实体手柄跑通全六区开伤害通关（双顺序 + 三结局）与长跑压测；收口 `UPGRADE_COMPLETION_CHECKLIST.md` 46 项人工验收 | 把 46 项台账从“仅无头自动化通过”真正收敛为真机可交付 |
| **WS-5 发行签名、仓库瘦身与 CI/测试降本** | **P2** | `G-16`, `G-17`, `G-18`, `G-19` | Windows 图标/版本元数据/签名、macOS 公证、文件日志与 Release 发布流水线；清理 14 份 `lfs: true` 与 CI 重复作业；治理 10.71 GB `.git`、剩余 1.13 GB `artifacts/` 及 104 个死脚本；补齐存档数值边界校验与真实 GPU/音频回归 | 降低 CI 机时与 LFS 配额消耗，打通正式分发链路，补齐测试与防篡改盲区 |

---

## 一、P0 级阻断项（公开发布前必须修复）

### G-01｜切区显存单调累积至 2.87 GiB（未压缩 RGBA8 + 永久静态缓存）
- **位置**：
  - `godot/scripts/hand_drawn_assets.gd:5-6`（`static var textures`, `static var frame_cache`）
  - `godot/scripts/character_art_warm_job.gd:26-125`
  - `godot/scripts/world_residency_inventory_validation.gd:130-137`
  - `godot/assets/sprites/{original_creatures,original_npcs,flat_maps,vfx}/**/*.import`
- **核实证据**：
  - 全量 `original_creatures`（396/396）、`original_npcs`（62/62）、`flat_maps`（35/35）、`vfx`（114/114）`.import` 均配置 `compress/mode=0`（Lossless 未压缩 RGBA8）。
  - 每次入区预热把该区所有敌怪/Boss/NPC/物品图集写入 `hand_drawn_assets.textures` 与 `frame_cache`，**无容量上限、无淘汰、连退出游戏都不清理**。
  - 实测 6 区累计驻留：**CH01 515.3 MiB → CH02 950.1 MiB → CH03 1,418.1 MiB → CH04 1,820.0 MiB → CH05 2,330.2 MiB → CH06 2,867.7 MiB VRAM**（255 张图集）。
  - `world_residency_inventory_validation.gd` 只检查节点 `texture`/`normal_map`，漏统计 `AnimatedSprite2D.sprite_frames`（`AtlasTexture.atlas`）与 `hand_drawn_assets.textures`，误报“每区 47–48 MB”。
- **修复建议**：
  1. 为 `hand_drawn_assets.gd` 增加按区域/引用计数的淘汰接口（在区域卸载完成且不在下一区/预取集合时释放旧区图集），并在 `application_close.gd` 统一清空。
  2. 评估将大尺寸角色/地图图集 `.import` 切为 VRAM 压缩（`compress/mode=2` BPTC/S3TC，压缩比约 4×–6×），在实机验证画质无明显色带后批量切换。
  3. 同步更新 `world_residency_inventory_validation.gd`，把 `SpriteFrames`/`AtlasTexture` 和静态缓存纳入显存预算统计。
- **验收标准**：连续走完 6 区后活跃纹理显存稳定在单区预算内（目标 < 250 MiB VRAM），`world_residency_inventory` 与真机 GPU 监控一致且无回退。

### G-02｜约 669–702 MiB 废弃素材与编辑器插件泄漏进每个发行 PCK
- **位置**：
  - `godot/export_presets.cfg:6-8, 26, 46`
  - `tools/audit_export_contents.py:154-167`
  - `godot/scripts/main_level.gd:174-269`（死引用表 `SPRITES` / `NPC_SPRITES` / `MOSSY_PLATFORM_TILES`）
  - `godot/project.godot:21-22`（`BeehaveGlobalMetrics`, `BeehaveGlobalDebugger`）
- **核实证据**：
  - 全部 46 个敌怪/Boss 已在运行时强制使用 `original_creatures/*/motion_redraw_manifest.json`（`enemy_lifecycle.gd:53-65`），25 位 NPC 均使用 `original_npcs/*/manifest.json`（`level_props.gd:347-360`）。
  - 但因 `export_filter="all_resources"` + `include_filter="*.json,*.txt,*.md"`，以下 **6,370+ 个文件（约 702 MiB 源素材）** 仍被打入所有平台 PCK：
    1. `godot/assets/sprites/original_creatures/` 194 张已被淘汰的旧 PNG（`motion_runtime.png` 147.8 MiB、`motion_expanded.png` 103.6 MiB、`atlas.png` 98.6 MiB、`hurt_death.png` 36.6 MiB、`special_motion_expanded.png` 16.8 MiB、`attacks.png` 15.5 MiB、`motion_repair.png` 14.0 MiB 等，合计 **440.4 MiB**）+ 300+ 个生成溯源 JSON + 58 个 `prompt.txt`/`README.md`；
    2. `godot/assets/sprites/bosses/`（2,423 文件，**177.25 MiB**，20 个备用 Boss）；
    3. `godot/assets/third_party/dark_fantasy_bestiary/`（2,832–3,472 文件，**26.4–29.9 MiB**）；
    4. `godot/assets/sprites/generated_supplements_20261017/`（26 文件，**24.65 MiB**，零引用）；
    5. `godot/assets/sprites/original_npcs/` 9 张旧图集（**19.69 MiB**）；
    6. `godot/assets/audio/bgm/generated/`（32 文件，**5.33 MiB**，零引用；线上用 `ai_generated/`）；
    7. `godot/assets/sprites/lumen/`（241 文件，**2.78 MiB**，零引用）与 `third_party/{kenney_*,godot_platformer_2d,gothicvania_cemetery}`（615 文件，**3.54 MiB**）；
    8. `godot/data/generated/*.generated.json`（6 文件，**1.90 MiB**，`GeneratedMain.tscn` 已排除但数据未排除）；
    9. `godot/addons/MetroidvaniaSystem/` 整套编辑器插件（`EditorExtension/`, `Database/`, `Themes/`, `Translations/` 421 文件）、`addons/beehave/{icons,debug}` 与 87+ 校验脚本 `.gd.uid` 伴随文件。
  - `tools/audit_export_contents.py` 仅扫描 `.gd`/`.tscn` 且放行 `addons/`，导致上述泄漏长期未被门禁拦住。
- **修复建议**：
  1. 清理 `main_level.gd` 死表 `NPC_SPRITES` 与无用旧 `SPRITES` 路径；将仍需存档的旧素材移出 `godot/` 或彻底从仓库移除；在 `export_presets.cfg` 与 `build_release.py` 中排除所有未用素材、编辑器插件子目录、校验 `.gd.uid` 和 `BeehaveGlobalDebugger`/`BeehaveGlobalMetrics` 自动加载。
  2. 扩展 `tools/audit_export_contents.py` 覆盖 `.png`/`.webp`/`.ogg`/`.json`/`.txt`/`.md`/`.gd.uid` 可达性审计。
- **验收标准**：三端 PCK 体积显著下降（释放 >650 MiB 源资源），`audit_export_contents.py` 通过且零 dead asset / 编辑器插件 / 调试单例进入发行包；CI 冷导入耗时显著缩短。

### G-03｜发行包开源许可与第三方署名合规缺陷
- **位置**：
  - `tools/build_macos_candidate.py:121-145` & `tools/test_build_macos_candidate.py:25-29`
  - `tools/build_release.py:63`
  - `THIRD_PARTY_NOTICES.md:30-31` & `godot/assets/NOTICE.md:27-31, 87`
- **核实证据**：
  1. **macOS 包零许可文件**：`build_macos_candidate.py` 直接打包裸 `.app`，未打包 `LICENSE`、`THIRD_PARTY_NOTICES.md`、`GODOT_ENGINE.txt`、字体/素材许可或 `BUILD_MANIFEST.json`（且 `test_build_macos_candidate.py` 的 `bundle_name()` 禁止与 `.app` 并列放文件，也未写入 `.app/Contents/Resources/`）。
  2. **Windows/Linux 静默丢弃当前字体 SIL OFL 1.1 协议**：`build_release.py:63` 仅匹配 `path.stem.lower() in {'license', 'notice', 'ofl', 'public-license'}`，漏掉了当前生效字体的 `godot/assets/fonts/OFL-NotoSerifCJK.txt`，却打进了已排除字体的 `OFL.txt`；而 `THIRD_PARTY_NOTICES.md:30-31` 明确声明附带 `OFL-NotoSerifCJK.txt`。
  3. **署名自相矛盾与漏列**：`godot/assets/NOTICE.md:27-31` 声称“仓库已无 Bread Adventure 音频”与同文件 L87 矛盾；根 `THIRD_PARTY_NOTICES.md` 漏列 `Bread Adventure`（Apache 2.0）及后期 8 个 AI 生成资源包（`thread_doll_v1`, `character_motion_v8`, `creature_redraw_v1`, `enemy_transitions_v1`, `minor_enemy_skills_v4`, `boss_motion_v6`, `attack_effects_v1`, `npc_insect_language_v1`）。
- **修复建议**：
  1. 修正 `build_release.py` 匹配规则（如 `stem.startswith('ofl')` 或复用 `build_credits_catalog.py` 清单），确保 `OFL-NotoSerifCJK.txt` 必打入三端包；
  2. macOS 发行包将许可目录、`README.md` 与 `BUILD_MANIFEST.json` 写入 `.app/Contents/Resources/legal/`（或顶层归档并同步更新 `test_build_macos_candidate.py`），并在 `release-candidate.yml` 为 macOS 启用 `audit_export_contents.py` 与完整 `smoke_save_contract`；
  3. 核对并统一 `THIRD_PARTY_NOTICES.md` 与 `godot/assets/NOTICE.md`，补齐 Apache 2.0 文本与全部在用素材来源。
- **验收标准**：Win/Linux/macOS 三端候选包均包含完整许可文件与 `OFL-NotoSerifCJK.txt`，单测校验通过。

### G-04｜手柄玩家无法打开设置页，且缺少游戏内暂停/退出/关闭自动存档
- **位置**：
  - `godot/scripts/level_audio.gd:45-51`、`godot/scripts/interface_settings.gd:471-482`、`godot/scripts/input_prompt_bindings.gd:55-60`
  - `godot/scripts/main_level.gd:845-858, 893-908`、`godot/scripts/application_close.gd:27-46`
  - `godot/scripts/player_controller.gd:451-458`、`godot/scripts/level_overlays.gd:143-150`
- **核实证据**：
  1. `audio_settings` 仅绑定 `KEY_V`，零手柄按键绑定；手柄连接时 HUD 仍提示 `"键盘 V 设置"`；同时默认手柄键位反直觉（`START`=背包，`BACK/SELECT`=交互，`L3/R3`=构筑/地图）。
  2. 游戏内无覆盖层时按 `Esc` 没有任何反应；关掉启动标题卡后游戏内无任何“暂停 / 返回标题 / 保存并退出”按钮。
  3. 点击系统窗口 `X` 触发 `application_close.gd` 时只停树、清音频、释放节点并退出，**未调用 `_save_world()` 或刷新 `journey_clock`**，静默丢失最近一次自动存盘之后的游玩进度与时长。
  4. 打开任意覆盖层不暂停树而设置 `ui_input_locked = true`，会在 `player_controller.gd:454-455` 立即触发 `_interrupt_heal()`（扣光预留治疗绯线）并取消灯影相位。
- **修复建议**：
  1. 设计标准暂停菜单（键盘 `Esc` / 手柄 `START`），提供“继续 / 背包 / 地图 / 构筑 / 设置 / 切换槽位 / 返回标题 / 保存并退出”；调整手柄默认交互键为常规按键（如 `RB`/`Y`/`Up` 等）并确保所有功能键均可在手柄上无障碍到达。
  2. 在 `application_close.gd` 退出前（非损坏阻止存盘状态下）安全刷写 `_save_world()`。
  3. 仅在真正进入暂停时冻结动作计时而非强制打断正在引导的治疗。
- **验收标准**：纯手柄玩家可从启动到通关完成全部菜单/设置/选槽/退回标题/退出流程；窗口关闭后重开保留最后一次安全进度与时长；覆盖层暂停回归测试通过。

### G-05｜Windows 正常写档缺少改名失败回滚保护（潜在主档丢失）
- **位置**：`godot/scripts/world_state.gd:213-216`（对比 `409-416`）
- **核实证据**：`_restore_backup_locked` 针对 Godot 4.6.1 在 Windows 上 `DirAccess.rename_absolute` 报错前可能先删除目标文件的行为做了回滚保护，但正常保存路径 `_write_candidate_locked` 未加同类回滚，一旦 Windows 文件锁/杀软导致改名失败，主存档可能丢失。
- **修复建议**：将 `_restore_backup_locked` 的安全回滚策略抽成共用原语应用于 `_write_candidate_locked`，并在 `save_recovery_validation.gd` / `test_release_save_contract.py` 补失败注入用例。
- **验收标准**：写档改名失败时主存档或 `.bak` 必保留完整字节，且回归单测通过。

---

## 二、P1 级欠缺：玩家体验、未完结世界内容、美术占位与本地化

### G-06｜缺少正式标题页、存档槽选择器、结局演职员表与多结局回看
- **位置**：
  - `godot/project.godot:9-10`、`godot/scripts/title_card.gd:6, 20-97`、`godot/scripts/main_level.gd:560, 821-829`
  - `godot/scripts/ending_gates.gd:137-218`、`godot/scripts/ending_story_desk.gd:1-150`、`godot/scripts/level_hud_build.gd:66-72`
  - `godot/scripts/player_damage.gd:74-95`
- **核实证据**：
  - 启动直接加载整张 CH01 槽 1 场景（不记住上次使用的槽 2/3），`TitleCard` 缺选槽、缺设置/语言（首次启动不读取系统语言，非中文玩家需先开档再摸索到“设置→显示”切英文）、缺制作人员表，且 `static var shown` 导致一生仅弹一次。
  - `TitleCard` 上的成就窗口挂载在 `CanvasLayer` 而非主题容器上，渲染为 Godot 默认灰丑主题（`title_card.gd:88-90`）。
  - `F9` 开新旅途硬编码且无设置页入口（当槽 1 损坏且阻塞切换槽位时，手柄玩家陷入死局）。
  - 结局只用 `ConfirmationDialog` 翻几页纯文本，无演职员表、通关统计、NG+ 或同档体验其余两结局；`win_label` 点亮后直到离区都不会消失。
- **修复建议**：
  1. 独立主菜单/标题页场景（选 3 槽位含缩略信息、继续/新旅途、首领连战、设置与顶层语言切换、成就、制作人员、退出），记住最近槽位；首次启动按 `OS.get_locale()` 预选或弹出语言/无障碍首启引导。
  2. 为结局补全专属全屏演出 + 演职员滚动 + 通关数据汇总 + 自动淡出的 `win_label`；在设置页/选槽页提供显式“新旅途”按钮取代隐藏 `F9`。
- **验收标准**：玩家可完整走通“首启选语言 → 标题选槽 → 通关结局演出与演职员表 → 返回标题切换槽位”闭环，全部 UI 统一应用项目主题。

### G-07｜玩家 UI 过度暴露开发者工具与桌面弹窗，且存在按键冲突
- **位置**：
  - `godot/project.godot:27`、`godot/journey/workbench.gd:151-212`
  - `godot/scripts/pilgrimage_interface.gd:134, 274-277`
  - `godot/scripts/main_level.gd:848-851, 863-871`
  - `godot/scripts/boss_rush.gd:87`、`godot/scripts/survey_map_view.gd:173-188`、`godot/scripts/map_player_pins_runtime.gd:66, 135`
- **核实证据**：
  - 30 个分析/开发模块（`JourneyWorkbench`，含原始输入日志、JSON diff、图割点、TSP 求解器、投资组合规划等）直接展示在设置页顶部；部分画布纯鼠标交互（`journey/caseboard/view.gd`、`journey/routes/view.gd`、`journey/photo/session.gd` 甚至弹出无主题原生 `Window`）。
  - 生产脚本中有 **59 处 `AcceptDialog`/`ConfirmationDialog`**、**32 处 `LineEdit`**、**13 处 `TextEdit`**、**3 处剪贴板依赖**，零 `DisplayServer.virtual_keyboard_show()` 调用。
  - 设置页打开时 WASD/左摇杆同时改动音量滑条（`main_level.gd:863-871`）；地图内 `Tab` 被劫持为切图；`boss_rush.gd:87` 长按退出硬编码手柄 `device 0` 且零屏幕提示；新手操作提示 `tutorial_hints` 默认为 `false`（`pilgrimage_interface.gd:134`）。
- **修复建议**：
  1. 将 `JourneyWorkbench` 移入“高级/巡礼研究工具”开关或开发者模式，默认不占据主设置页入口；收敛玩家必用流程中的嵌套原生弹窗与自由文本输入，为保留的 `LineEdit` 接入虚拟键盘或预设标签选择。
  2. 仅当焦点在音频滑条行时才响应音量增减；`boss_rush.gd` 遍历所有已连接手柄并在 HUD 显示长按退出提示；将 `tutorial_hints` 首启默认改为 `true` 并补齐 `build_menu`/`inventory`/`settings`/`归途结` 教学。
- **验收标准**：Steam Deck 1280×800 与标准手柄全程不卡焦点、不弹无主题原生窗口、不发生设置页误调音量。

### G-08｜世界内容穿帮：永久封存快旅/跨章通道、不可完成愿板、未实现花粉风与“试玩章”字样
- **位置**：
  - **钟骨长梯（五站快旅）**：`godot/data/demo_ch01_moss_bell_court.json:395-425, 6405, 7152`、`demo_ch02_rain_foundry_canal.json:772-798, 7474, 9512-9522`
  - **封存跨章口与路线标签矛盾**：`demo_ch02_rain_foundry_canal.json:1082-1086, 1601-1605, 9484-9510` vs `godot/data/world_routes.json:6256, 7030`
  - **不可完成 CH06 愿板**：`godot/data/demo_ch06_silent_crown_core.json:4581-4598`
  - **未实现花粉风/过滤器**：`godot/data/campaign_chapters.json:269, 308, 335, 340`、`godot/data/demo_ch04_broken_string_greenhouse.json:880, 3305`、`godot/data/item_lore.json:165, 214-223`、`godot/data/audio_visual_manifest.json:172, 3061-3079`
  - **“试玩章”文案**：`demo_ch02..06_*.json:3`、`world_routes.json:7125, 7569`、`export_presets.cfg:56-57`（`0.1`）
- **核实证据**：
  1. 宣传的“五站钟骨长梯”只在 CH01/CH02 有两间永远“未通电”的房间，且 CH01 引用了不存在的 `npc_bellway_weaver`。
  2. CH02 炉底“铸渣滑道”（对端 `slag_arrival` 不存在）与水塔“雨溢立管”（对端 `wet_cellar` 不存在）永久封存；同时 `world_routes.json` 又把“铸渣滑道”标签安在了 CH04↔CH05 传送门上。
  3. CH06 愿板 `wish_crown_tongue_pain`（`quest_tongue_pain_done`）与 `wish_echo_perfect`（`quest_echo_perfect_done`）全仓无代码置位，永远无法完成；CH02 有 `wish_board_landing` 房却无愿板条目。
  4. CH04“花粉风”与“花粉过滤器”仅存在于文案、图鉴和 `asset_ready` 音效中，无玩法实现；`item_lore.json:165`（`quiet_sole`）仍保留已撤除陷阱时代的旧说明。
  5. CH02–CH06 章节标题和两条旧支线门在玩家界面直接显示“试玩章”。
- **修复建议**：
  1. 决策并收敛叙事/玩法口径：对不打算做的封存车站/通道改写为已退役遗迹文案（或补齐连通），修正 `world_routes.json` 重复“铸渣滑道”命名与 `npc_bellway_weaver` 悬空引用；
  2. 为 CH06 两条愿板接入真实触发逻辑（或移除未实现条目）；
  3. 补齐花粉风机制与音效挂载，或将对应文案/条目从正式运行数据与 `audio_visual_manifest` 清理干净，并同步修正 `quiet_sole` 旧陷阱文案；
  4. 去除 CH02–CH06 章节名与路线门中的“试玩章”字样，同步升级项目与导出版本号。
- **验收标准**：新增数据一致性校验，确保零“试玩章”玩家可见文本、零无人置位的愿板 `target_flag`、零不存在的房间/NPC 引用。

### G-09｜关键场景与机关仍依赖旧占位贴图或纯代码几何绘制
- **位置**：
  - 结局三扇大门：`godot/scripts/ending_gates.gd:88-106`（直接加载旧 GothicVania `boss_gate.png` 着色 + `Line2D` 六边形）
  - 纯代码绘制物件：`cave_lift.gd:36-63`（7 座升降梯）、`level_ground.gd:74-81`（归途结）、`level_world_travel.gd:92-104`（钩环与链条）、`ending_aftermath_scene.gd:19-62`（18 处结局后景象）、`scene_history_prop.gd:78-163`（12 处遗迹）、`hidden_route_clue.gd:30-87`（8 处暗道线索）、`ability_gate_sign.gd:48-96` 与 `world_wayfinding.gd:115-225`（能力门/路标）
  - 复用拉杆贴图：`optional_challenges.gd:47-50, 109-112`（9 处挑战钟与 6 处追踪残迹共用 `lever_closed`/`lever_open`）
- **修复建议**：优先为**结局三门、挑战余响钟、追踪爪痕残迹、归途结、钩环、升降梯**替换手绘原创美术贴图；次优先级逐步升级场景遗迹与战后环境变化（`docs/ledger/status/N05.md`）。
- **验收标准**：运行期不再直接引用 `gothicvania/demo/boss_gate.png`，核心交互机关具备辨识度统一的原创贴图。

### G-10｜角色动画与音效覆盖缺口
- **位置**：
  - `godot/scripts/player_controller.gd:232`、`godot/scripts/player_abilities.gd:130`、`godot/scripts/seal_presentation.gd:32-33`
  - `godot/assets/sprites/original_creatures/*/motion_redraw_manifest.json`
  - `tools/creature_redraw_art.py:64-72`
  - `godot/data/audio_visual_manifest.json:193-204, 283-294, 787-798, 1570`、`docs/ledger/status/{B01,S02,S03,V02}.md`
- **核实证据**：
  1. **45 / 46** 敌怪/Boss 缺 `turn`/`brake` 帧（仅 `moss_larva` 完成）；**0 / 46** 有 B01 伏击/报警/支援专属动画；所有 46 个原生视觉敌怪受击时跳过 `hurt` 动画仅闪白（`enemy_actor.gd:551-555`）。
  2. 主角三契印（绯线/司铸/盐录）共用一套 `thread_doll_v1` 动作，无区分契印的挥刃/疗伤演出。
  3. **7 组重绘动作仍在质量豁免列表**（掉强调色 >45%：`bronze_moth` 4 组、`corridor_heavy/heavy_stamp`、`index_scribe/attack`、`saltwhite_contract_judge/windup`）；`docs/research/20261109_character_animation_checklist.md` 仍有 11 项未勾选。
  4. 25 位 NPC 仅有 4 个站桩态且仅 2 位有物理迁移；音效方面 `player_wall_jump` 占位复用 `player_jump.ogg`，`ch02` 室内外雨声切换无运行触发，仅 24 间房配置连续底声过渡。
- **修复建议**：先清掉 7 组质量豁免动作与 `player_wall_jump` 占位音，再按美术排期补齐三契印差异动作、重点敌怪转身/职责动画与其余房间环境声。
- **验收标准**：`tools/creature_redraw_art.py` 豁免列表清零；`audio_visual_manifest.json` 中占位/待接线项清零或明确退役。

### G-11｜英文译文机翻硬伤、术语分裂与硬编码中文标题（PR #693 修复错位后的剩余项）
- **位置**：
  - `godot/data/ui_en_story.json:251, 290, 1051, 1109, 1275, 1508-1509, 1575-1576, 2405-2406, 2443-2448, 2646`
  - `godot/data/ui_en_game.json:9, 71-72, 1432, 1730, 1797, 2383, 2499, 2523, 3098, 4268`
  - `godot/project.godot:9`、`godot/scripts/main_level.gd:72-172`、`godot/journey/fieldwork/vector.gd:245`
- **核实证据**：
  1. **严重反义/错译**：
     - `"无敌群压迫/安全工房无敌群"`（无敌人群）4 处错译为 `"Invincible group pressure"` / `"Invincible group in the safety workshop"`；
     - `"旧记录未说明；不推定为空槽"` 反义错译为 `"Old records are not specified; likely an empty slot"`（安全警告完全相反！）；
     - 13 处“钟（Bell）”误译为 `clock`（`old clockboard`, `buzzing sound of the clock hands`, `clock moths`, `Sleepless Clock`（把“沉睡”译成“不眠”））；
     - `"孢钟匠"` 译为 `"Candle Caster"` / `"spork master"`；`"钟舌"` 译为 `"bell fingers"`；`"大字慢字幕"` 译为 `"Slow subtitles for large characters"`；正则 `"长按 E(?![A-Za-z0-9_])"` 被错误抓取进译表；部分内部标志/灰盒开发文案（`boss_down_ch02`, `Automatically Generated Gray Box`）混入 `ui_en_story.json`。
  2. **术语分裂**：`Rainforge` / `Rain Foundry` / `Rain Cast`、`Saltwhite` / `Salt White`、`bell shrine` / `bell niche` / `Chime Shrine`、`Charms` / `ornament`、`Modify` / `Reform`、`Moss Bell Matriarch` / `Guardian Mother`、`Tools` / `Weapon slot`。
  3. **硬编码文本**：OS 窗口标题 `"绯线巡礼 - 互联世界"` 不随语言切换；`main_level.gd:72-172` 残留英文旧版操作说明（写着早已被改为灯影相位的 `"E spends 30 energy for Thread Burst"`）；`vector.gd:245` SVG 标题键不匹配导致导出的报告标题仍是中文。
- **修复建议**：建立统一英文术语表（Glossary），集中精校上述反义/机翻条目并在 `audit_ui_translations.py` 加入禁用词/反义守卫；同步按语言调用 `DisplayServer.window_set_title()` 并清理 `main_level.gd` 过时兜底文案。
- **验收标准**：零反义译文、零 `clock`/`Invincible group`/`spork master` 误译、核心专有名词全表统一，`audit_ui_translations.py` 通过。

---

## 三、P1–P2 级欠缺：架构债、运行时性能与升级台账收口

### G-12｜`JourneyWorkbench` 常驻 10 Hz 深拷贝与主线程同步双 SHA-256 写盘
- **位置**：`godot/journey/workbench.gd:29-130`、`godot/journey/core/context.gd:29-79`、`godot/journey/core/store.gd:24-105`、`godot/journey/features/{chronicle,supplies,caseboard}.gd`
- **核实证据**：
  - 虽改为后台加载，启动仍会实例化并 `setup()` 全部 30 个模块（最多 30 次磁盘读取/SHA-256 校验），即便玩家从不打开工作台。
  - 游玩期间以 `PROCESS_MODE_ALWAYS` 每 0.1s 执行 `context.update()`，深拷贝 `world_state.data.regions`、`build_system.state`、已访房间/捷径/背包/剧情旗标；换区时还深拷贝 280 KB `config` 与 57 KB `catalog`。
  - 切房/拾取/立旗时，3 个观察者在主线程同步调用 `store.write()`（建锁目录 → 写临时文件 → flush → 整文件回读比对 → 双 SHA-256 → rename → 删锁目录）。
- **修复建议**：默认关闭后台观察与预加载，仅在玩家首次显式开启工作台（或开启“启用巡礼记录仪”开关）后才懒加载模块；落盘改为异步队列或仅在存盘点/关闭工作台时合并写入。
- **验收标准**：默认游玩时 `JourneyWorkbench` 启动 0 磁盘读、游玩期 0 每帧深拷贝与 0 同步写盘。

### G-13｜切房/切区冗余开销与 W00 无缝驻留真机收口缺口
- **位置**：
  - `godot/scripts/level_rooms.gd:29-35`、`godot/scripts/level_region_build.gd:132, 169, 280, 312`、`godot/scripts/world_routes.gd:46-50`
  - `godot/scripts/level_region_pipeline.gd:48-53, 140-157`
  - `godot/scripts/loader_staging.gd:28-52, 176-259`、`godot/scripts/world_passage.gd:449-500`
  - `docs/W00_SEAMLESS_RESIDENCY_PLAN.md:117-147`
- **核实证据**：
  1. 每次进房 `level_region_build.gd:312` 仍通过 `cached_data()` 深拷贝 293 KB `world_routes.json`（应改调已有的 `cached_hidden_clues()`），每次建区又在 L132/169/280 重复深拷贝 3 次；
  2. 每次区域准备仍加载仅服务校验计数的死数据 `data/chapters/*.json`（5 文件）与 `audio_visual_manifest.json`（159 KB）；
  3. 隐式预构建期间每帧执行 2 次 126 字段反射切换（**504 次 `get`/`set`/帧**）且每次切区销毁重建整套 UI（40+ 微作业）；到达通道终点时仍冻结玩家等待源区卸载；
  4. **W00 Stage 6 洞口视觉人工验收与 Stage 7 Windows 真机长跑（帧时/内存/ObjectDB）均未完成**。
- **修复建议**：改用只读/精准访问器消除 293 KB 深拷贝，移除运行期对 `data/chapters` 与 `audio_visual_manifest` 的加载，评估将 `pilgrimage_interface` / `audio_director` 提升为会话级节点并前移源区卸载时机；随后执行 W00 Stage 7 真机压测并留档。
- **验收标准**：进房/切区不再出现无关 JSON 深拷贝与死数据加载；完成 Windows GPU 实机 6 区循环长跑报告（无卡顿尖峰、无内存/ObjectDB 泄漏）。

### G-14｜核心脚本“上帝类 + 静态垫片”结构债与目录混放
- **位置**：`godot/scripts/{main_level,player_controller,enemy_actor,pilgrimage_interface,audio_director,world_region_loader}.gd`
- **核实证据**：
  - 6 个核心类共 7,029 行、715 个成员字段，其中 **783 / 932（84.0%）** 个方法是 1 行委托垫片，把无类型 `Node` 传给外部 `static func`，丧失静态类型校验，且迫使 W00 用 126 字段反射搬运状态。
  - `godot/scripts/` 单一扁平目录混放 **457 个校验/回放/抓图脚本（74,199 行，占 56.4%）** 与 370 个运行时脚本（57,438 行），导致 `export_presets.cfg` 三份重复维护 2.1 KB 的排除通配符。
- **修复建议**：逐步将验证/回放脚本迁入独立目录 `godot/validations/`（一次简化全部导出排除规则）；按子系统将无类型 `static func` 重构为强类型子节点组件。
- **验收标准**：运行时脚本与测试脚本目录隔离，导出过滤规则大幅精简。

### G-15｜升级台账 0 / 46 项完成最终人工实机验收（缺 T04 全六区开伤害自然通关）
- **位置**：`docs/UPGRADE_COMPLETION_CHECKLIST.md`、`docs/UPGRADE_TASK_LEDGER.md:9-54`、`docs/ledger/status/*.md`
- **核实证据**：46 个升级包全部处于 `[ ] 最终验收` 状态；最关键的是 **`T04` 全六区开伤害完整自然通关（双探索顺序 + 最终 Boss + 三结局）从未完成**，且 C02（盐白契约官冲刺约 50% 打断承力缝治疗的平衡取舍）、手感、混音、实体手柄均等待真实玩家验收记录。
- **修复建议**：待 WS-1/WS-2/WS-3 收口后，组织两轮完整开伤害真机通关（双顺序 + 三结局 + 实体手柄 + 键鼠），逐项核销 `UPGRADE_COMPLETION_CHECKLIST.md` 并在 `docs/ledger/status/` 留档。
- **验收标准**：核心游玩与发行项完成真机验收并归档，清点所有待决平衡项（含 C02）。

---

## 四、P2 级欠缺：发行工程、仓库膨胀、CI 成本与测试盲区

### G-16｜打包元数据、代码签名、文件日志与正式分发链路空白
- **位置**：`godot/export_presets.cfg:1-59`、`godot/project.godot:9-11, 38-39`、`tools/build_release.py:43`、`.github/workflows/release-candidate.yml`
- **核实证据**：
  - Windows `application/modify_resources=false`（使用默认 Godot 图标、无版本号/版权）、未代码签名；macOS 硬编码 `0.1`、仅 ad-hoc 签名未公证；Linux 无 `.desktop`/AppImage/Flatpak；
  - `project.godot` 无 `config/version`，未开启 `debug/file_logging/enable_file_logging`（但 `docs/RELEASE_PLAYER_GUIDE.md:33` 要求玩家附日志），且 `config/features` 声明 `Forward Plus` 与实际 `gl_compatibility` 矛盾；
  - `build_release.py:43` 用 `rglob('*')` 而非 `git ls-files`，本地脏文件可能误打进候选包；
  - 尚无 Steamworks / itch.io（`butler`）/ GitHub Releases 自动化发布流水线。
- **修复建议**：补齐三端图标/版本元数据/文件日志与 `project.godot` 渲染特性一致性；`build_release.py` 改走 `git ls-files`；接入签名/公证环境变量钩子与 GitHub Releases/itch 发布工作流。
- **验收标准**：导出的 Windows `.exe` 含正确图标与版本号，三端运行自动落盘日志文件，且发布流水线支持 tag 触发产物归档。

### G-17｜仓库极度膨胀（`.git` 10.71 GB）与死脚本/临时文件堆积
- **位置**：`.gitattributes`（523 行含 306 条 `-filter` 绕过 LFS）、`art_requests/`（2.38 GB）、`artifacts/`（合并 PR #698 后仍剩 9,726 文件 / **1.13 GB**）、`tools/`（503 文件）、根目录 `tmp_check_contracts.mjs`
- **核实证据**：
  - HEAD 追踪 5.68 GB 中 **4.50 GB 为非 LFS 普通 Blob**；`art_requests/` 含 1.99 GB 非 LFS 原始生成图与 MP3；
  - 合并 PR #698 后 `artifacts/` 仍余 201 个零引用子目录（4,803 文件 / **711.92 MiB**，如 `boss_keyframes` 382.9 MiB LFS、`boss_motion_v6` 36.9 MiB、`map_blueprints` 34.2 MiB 等）；
  - `tools/` 含 104 个零引用脚本及明确损坏脚本：`validate_demo_geometry.py`（检查已不存在的 `starter_step`）、`validate_itch_enemy_assets.py`、`validate_open_asset_policy.py`、`capture_combat_pose_review.py`（引用已删脚本）、带 UTF-8 BOM 的 `build_boss05_directional_assets.py` / `validate_boss05_directional_assets.py`；根目录还追踪了 `tmp_check_contracts.mjs`。
- **修复建议**：清理/归档零引用历史产物与损坏死脚本、移除根目录 `tmp_check_contracts.mjs`、统一 `.import`/`.uid` 追踪策略，并对后续素材严守 `.gitattributes` LFS 规则（若需缩小克隆体积，另行规划经维护者批准的 LFS 迁移/历史重写）。
- **验收标准**：`tools/` 下所有保留脚本可执行/可解析，零临时文件追踪，仓库工作树体积极大收敛。

### G-18｜CI 成本高昂、剩余 14 份合同全拉 LFS 与工作流冗余
- **位置**：`.github/contracts/*.yml`、`.github/workflows/{godot-integration,release-candidate,ledger-u06-audio-volume-save,ledger-u06-build-shortcut,settings-dialog-layout}.yml`、`tools/ci/{contracts.py,contract_minutes.json}`
- **核实证据**：
  1. **仍有 14 份合同写死 `lfs: true`**（`build-receipt`, `camera-observation`, `credits-reader`, `expedition-drafts`, `goal-update`, `itinerary-handoff`, `journal-find`, `journal-marks`, `journey-comparison`, `journey-window-layout`, `known-wish`, `settings-comparison`, `thread-budget`, `transaction-receipts`），任一落入分片即令该分片全拉 1.18 GB LFS；
  2. `release-candidate.yml:88, 134` 跳过 `./.github/actions/hydrate-lfs` 缓存，每次 PR 在三端全拉 `godot/**`；
  3. 179 份合同估算 9.6 小时机时，`.godot/imported` 零缓存（每分片重跑 ~10 分钟冷导入）；`godot-integration.yml:50-78` 在 3 个分片上重复跑 3 遍 JS 与 MetSys 校验；4 份独立工作流对 `push: main` 无 `paths:` 过滤；`ledger-u06-build-shortcut.yml:29-47` 用 Python 下载 Godot 绕过了 `contracts.py lint` 检查；
  4. **76 / 179 份合同（42.5%）** 缺失 `contract_minutes.json` 耗时数据；13 个 `*_validation.gd` 孤儿测试与 6 个 `godot_suite_success_markers.json` 套件未接入默认 CI。
- **修复建议**：把 14 份 `lfs: true` 改为按需 `--include`、让 `release-candidate.yml` 复用 `hydrate-lfs` 缓存、给 `godot-integration.yml` 补 `if: matrix.shard == 1`、补齐 `contract_minutes.json` 并决定 13 个孤儿测试的去留（接入或清理）、修复 `boss_trial_validation.gd:53-54` 退出时未 `await process_frame` 导致的 ObjectDB 泄漏警告。
- **验收标准**：全仓 0 个 `lfs: true` 合同，`contracts.py lint` 与 `test_contracts.py`、`test_lfs_cache_workflows.py` 通过，CI 分片耗时与 LFS 流量明显下降。

### G-19｜自动化测试盲区与存档输入防篡改缺口
- **位置**：`godot/scripts/world_state.gd:319-337`、`godot/scripts/world_coordinates.gd:77`、`.github/workflows/runtime-lifecycle-soak.yml:57`、`tools/run_rock_gpu_validation.py:68-70`
- **核实证据**：
  1. 无连续 6 章开伤害通关自动化链路；PR 阶段 `runtime-lifecycle-soak.yml` 仅跑 `--seconds 1` 且无定时 `schedule:` 夜间长跑；
  2. 全部渲染与音频测试运行在 Linux `llvmpipe` 软件 GL + `--audio-driver Dummy` + 合成按键，CH03–CH06 缺少实时战斗/UI 像素回归；
  3. 零模糊测试；`world_state.gd:_valid_data()` 允许任意极端有限数 `hp`/`energy`（如 `1e308`）与未知键，`world_coordinates.gd:77` 在 `world_location == {}` 时放行任意不存在的 `current_region`。
- **修复建议**：在 `world_state.gd` / `world_coordinates.gd` 补齐数值合理区间与区域白名单校验并新增存档篡改/截断模糊测试；为 `runtime-lifecycle-soak.yml` 增加夜间定时长跑；将 CH03–CH06 纳入实时渲染抽检。
- **验收标准**：恶意/极端篡改存档被安全拦截或钳位并触发备份恢复提示；夜间长跑定时生效且零泄漏。
