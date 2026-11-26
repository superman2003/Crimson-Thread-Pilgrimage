# 全项目手绘美术绘制总清单（2026-11-26）

- **盘点基线**：`origin/main`（结合 `godot/assets/sprites/`、`godot/data/original_creature_combat.json`、`godot/data/enemy_journal.json`、`godot/data/build_catalog.json`、`tools/creature_redraw_art.py` 与 `docs/ledger/status/{V01,V02,V03,B01}.md` 实测提取）
- **配套机器可读清单**：[20261126_art_production_backlog.json](20261126_art_production_backlog.json)（可供外部排期表或自动化出图/打包管线直接读取）
- **范围边界**：本清单**仅汇总需要美术手绘/重绘的视觉素材与动画原画**。代码/配置/CI/本地化修复已另行提交于 PR #702–#705；音频缺口（如 `player_wall_jump` 占位音与剩余房间环境声）归属音频排期，仅在文末注明，不混入画师任务量。

---

## 总览与推荐排期（9 个工作包，按 P0 → P3 排序）

| 编号 | 优先级 | 关联台账 / 审计项 | 绘制内容 | 量化规模 | 代码接缝状态 | 验收入口 |
| :--- | :---: | :--- | :--- | :--- | :--- | :--- |
| **ART-01** | **P0** | `V02` / `G-10` | 清零 7 段强调色丢失豁免项 | **7 段**（4 角色） | 已就绪，重绘打包即触发质检 | `tools/creature_redraw_art.py` |
| **ART-02** | **P1** | `V02` / `E01` / `C02` / `G-10` | 主角三契印专属普攻、下劈与疗伤动作 | **3 契印 × 5–6 组动作**（~96 帧） | 数值与判定已就绪，需补动作选择键 | `seal_identity` + `hero_animation` |
| **ART-03** | **P1** | `B01` / `V02` / `G-10` | B01 战术职责专属动画（伏击/报警/支援，含守点可选） | **8 种核心角色（12 段）** + 4 种守点可选 | 行为、音效、光环提示已落地（`_role_cue`） | `enemy_tactical_roles` + `capture_role_cues.gd` |
| **ART-04** | **P1** | `V02` / `G-10` | 短受击段（≤4 唯一帧）与短死亡段补帧 | **7 种短受击（含 3 Boss）+ 8 种短死亡** | 补图后可同步放开 `enemy_actor.gd:551-555` 受击播帧 | `audit_character_animation_assets.py` |
| **ART-05** | **P1** | `A01` / `V01` / `N05` / `G-09` | 能力门牌、结局三门、挑战/追踪物件与纯代码场景机关替换 | **8 枚门牌 + 3 扇终局门 + 3 种战后异象 + 6 类机关/遗迹** | 挂点全部就绪，替换贴图即可生效 | `ability_gate` + `ending_aftermath` + `optional_challenges` |
| **ART-06** | **P2** | `V02` / `G-10` | 45 种怪物转身（`turn`）与急停（`brake`）衔接帧 | **6 Boss + 20 地面 + 11 飞行**（+ 8 驻足按需仅转向） | `enemy_motion_transitions` 已就绪，参照 `moss_larva` 模板 | `motion_transition` 回归 + `creature_redraw_art.py` |
| **ART-07** | **P2** | `V02` / `G-10` | 25 位 NPC 职能交互动作拓展（现有仅 4 站桩态） | **25 位 NPC × 2 组动作**（按服务/指引/剧情分批） | 已有 `original_npcs/*/motion_manifest.json` 管线 | NPC 动作专项回归（245 项） |
| **ART-08** | **P2** | `V03` | 六区 `flat_maps` 岩体去弱对称团 & 普通房间前中后景层次 | **6 个生物群系**（`rock_mass_large.png` + 前中后景层） | `parallax_layout` 与渲染器已就绪 | `parallax_layout` + 真机实看（T04） |
| **ART-09** | **P3** | `V02` | 备用 20 Boss 图库画风统一（仅在新增 Boss 战时启动） | 按新增排期定，当前六章不急需 | 备用图库当前未接入正式六章 | 按新 Boss 接入合同验收 |

---

## ART-01（P0）｜清零 7 段强调色丢失豁免项（`LEGACY_ACCENT_SOURCES`）

在画风质检门禁合入之前已合并的 7 段重绘动作存在高饱和强调色（绯红/铜金/纹样）大面积发灰或丢失，目前按源图 SHA-256 暂列于 `tools/creature_redraw_art.py:64-72` 的 `LEGACY_ACCENT_SOURCES` 豁免名单。**建议第一批优先处理，清零豁免列表。**

| # | 角色 `kind` | 中文名 | 片段名 | 原图指纹（`source_sha256` 前 12 位） | 备注与重画要求 |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `bronze_moth` | 铜翼蛾 | `moth_dust` | `b056b313d65d` | 最严重，强调色仅剩约 23%，需完整恢复铜翼纹样与翅缘高亮 |
| 2 | `bronze_moth` | 铜翼蛾 | `moth_dust_recover` | `686aa4ce38da` | 恢复高饱和纹样/红金部件，确保强调色占比 ≥ 原片段 55% |
| 3 | `bronze_moth` | 铜翼蛾 | `moth_dust_windup` | `c888232b2eb9` | 恢复高饱和纹样/红金部件，确保强调色占比 ≥ 原片段 55% |
| 4 | `bronze_moth` | 铜翼蛾 | `windup` | `ef60efaa989a` | 恢复高饱和纹样/红金部件，确保强调色占比 ≥ 原片段 55% |
| 5 | `corridor_heavy` | 钟壳重卫 | `heavy_stamp` | `e41032cefbc5` | 恢复高饱和纹样/红金部件，确保强调色占比 ≥ 原片段 55% |
| 6 | `index_scribe` | 索引书吏 | `attack` | `797afc62e4ed` | 恢复高饱和纹样/红金部件，确保强调色占比 ≥ 原片段 55% |
| 7 | `saltwhite_contract_judge` | 灰冠螳将 | `windup` | `5efa67075624` | 恢复高饱和纹样/红金部件，确保强调色占比 ≥ 原片段 55% |

- **验收门槛**：重画打包后将对应项从 `tools/creature_redraw_art.py` 的 `LEGACY_ACCENT_SOURCES` 移除；`style_defects()` 必须满足 `new_accent >= old_accent * 0.55`、`new_soft <= old_soft * 2.5`、中位实体面积误差 `≤ 4%`。

---

## ART-02（P1）｜主角三契印专属动作（`thread_doll_v1`）

当前主角 `godot/assets/sprites/player/thread_doll_v1/manifest.json` 拥有 32 组通用动作（共 154 独特帧，画幅 `384×384`，落脚基准 `foot_baseline = 280`，缩放 `sprite_scale = 0.66`），但三种契印（缝名／司铸／校录）的战斗数值、节奏与疗伤机制已完全分化（详见 [20261018_seal_identity.md](20261018_seal_identity.md)），视觉上仍共用一套挥刃与疗伤序列帧。

| 契印 ID | 中文名 | 疗伤机制（实装参数） | 必补动作片段（建议各 6 帧） | 造型与动作辨识方向 |
| :--- | :--- | :--- | :--- | :--- |
| `crimson` | **缝名契印** | 耗 60 绯线 / 回 1 格 / 0.55s / 支持空中 | `attack_1`、`attack_2`、`down_attack`、`ground_down_attack`、`heal`、`air_heal` | 轻快缝针直刺、疾速上挑/斜斩，快缝疗伤支持空中收束红线（0.55s） |
| `bell` | **司铸契印** | 耗 80 绯线 / 回 2 格 / 1.15s / 须落地 | `attack_1`、`attack_2`、`down_attack`、`ground_down_attack`、`heal` | 厚重铜钟锤势大弧挥击与沉坠下劈，承力缝落地双膝稳架厚光环（1.15s，回 2 格） |
| `salt` | **校录契印** | 耗 50 绯线 / 回 1 格 / 0.9s / 须落地 | `attack_1`、`attack_2`、`down_attack`、`ground_down_attack`、`heal` | 精准校录刻笔式点刺与标线斜劈，校录缝落地展卷定印（0.90s，低耗 50 绯线） |

- **规格约束**：严格保持 `384×384` 单帧画幅与 `foot_baseline = 280` 站位锚点，不以复制帧冒充独特帧（遵循 [20261028_v02-action-transitions.md](../coordination/20261028_v02-action-transitions.md)）；出图后同步在主角表现脚本按契印 ID 路由对应片段。

---

## ART-03（P1）｜B01 战术职责专属动作（伏击 / 报警 / 支援 / 守点）

`godot/data/original_creature_combat.json` 与 `enemy_actor.gd::_role_cue()` 已落地全部 B01 行为、音效与光环提示，但角色本体尚无对应职责动作帧：

### 3.1 必画核心角色（8 种：4 伏击 + 3 报警 + 1 支援）

| 战术职责 | 角色 `kind` | 中文名 | 章节 | `canvas` | `display_height` | 建议新增动作片段与帧数 | 表现要求 |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- | :--- |
| **伏击 (`ambush`)** | `drain_leech` | 渠底蛭 | CH02 | `[516, 233]` | 66 | `ambush_lurk`（4 帧循环）+ `ambush_reveal`（6 帧） | 蛰伏藏匿轮廓明显低矮；现身时破隐抬头，匹配 0.35s 停顿窗 |
| **伏击 (`ambush`)** | `echo_moss_larva` | 回声苔虫 | CH06 | `[412, 257]` | 72 | `ambush_lurk`（4 帧循环）+ `ambush_reveal`（6 帧） | 蛰伏藏匿轮廓明显低矮；现身时破隐抬头，匹配 0.35s 停顿窗 |
| **伏击 (`ambush`)** | `salt_bookmite` | 盐页螨 | CH03 | `[320, 191]` | 68 | `ambush_lurk`（4 帧循环）+ `ambush_reveal`（6 帧） | 蛰伏藏匿轮廓明显低矮；现身时破隐抬头，匹配 0.35s 停顿窗 |
| **伏击 (`ambush`)** | `vine_crawler` | 藤蔓爬虫 | CH04 | `[340, 214]` | 72 | `ambush_lurk`（4 帧循环）+ `ambush_reveal`（6 帧） | 蛰伏藏匿轮廓明显低矮；现身时破隐抬头，匹配 0.35s 停顿窗 |
| **报警 (`alarm`)** | `echo_pilgrim_commander_minor` | 回声巡礼副统 | CH06 | `[398, 320]` | 118 | `alarm_call`（6–8 帧） | 摇钟 / 吹号 / 举旗号令姿态，配合声波环可一眼识别为优先击杀目标 |
| **报警 (`alarm`)** | `silent_bugbler` | 无声号手 | CH05 | `[362, 194]` | 100 | `alarm_call`（6–8 帧） | 摇钟 / 吹号 / 举旗号令姿态，配合声波环可一眼识别为优先击杀目标 |
| **报警 (`alarm`)** | `spore_bellmaker` | 孢铃匠 | CH01 | `[334, 244]` | 96 | `alarm_call`（6–8 帧） | 摇钟 / 吹号 / 举旗号令姿态，配合声波环可一眼识别为优先击杀目标 |
| **支援 (`support`)** | `ash_banner_imp` | 灰旗小鬼 | CH05 | `[416, 282]` | 80 | `support_channel`（6–8 帧循环） | 举灰旗引导支援流向友军的持续施法动作，便于玩家读招打断 |

### 3.2 次优可选：守点职责（4 种 `guard`）

| 角色 `kind` | 中文名 | 章节 | `canvas` | 建议动作 | 说明 |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `echo_thorn_sentinel` | 回声荆棘哨卫 | CH06 | `[386, 234]` | `guard_stance`（4–6 帧） | 区别于普通巡逻待机的架盾/持枪戒备站姿，仅在试玩辨识度不足时补画 |
| `echo_waterwheel_knight` | 回声水轮骑士 | CH06 | `[304, 230]` | `guard_stance`（4–6 帧） | 区别于普通巡逻待机的架盾/持枪戒备站姿，仅在试玩辨识度不足时补画 |
| `gear_sentinel` | 齿轮哨卫 | CH01 | `[492, 226]` | `guard_stance`（4–6 帧） | 区别于普通巡逻待机的架盾/持枪戒备站姿，仅在试玩辨识度不足时补画 |
| `thorn_sentinel` | 荆棘哨卫 | CH04 | `[394, 233]` | `guard_stance`（4–6 帧） | 区别于普通巡逻待机的架盾/持枪戒备站姿，仅在试玩辨识度不足时补画 |

---

## ART-04（P1）｜短受击段与短死亡段补帧（受力与倒地连续性）

依据现行 `motion_redraw_manifest.json` 唯一帧统计与 [20261109_character_animation_checklist.md](../research/20261109_character_animation_checklist.md)：

### 4.1 短受击段（唯一帧 ≤ 4，共 7 种，含 3 位正式 Boss）

> 附注：当前 `enemy_actor.gd:551-555` 为避免受击闪烁跳帧，对所有原生视觉敌怪仅执行白闪而未播放 `hurt` 动画；补齐下列 7 种受击“接触受力 → 重心偏移 → 回架”完整序列（建议 6–8 唯一帧）后，可同步评估放开非霸体受击播帧。

| 类型 | 角色 `kind` | 中文名 | 章节 | 当前唯一帧 | 目标唯一帧 | `canvas` |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| 小怪 | `drain_leech` | 渠底蛭 | CH02 | 4 | 6–8 | `[516, 233]` |
| 小怪 | `echo_thorn_sentinel` | 回声荆棘哨卫 | CH06 | 4 | 6–8 | `[386, 234]` |
| Boss | `rust_crown_guardian` | 苔钟守母 | CH01 | 4 | 6–8 | `[616, 293]` |
| 小怪 | `rust_diver` | 锈潜者 | CH02 | 4 | 6–8 | `[474, 238]` |
| Boss | `silent_pilgrim_commander` | 镜池新娘 | CH05 | 4 | 6–8 | `[476, 272]` |
| 小怪 | `spore_bellmaker` | 孢铃匠 | CH01 | 4 | 6–8 | `[334, 244]` |
| Boss | `sunken_hammer_smith` | 绯线执剪者 | CH02 | 4 | 6–8 | `[422, 317]` |

### 4.2 短死亡段复核与补帧（8 种小怪）

| 角色 `kind` | 中文名 | 章节 | 当前帧数 | 补画重点 |
| :--- | :--- | :---: | :---: | :--- |
| `ash_banner_imp` | 灰旗小鬼 | CH05 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `drain_leech` | 渠底蛭 | CH02 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `echo_thorn_sentinel` | 回声荆棘哨卫 | CH06 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `erasure_bailiff` | 删页执行官 | CH03 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `gear_sentinel` | 齿轮哨卫 | CH01 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `rust_diver` | 锈潜者 | CH02 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `salt_bookmite` | 盐页螨 | CH03 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |
| `silent_bugbler` | 无声号手 | CH05 | 6 | 检查站姿 → 失衡 → 倒地轮廓与武器连续性，消除跳变 |

---

## ART-05（P1）｜核心交互物件、结局三门与能力门牌手绘替换

当前 `godot/assets/sprites/original_interactables/manifest.json` 仅有 8 枚基础原画物件（`rest_bell`/`rest_root`/`lever_*`/`gate_*`/`chest_*`），其余高频可见机关仍依赖 `_draw()` 几何图形或共用拉杆/门贴图：

### 5.1 能力门牌手绘图标（8 枚，替换 `ability_gate_sign.gd` 纯代码矢量绘制）

| 编号 | 能力 ID | 门牌名称 | 建议尺寸 | 设计意图 |
| :---: | :--- | :--- | :---: | :--- |
| 1 | `thread_dash` | 绯线冲刺 | `64×64` | 双折绯线疾掠箭头，铜边深墨底盘 |
| 2 | `silk_wall_grip` | 丝爪攀壁 | `64×64` | 垂壁竖线与钩爪斜抓纹样 |
| 3 | `double_thread_jump` | 二段悬跳 | `64×64` | 双层上扬飞羽/折线悬跃纹 |
| 4 | `thorn_downstrike` | 棘线下劈 | `64×64` | 竖直下刺尖针与下方荆棘裂纹 |
| 5 | `lantern_phase` | 灯影相位 | `64×64` | 八芒虚实提灯光晕核心 |
| 6 | `crown_resonance` | 冠鸣共震 | `64×64` | 钟舌核心与双层向上共振波弧 |
| 7 | `echo_hook` | 回响钩索 | `64×64` | 悬垂铜钩与回响尾线 |
| 8 | `return_arrow` | 归途返程徽章 | `64×64` | 淡青色向上归途指向标（背侧通行提示） |

### 5.2 结局三扇专属大门 & 结局后钟龛异象（替换通用门与 `_draw()`）

> 附注：PR #704 已在代码侧移除 `ending_gates.gd` 对旧 `gothicvania/boss_gate.png` 的引用并暂切至 `gate_closed`/`gate_open` 通用门叠加程序轮廓线；美术侧仍需补画 3 扇具有独立剪影的终局手绘门及 3 套结局后异象贴图。

| 结局 ID | 门体名称 | 门体原画规格 | 对应战后钟龛异象（`ending_aftermath_scene.gd`，跨 6 区共 18 处） |
| :--- | :--- | :--- | :--- |
| `ending_a` | **重鸣之门**（暖金 `#f6d27a`） | 独立钟拱石门 + 悬钟雕饰（建议 `256×320`） | `bells`：钟龛旁悬垂共鸣金钟与余音光丝 |
| `ending_b` | **断冠之门**（绯红 `#e8746f`） | 裂开王冠残拱 + 断裂锁链（建议 `256×320`） | `barrier`：碎冠残碑与散落的绯线封印结 |
| `ending_c` | **改写之门**（苍青 `#84e8f2`） | 铭文展开星门 + 悬浮书页（建议 `256×320`） | `names`：飘浮的苍青铭名纸笺与微光墨迹 |

### 5.3 其他纯代码 / 复用拉杆的关卡交互物件

| 物件类别 | 当前实现与问题 | 全世界数量 | 需绘制贴图清单 | 关联脚本 |
| :--- | :--- | :---: | :--- | :--- |
| **挑战余响钟** | 复用 `lever_closed`/`lever_open` 拉杆 | 9 处 | 2 态（未启 / 已清）手绘古铜余响钟座 | `optional_challenges.gd` |
| **追踪狩猎残迹** | 复用 `lever_closed`/`lever_open` 拉杆 | 6 处 | 2 态（待查 / 已录）爪痕与发光残丝 | `optional_challenges.gd` |
| **洞窟升降梯** | 纯代码 `_draw()` 线条框 | 7 座（六章各 1–2 座） | 载人铁篮、滑轮齿轮、可平铺链索、站台制动桩 | `cave_lift.gd` |
| **归途结 & 钩环** | 纯代码 `_draw()` 圆环/线段 | 全六章通用 | 归途红绳结（待机/激活）、高空铜钩环与悬链 | `level_ground.gd` / `level_world_travel.gd` |
| **暗道光缝线索** | 纯代码 `_draw()` 折线 | 8 处 | 2 态（未发现微光裂隙 / 已发现黯淡裂隙） | `hidden_route_clue.gd` |
| **场景历史遗迹** | 纯代码 `_draw()` 40 处几何调用 | 12 种独有物件 | `bell_mold`, `pump_manifold`, `book_press`, `graft_bench`, `name_spool`, `lock_comb`, `pledge_scar`, `reversed_badges`, `scraped_page`, `grafted_collar`, `rewritten_muster`, `swallowed_key` | `scene_history_prop.gd` |

---

## ART-06（P2）｜45 种怪物转身（`turn`）与急停（`brake`）衔接帧清单

46 种正式角色中，仅 `moss_larva`（苔钟幼虫）已完成模板示范（`turn` 7 帧、`brake` 7 帧，见 `godot/assets/sprites/original_creatures/moss_larva/motion_redraw_manifest.json`）。其余 **45 种角色** 严禁一刀切按地面步态重画，必须按 `motion` 类型分 4 组排期：

### 6.1 A 组：6 位正式 Boss（地面 `ground`，最高视觉收益，各补 `turn` + `brake`）

| # | 角色 `kind` | 中文名 | 章节 | `canvas` | `display_height` | 建议帧数 | 备注 |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 1 | `broken_string_gardener` | 铜根主教 | CH04 | `[356, 248]` | 228 | `turn` 6 + `brake` 6 | Boss 体积大，转身需保持武器长度、披风与支撑脚稳定 |
| 2 | `rust_crown_guardian` | 苔钟守母 | CH01 | `[616, 293]` | 224 | `turn` 6 + `brake` 6 | Boss 体积大，转身需保持武器长度、披风与支撑脚稳定 |
| 3 | `saltwhite_contract_judge` | 灰冠螳将 | CH03 | `[530, 238]` | 226 | `turn` 6 + `brake` 6 | Boss 体积大，转身需保持武器长度、披风与支撑脚稳定 |
| 4 | `silent_crown_core` | 百钥守门人 | CH06 | `[522, 278]` | 232 | `turn` 6 + `brake` 6 | Boss 体积大，转身需保持武器长度、披风与支撑脚稳定 |
| 5 | `silent_pilgrim_commander` | 镜池新娘 | CH05 | `[476, 272]` | 226 | `turn` 6 + `brake` 6 | Boss 体积大，转身需保持武器长度、披风与支撑脚稳定 |
| 6 | `sunken_hammer_smith` | 绯线执剪者 | CH02 | `[422, 317]` | 228 | `turn` 6 + `brake` 6 | Boss 体积大，转身需保持武器长度、披风与支撑脚稳定 |

### 6.2 B 组：20 种地面常规 / 精英小怪（`ground`，各补 `turn` + `brake`）

| # | 角色 `kind` | 中文名 | 章节 | 战术职责 | `canvas` | `display_height` | 建议帧数 |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| 1 | `ash_banner_imp` | 灰旗小鬼 | CH05 | `support` | `[416, 282]` | 80 | `turn` 6 + `brake` 6 |
| 2 | `bellroot_acolyte` | 铃根侍徒 | CH01 | `patrol` | `[568, 310]` | 96 | `turn` 6 + `brake` 6 |
| 3 | `corridor_heavy` | 钟壳重卫 | CH01 | `patrol` | `[336, 294]` | 118 | `turn` 6 + `brake` 6 |
| 4 | `drain_leech` | 渠底蛭 | CH02 | `ambush` | `[516, 233]` | 66 | `turn` 6 + `brake` 6 |
| 5 | `echo_moss_larva` | 回声苔虫 | CH06 | `ambush` | `[412, 257]` | 72 | `turn` 6 + `brake` 6 |
| 6 | `echo_pilgrim_commander_minor` | 回声巡礼副统 | CH06 | `alarm` | `[398, 320]` | 118 | `turn` 6 + `brake` 6 |
| 7 | `echo_waterwheel_knight` | 回声水轮骑士 | CH06 | `guard` | `[304, 230]` | 110 | `turn` 6 + `brake` 6 |
| 8 | `erasure_bailiff` | 删页执行官 | CH03 | `patrol` | `[360, 246]` | 114 | `turn` 6 + `brake` 6 |
| 9 | `gear_sentinel` | 齿轮哨卫 | CH01 | `guard` | `[492, 226]` | 102 | `turn` 6 + `brake` 6 |
| 10 | `obsidian_bellwheel` | 黑曜钟轮 | CH05 | `patrol` | `[384, 244]` | 96 | `turn` 6 + `brake` 6 |
| 11 | `obsidian_spearman` | 黑曜枪兵 | CH05 | `patrol` | `[498, 306]` | 106 | `turn` 6 + `brake` 6 |
| 12 | `page_duelist` | 页刃斗士 | CH03 | `patrol` | `[416, 245]` | 98 | `turn` 6 + `brake` 6 |
| 13 | `pilgrim_chariot` | 巡礼战车 | CH05 | `patrol` | `[360, 219]` | 116 | `turn` 6 + `brake` 6 |
| 14 | `root_cage_hunter` | 根笼猎手 | CH04 | `patrol` | `[390, 246]` | 104 | `turn` 6 + `brake` 6 |
| 15 | `rust_diver` | 锈潜者 | CH02 | `patrol` | `[474, 238]` | 102 | `turn` 6 + `brake` 6 |
| 16 | `salt_bookmite` | 盐页螨 | CH03 | `ambush` | `[320, 191]` | 68 | `turn` 6 + `brake` 6 |
| 17 | `valve_crawler` | 阀壳爬虫 | CH02 | `patrol` | `[368, 166]` | 74 | `turn` 6 + `brake` 6 |
| 18 | `vine_crawler` | 藤蔓爬虫 | CH04 | `ambush` | `[340, 214]` | 72 | `turn` 6 + `brake` 6 |
| 19 | `waterwheel_knight` | 水轮骑士 | CH02 | `patrol` | `[376, 230]` | 108 | `turn` 6 + `brake` 6 |
| 20 | `wax_lancer` | 蜡枪卫 | CH03 | `patrol` | `[450, 245]` | 106 | `turn` 6 + `brake` 6 |

### 6.3 C 组：11 种飞行小怪（`flight`，按飞行动力学补空中换向 `turn` + 悬停回稳 `brake`）

> 附注：飞行角色不画地面踏步刹车；重点表现翅翼倾斜换向、俯冲退出与悬停回稳（并与 `creature_wing_flap.json` 翅根着色器摆动兼容）。

| # | 角色 `kind` | 中文名 | 章节 | `canvas` | `display_height` | 建议帧数 |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| 1 | `bell_mote` | 铃光蛾 | CH02 | `[406, 183]` | 68 | `turn` 4–6 + 悬停回稳 4–6 |
| 2 | `bronze_moth` | 铜翼蛾 | CH01 | `[366, 293]` | 86 | `turn` 4–6 + 悬停回稳 4–6 |
| 3 | `delayed_shadow` | 迟影 | CH06 | `[424, 274]` | 100 | `turn` 4–6 + 悬停回稳 4–6 |
| 4 | `echo_contract_scribe` | 回声契约书吏 | CH06 | `[480, 271]` | 98 | `turn` 4–6 + 悬停回稳 4–6 |
| 5 | `falling_clapper` | 坠落钟舌 | CH06 | `[398, 226]` | 86 | `turn` 4–6 + 悬停回稳 4–6 |
| 6 | `isotope_lumen` | 微光异体 | CH06 | `[362, 263]` | 78 | `turn` 4–6 + 悬停回稳 4–6 |
| 7 | `phase_censor` | 灯影审察者 | CH05 | `[346, 245]` | 98 | `turn` 4–6 + 悬停回稳 4–6 |
| 8 | `rain_censer_mote` | 雨香灰灵 | CH02 | `[408, 219]` | 74 | `turn` 4–6 + 悬停回稳 4–6 |
| 9 | `summoned_page` | 召唤书页 | CH03 | `[392, 170]` | 74 | `turn` 4–6 + 悬停回稳 4–6 |
| 10 | `thorn_bloom_mote` | 刺花微灵 | CH04 | `[418, 190]` | 76 | `turn` 4–6 + 悬停回稳 4–6 |
| 11 | `wax_bee` | 蜡蜂 | CH04 | `[348, 241]` | 80 | `turn` 4–6 + 悬停回稳 4–6 |

### 6.4 D 组：8 种驻足小怪（`stationary`，**无需 `brake`**，按需仅评估原地 `turn`）

> 附注：驻足炮台/哨卫不进行地面长距离巡逻，禁止为凑清单强补 `brake`；仅在实体试玩观察到左右翻面生硬时补 4 帧原地转身。

| # | 角色 `kind` | 中文名 | 章节 | 战术职责 | `canvas` | `display_height` | 建议动作 |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 1 | `echo_thorn_sentinel` | 回声荆棘哨卫 | CH06 | `guard` | `[386, 234]` | 108 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 2 | `index_scribe` | 索引书吏 | CH03 | `ranged` | `[380, 277]` | 96 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 3 | `kneeling_crossbowman` | 跪弩手 | CH05 | `ranged` | `[332, 229]` | 92 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 4 | `pipe_thrower` | 管弹投手 | CH02 | `ranged` | `[392, 230]` | 96 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 5 | `pollen_lutist` | 花粉琴师 | CH04 | `ranged` | `[320, 232]` | 96 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 6 | `silent_bugbler` | 无声号手 | CH05 | `alarm` | `[362, 194]` | 100 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 7 | `spore_bellmaker` | 孢铃匠 | CH01 | `alarm` | `[334, 244]` | 96 | 仅按需补 `turn`（4 帧），不补 `brake` |
| 8 | `thorn_sentinel` | 荆棘哨卫 | CH04 | `guard` | `[394, 233]` | 104 | 仅按需补 `turn`（4 帧），不补 `brake` |

### 6.5 既留步态豁免追踪（`LEGACY_STRIDE_SOURCES`，11 种）

以下 11 种角色的既有 `walk` 片段登记在 `tools/creature_redraw_art.py:39-51`（下肢像素变化低于 `LEG_CHANGE_FLOOR = 0.15` 豁免），若顺带润色地面步态可按需同步消除豁免：
`corridor_heavy`（钟壳重卫）, `drain_leech`（渠底蛭）, `echo_moss_larva`（回声苔虫）, `erasure_bailiff`（删页执行官）, `moss_larva`（苔钟幼虫）, `pilgrim_chariot`（巡礼战车）, `rust_crown_guardian`（苔钟守母）, `rust_diver`（锈潜者）, `saltwhite_contract_judge`（灰冠螳将）, `silent_crown_core`（百钥守门人）, `vine_crawler`（藤蔓爬虫）。

---

## ART-07（P2）｜25 位 NPC 职能交互动作拓展清单

全部 25 位 NPC 现已完成基础 4 态（`idle`/`talk`/`greet`/`rest`，共 409 帧原画 + 固定头像），但工坊锻造、交易递物、绘图指引与结局见证仍停留在通用站桩交谈态。建议按职能分 3 批各补 2 组交互动作（每组 4–6 帧）：

| # | NPC ID | 中文名 | 章节 | 分类批次 | `canvas` | 现有帧数（`motion_manifest`） | 建议新增动作 |
| :---: | :--- | :--- | :---: | :--- | :---: | :--- | :--- |
| 1 | `npc_backdoor_sacristan` | 后门司铃人 | CH01 | 教学/指引手势 | `[334, 320]` | idle:4, talk:8, greet:2, rest:2 | 摇小铃示意与侧身让道（ring_bell / step_aside） |
| 2 | `npc_beeswax_vendor` | 蜂蜡商人蜜岚 | CH04 | 服务/工坊交互 | `[294, 274]` | idle:4, talk:8, greet:2, rest:2 | 检视蜂蜡与交易递物（trade_inspect / hand_item） |
| 3 | `npc_black_tide_child` | 黑潮童声 | CH06 | 结局/核心见证 | `[364, 328]` | idle:4, talk:8, greet:2, rest:2 | 侧首低语与黑潮牵引（whisper_tilt / beckon_tide） |
| 4 | `npc_blind_bell_knight` | 盲钟骑士 | CH05 | 剧情/见证反应 | `[260, 293]` | idle:4, talk:8, greet:2, rest:2 | 拄剑聆听与持剑致敬（sword_listen / knight_salute） |
| 5 | `npc_broken_singer` | 断弦歌者 | CH04 | 剧情/见证反应 | `[320, 265]` | idle:8, talk:8, greet:2, rest:2 | 抚弦轻吟与停手凝视（pluck_string / hush_pause） |
| 6 | `npc_canal_child` | 管渠童子 | CH02 | 剧情/见证反应 | `[286, 258]` | idle:4, talk:8, greet:2, rest:2 | 蹲身观水与惊奇招手（crouch_watch / eager_wave） |
| 7 | `npc_crown_tongue` | 旧王钟舌 | CH06 | 结局/核心见证 | `[368, 286]` | idle:4, talk:8, greet:2, rest:2 | 低沉示警与震颤共鸣（solemn_warn / resonance_tremor） |
| 8 | `npc_deserter_flagbearer` | 逃旗手 | CH05 | 剧情/见证反应 | `[316, 261]` | idle:4, talk:8, greet:2, rest:2 | 收拢残旗与低头抉择（furl_banner / bow_conflict） |
| 9 | `npc_drowned_foreman` | 半沉工头 | CH02 | 剧情/见证反应 | `[262, 202]` | idle:4, talk:8, greet:2, rest:2 | 扶膝喘息与指向水渠（lean_weary / point_canal） |
| 10 | `npc_first_pilgrim_echo` | 初代巡礼者回声 | CH06 | 结局/核心见证 | `[352, 272]` | idle:4, talk:8, greet:2, rest:2 | 残影显现与伸手交托（echo_manifest / entrust_gesture） |
| 11 | `npc_fugitive_scribe` | 逃亡书记 | CH03 | 剧情/见证反应 | `[422, 272]` | idle:4, talk:8, greet:2, rest:2 | 护卷回望与急切递信（guard_scroll / pass_note） |
| 12 | `npc_gate_pilgrim` | 守门朝圣者 | CH01 | 剧情/见证反应 | `[396, 275]` | idle:4, talk:8, greet:5, rest:2 | 行礼致意与望向钟门（pilgrim_bow / gaze_gate） |
| 13 | `npc_gear_cartographer` | 升台绘图师 | CH01 | 服务/工坊交互 | `[372, 254]` | idle:4, talk:8, greet:2, rest:2 | 展开海图与标注路线（map_unroll / point_route） |
| 14 | `npc_lantern_sister` | 灯影修女 | CH05 | 教学/指引手势 | `[412, 330]` | idle:6, talk:6, greet:2, rest:2 | 提灯照路与传授灯影姿态（raise_lantern / teach_gesture） |
| 15 | `npc_obsidian_guide` | 黑曜引路人 | CH05 | 教学/指引手势 | `[416, 330]` | idle:4, talk:8, greet:2, rest:2 | 举杖指路与警戒停顿（point_way / warn_halt） |
| 16 | `npc_old_gardener` | 老园丁弦伯 | CH04 | 剧情/见证反应 | `[332, 334]` | idle:4, talk:8, greet:2, rest:2 | 修剪枯枝与叹息抬头（prune_vine / sigh_look） |
| 17 | `npc_quiet_reader` | 沉默读者 | CH03 | 教学/指引手势 | `[558, 284]` | idle:4, talk:8, greet:2, rest:2 | 翻卷示范与点头回应（turn_page / nod_confirm） |
| 18 | `npc_rain_smith_liu` | 失聪铁匠柳 | CH02 | 服务/工坊交互 | `[380, 289]` | idle:4, talk:8, greet:2, rest:2 | 锻造/改制敲击与递出工具（craft_work / hand_item） |
| 19 | `npc_root_prisoner` | 根笼囚徒 | CH04 | 剧情/见证反应 | `[366, 333]` | idle:4, talk:8, greet:2, rest:2 | 靠笼抬头与伸手示意（grip_bars / reach_hint） |
| 20 | `npc_runback_scout` | 回廊斥候 | CH01 | 教学/指引手势 | `[388, 338]` | idle:4, talk:8, greet:2, rest:2 | 侦察挥手与标出捷径（beckon_shortcut / scout_watch） |
| 21 | `npc_salt_librarian_ye` | 盐页管理员叶 | CH03 | 教学/指引手势 | `[402, 330]` | idle:6, talk:8, greet:2, rest:2 | 拂去盐尘与指点书架（brush_salt / point_way） |
| 22 | `npc_sealed_archivist` | 封蜡档案员 | CH03 | 服务/工坊交互 | `[388, 327]` | idle:4, talk:8, greet:2, rest:2 | 启封蜡印与取卷交付（unseal_scroll / hand_item） |
| 23 | `npc_six_mark_keeper` | 六印守望者 | CH06 | 结局/核心见证 | `[396, 325]` | idle:4, talk:8, greet:2, rest:2 | 核验六印与展开终门仪态（inspect_seals / solemn_open） |
| 24 | `npc_sluice_nun` | 锈泵修女 | CH02 | 教学/指引手势 | `[420, 330]` | idle:4, talk:8, greet:2, rest:2 | 合十祈祷与指向闸口（pray_idle / point_sluice） |
| 25 | `npc_threadsmith_apprentice` | 织线学徒 | CH01 | 服务/工坊交互 | `[450, 331]` | idle:4, talk:8, greet:2, rest:2 | 穿针接线与交付铭饰（craft_work / hand_item） |

---

## ART-08（P2）｜六区场景层次与岩体去对称修订（V03）

台账 `V03` 确认镜像万花筒已去除，但六区 `flat_maps` 仍有两项需手绘修订的场景项：
1. **消除岩体弱对称团**：重绘 6 个群系各自的 `rock_mass_large.png`，打破残留的中心对称结构；
2. **补齐普通房间前 / 中 / 后景层次**：为 6 个群系补充可与 `parallax_layout` 随机散布配合的前景剪影件、中景建筑柱/悬吊件与远景景深切片。

| 章节 | 群系名称 | 资源目录 | 待修订/补充目标文件 |
| :---: | :--- | :--- | :--- |
| CH01 | 苔钟庭 | `godot/assets/sprites/flat_maps/moss_cavern/` | `rock_mass_large.png`（去对称）+ `decor_atlas.png` / 前中后景扩展切片 |
| CH02 | 雨铸渠 | `godot/assets/sprites/flat_maps/rain_foundry/` | `rock_mass_large.png`（去对称）+ `decor_atlas.png` / 前中后景扩展切片 |
| CH03 | 盐白档案库 | `godot/assets/sprites/flat_maps/salt_archive/` | `rock_mass_large.png`（去对称）+ `decor_atlas.png` / 前中后景扩展切片 |
| CH04 | 断弦温室 | `godot/assets/sprites/flat_maps/string_greenhouse/` | `rock_mass_large.png`（去对称）+ `decor_atlas.png` / 前中后景扩展切片 |
| CH05 | 黑曜巡礼道 | `godot/assets/sprites/flat_maps/obsidian_pilgrim/` | `rock_mass_large.png`（去对称）+ `decor_atlas.png` / 前中后景扩展切片 |
| CH06 | 沉冠核心 | `godot/assets/sprites/flat_maps/silent_crown/` | `rock_mass_large.png`（去对称）+ `decor_atlas.png` / 前中后景扩展切片 |

---

## ART-09（P3 / 长远可选）｜备用 20 Boss 图库与跨组非美术提醒

1. **备用 20 Boss 图库（`godot/assets/sprites/bosses/`）**：正式六章全部使用 `original_creatures/` 中的 6 位原创 Boss。该备用库仅在未来规划 DLC / 新增 Boss 战时，再由策划决定是重绘为原创手绘画风还是彻底退役，**不纳入 v1.0 必画排期**。
2. **跨组非美术提醒（不计入画师工时）**：`G-10` 同时记录了 `player_wall_jump` 占位复用 `player_jump.ogg`、`ch02` 室内外雨声切换与其余房间环境声（`S02`/`S03`），以及 `ch04` 花粉风机制设计；这些归属音频与关卡设计排期，不在本美术清单交付范围内。

---

## 通用绘制规范、仓库 LFS 红线与自动化验收命令

### 1. 美术质量硬门槛（打包脚本自动拦截）
- **体量一致性**：重绘后角色中位实体面积相对原片段误差 `≤ ±4%`（`BODY_AREA_TOLERANCE = 0.04`）；相邻帧面积突变不超过 `1.5×`。
- **画风一致性**：硬朗手绘线稿与清晰色块，半透明软边占比不得超过原片段 `2.5×`（`SOFT_EDGE_LIMIT = 2.5`）；高饱和强调色像素占比不得低于原片段 `55%`（`ACCENT_FLOOR = 0.55`）。
- **锚点与透明边**：地面角色严格锁定支撑脚基准（`foot_baseline` / 落脚支点），严禁飘浮、缩放跳变或武器出框裁切；禁用纯时间插值伪造帧。
- **先接入口再交付**：新增命名动作（如 `turn`/`brake`/`ambush_reveal`/契印动作）必须同步更新对应 `manifest.json` 并在脚本中登记触发入口，不可仅丢 PNG 进目录。

### 2. Git LFS 与仓库体积红线（`AGENTS.md` CI 强制）
- 单个 PR 新增或修改的非 LFS 二进制文件：单文件不得超过 **8 MiB**，总计不得超过 **60 MiB**（`tools/ci/check_binary_budget.py`）。
- 正式上线的 PNG 图集必须遵循 `.gitattributes` 走 Git LFS；**生成过程草稿、被拒候选图、多版本参考板严禁提交进 Git**（或仅在归档目录留存轻量缩略图与生成收据）。

### 3. 交付前必跑本地验收命令
```bash
# 1. 重绘质检与角色动画静态盘点（验证面积、软边、强调色、图集边界与帧引用）
python3 tools/audit_character_animation_assets.py --check

# 2. 导出引用审计与运行时素材完整性检查（确保新图集已纳入导出且零孤立/缺失引用）
python3 tools/audit_export_contents.py
npm run test:runtime-assets

# 3. 台账与 CI 卫生校验（新增美术批次 PR 须补 docs/ledger/entries/*.md）
python3 tools/build_ledger.py --validate
python3 tools/ci/contracts.py lint
```
