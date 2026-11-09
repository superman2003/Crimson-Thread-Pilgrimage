# 敌人动作素材逐项盘点（自动生成）

审计基线：`ec31dbf79ca2729103fc9d90817d2470b9777c05`。范围为正式六章、可选挑战敌人和二十 Boss 备用库。

共 40 种小怪、6 位正式 Boss；小怪 90 条攻击（含 10 条精英专属），Boss 24 条攻击。
检查 1996 张身体图集、8416 个帧引用；缺少基础动作或无效资源：0。

未取得本地 LFS 实体的图片：0；若非零，相关图片仅验证 Git 指针及动画登记，不能据此宣称像素资源验收完成。

帧数指 manifest 引用数；`unique_regions` 记录不同图集区域，不等于新画姿势数。本次只检查 Git 中的 PNG、尺寸、裁切边界、动作选择和特效登记，不证明动作顺滑、碰撞同步或自然通关。

正式读取优先级：`boss_behavior_manifest` → `combat_motion_v7_manifest` → `motion_manifest` → `manifest`。左右采用水平翻转；没有单独左右图不计作缺失。

十二帧是每个阶段的数量，通常三段合计 36 个姿势引用。平滑程度还取决于时长：`姿势更新率 = 帧数 / 秒数`。下列 Boss 名义更新率依据配置计算；连击子节拍和运行时改写时长需单独测量，不等于渲染 FPS。

## 40 种小怪

每行均有待机、移动、前摇、出手、收招、受击、死亡。驻足怪的 `walk` 存在不代表其 AI 会行走；飞行怪的 `walk` 表示飞行循环。

| 章节 / kind | 移动方式 | 待机 / 移动 / 受击 / 死亡 | 攻击 → 实际身体动画（前摇 / 出手 / 收招帧数） |
| --- | --- | --- | --- |
| 1 / `moss_larva` | ground | 4/8/4/4 | `larva_snap` → `larva_snap` (12/12/12)<br>`larva_curl` → `attack` (12/12/12) |
| 1 / `bronze_moth` | flight | 4/8/4/4 | `moth_dive` → `attack` (12/12/12)<br>`moth_dust` → `moth_dust` (12/12/12) |
| 1 / `spore_bellmaker` | stationary | 4/8/2/4 | `bell_spores` → `attack` (12/12/12)<br>`bell_fungus` → `bell_fungus` (12/12/12) |
| 1 / `gear_sentinel` | ground | 4/8/5/3 | `gear_guard` → `gear_guard` (12/12/12)<br>`gear_spear` → `attack` (12/12/12)<br>精英 `gear_elite_spin` → `gear_elite_spin` (12/12/12) |
| 1 / `corridor_heavy` | ground | 4/8/4/4 | `heavy_roll` → `attack` (12/12/12)<br>`heavy_stamp` → `heavy_stamp` (12/12/12)<br>精英 `heavy_elite_quake` → `heavy_elite_quake` (12/12/12) |
| 1 / `bellroot_acolyte` | ground | 4/8/4/4 | `root_staff` → `attack` (12/12/12)<br>`root_bell_wave` → `root_bell_wave` (12/12/12) |
| 2 / `drain_leech` | ground | 4/8/2/3 | `leech_drain` → `attack` (12/12/12)<br>`leech_leap` → `leech_leap` (12/12/12) |
| 2 / `pipe_thrower` | stationary | 4/8/3/4 | `pipe_mortar` → `pipe_mortar` (12/12/12)<br>`pipe_backblast` → `attack` (12/12/12) |
| 2 / `valve_crawler` | ground | 4/8/4/4 | `valve_roll` → `attack` (12/12/12)<br>`valve_vent` → `valve_vent` (12/12/12) |
| 2 / `bell_mote` | flight | 4/8/4/4 | `mote_seek` → `mote_seek` (12/12/12)<br>`mote_peck` → `attack` (12/12/12) |
| 2 / `rain_censer_mote` | flight | 4/8/4/4 | `censer_rain` → `attack` (12/12/12)<br>`censer_cloud` → `censer_cloud` (12/12/12) |
| 2 / `waterwheel_knight` | ground | 4/8/4/4 | `wheel_charge` → `attack` (12/12/12)<br>`wheel_return` → `wheel_return` (12/12/12)<br>精英 `wheel_elite_ride` → `wheel_elite_ride` (12/12/12) |
| 2 / `rust_diver` | ground | 4/8/2/3 | `diver_vault` → `attack` (12/12/12)<br>`diver_splash` → `diver_splash` (12/12/12) |
| 3 / `salt_bookmite` | ground | 6/8/3/3 | `book_burrow` → `attack` (12/12/12)<br>`book_bite` → `book_bite` (12/12/12) |
| 3 / `index_scribe` | stationary | 4/8/4/4 | `index_pages` → `attack` (12/12/12)<br>`index_seal` → `index_seal` (12/12/12) |
| 3 / `page_duelist` | ground | 4/8/3/4 | `page_feint` → `page_feint` (12/12/12)<br>`page_combo` → `attack` (12/12/12)<br>精英 `page_elite_flurry` → `page_elite_flurry` (12/12/12) |
| 3 / `wax_lancer` | ground | 4/8/3/4 | `wax_charge` → `attack` (12/12/12)<br>`wax_high` → `wax_high` (12/12/12) |
| 3 / `summoned_page` | flight | 4/8/3/4 | `page_orbit` → `page_orbit` (12/12/12)<br>`page_skim` → `attack` (12/12/12) |
| 3 / `erasure_bailiff` | ground | 4/8/4/3 | `bailiff_cleave` → `attack` (12/12/12)<br>`bailiff_erase` → `bailiff_erase` (12/12/12)<br>精英 `bailiff_elite_sweep` → `bailiff_elite_sweep` (12/12/12) |
| 4 / `vine_crawler` | ground | 4/8/4/4 | `vine_bite` → `attack` (12/12/12)<br>`vine_roots` → `vine_roots` (12/12/12) |
| 4 / `root_cage_hunter` | ground | 4/8/4/4 | `cage_net` → `attack` (12/12/12)<br>`cage_pounce` → `cage_pounce` (12/12/12)<br>精英 `cage_elite_snare` → `cage_elite_snare` (12/12/12) |
| 4 / `thorn_sentinel` | stationary | 4/8/4/4 | `thorn_ring` → `thorn_ring` (12/12/12)<br>`thorn_wall` → `attack` (12/12/12) |
| 4 / `thorn_bloom_mote` | flight | 4/8/4/4 | `bloom_seeds` → `bloom_seeds` (12/12/12)<br>`bloom_needle` → `attack` (12/12/12) |
| 4 / `wax_bee` | flight | 4/8/4/4 | `bee_dive` → `attack` (12/12/12)<br>`bee_stingers` → `bee_stingers` (12/12/12) |
| 4 / `pollen_lutist` | stationary | 4/8/4/4 | `pollen_arcs` → `attack` (12/12/12)<br>`pollen_spots` → `pollen_spots` (12/12/12) |
| 5 / `obsidian_spearman` | ground | 4/8/4/4 | `obsidian_thrust` → `attack` (12/12/12)<br>`obsidian_raise` → `obsidian_raise` (12/12/12)<br>精英 `obsidian_elite_impale` → `obsidian_elite_impale` (12/12/12) |
| 5 / `pilgrim_chariot` | ground | 4/8/4/4 | `chariot_charge` → `attack` (12/12/12)<br>`chariot_caltrops` → `chariot_caltrops` (12/12/12)<br>精英 `chariot_elite_drift` → `chariot_elite_drift` (12/12/12) |
| 5 / `silent_bugbler` | stationary | 4/8/3/3 | `bugle_volley` → `attack` (12/12/12)<br>`bugle_pulse` → `bugle_pulse` (12/12/12) |
| 5 / `ash_banner_imp` | ground | 4/8/3/3 | `imp_flurry` → `attack` (12/12/12)<br>`imp_retreat` → `imp_retreat` (12/12/12) |
| 5 / `phase_censor` | flight | 4/8/4/4 | `censor_blink` → `censor_blink` (12/12/12)<br>`censor_fan` → `attack` (12/12/12) |
| 5 / `obsidian_bellwheel` | ground | 4/8/4/4 | `bellwheel_roll` → `attack` (12/12/12)<br>`bellwheel_waves` → `bellwheel_waves` (12/12/12) |
| 5 / `kneeling_crossbowman` | stationary | 4/8/4/4 | `crossbow_burst` → `attack` (12/12/12)<br>`crossbow_low` → `crossbow_low` (12/12/12) |
| 6 / `echo_waterwheel_knight` | ground | 4/8/4/4 | `echo_wheel_guard` → `attack` (12/12/12)<br>`echo_wheel_wave` → `echo_wheel_wave` (12/12/12)<br>精英 `echo_wheel_elite` → `echo_wheel_elite` (12/12/12) |
| 6 / `echo_moss_larva` | ground | 4/8/4/4 | `echo_larva_burrow` → `attack` (12/12/12)<br>`echo_larva_mark` → `echo_larva_mark` (12/12/12) |
| 6 / `echo_thorn_sentinel` | stationary | 4/8/2/3 | `echo_thorn_double` → `echo_thorn_double` (12/12/12)<br>`echo_thorn_roots` → `attack` (12/12/12) |
| 6 / `falling_clapper` | flight | 4/8/4/4 | `clapper_fall` → `attack` (12/12/12)<br>`clapper_wave` → `clapper_wave` (12/12/12) |
| 6 / `echo_contract_scribe` | flight | 4/8/4/4 | `echo_scribe_pages` → `attack` (12/12/12)<br>`echo_scribe_seals` → `echo_scribe_seals` (12/12/12) |
| 6 / `delayed_shadow` | flight | 4/8/4/4 | `shadow_blink` → `attack` (12/12/12)<br>`shadow_echo` → `shadow_echo` (12/12/12) |
| 6 / `echo_pilgrim_commander_minor` | ground | 4/8/4/4 | `minor_lances` → `attack` (12/12/12)<br>`minor_banner` → `minor_banner` (12/12/12)<br>精英 `minor_elite_rally` → `minor_elite_rally` (12/12/12) |
| 6 / `isotope_lumen` | flight | 4/8/4/4 | `lumen_orbits` → `attack` (12/12/12)<br>`lumen_focus` → `lumen_focus` (12/12/12) |

## 六位正式 Boss

名称来自章节配置；旧目录 kind、历史报告名称与当前显示名可能不同。每位 Boss 的四条攻击分别核对，避免把通用名字 `heavy/cast/phase` 误判成没做专属动作。

### 苔钟守母 · `rust_crown_guardian`

实际清单：[boss_behavior_manifest.json](../../godot/assets/sprites/original_creatures/rust_crown_guardian/boss_behavior_manifest.json)。

- `idle` 8 帧；`walk` 16 帧；`backstep` 12 帧；`ready_guard` 6 帧；`ready_settle` 6 帧；`hurt` 2 帧；`death` 4 帧。

- 苔镰横扫 `boss_moss_scythe` → `windup` → `attack` → `recover`，12/12/12 帧；配置时长 0.68/0.28/0.76 秒；名义姿势更新率 17.65/42.86/15.79 次/秒。
- 钟冠重压 `boss_moss_stamp` → `heavy_windup` → `heavy` → `heavy_recover`，12/12/12 帧；配置时长 0.86/0.3/0.95 秒；名义姿势更新率 13.95/40.0/12.63 次/秒。
- 守庭孢子 `boss_moss_spores` → `cast_windup` → `cast` → `cast_recover`，12/12/12 帧；配置时长 1.05/0.3/0.84 秒；名义姿势更新率 11.43/40.0/14.29 次/秒。
- 根冠苏醒 `boss_moss_roots` → `phase_windup` → `phase` → `phase_recover`，12/12/12 帧；配置时长 0.95/0.3/1.35 秒；名义姿势更新率 12.63/40.0/8.89 次/秒。

四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。

### 绯线执剪者 · `sunken_hammer_smith`

实际清单：[boss_behavior_manifest.json](../../godot/assets/sprites/original_creatures/sunken_hammer_smith/boss_behavior_manifest.json)。

- `idle` 8 帧；`walk` 16 帧；`backstep` 12 帧；`ready_guard` 6 帧；`ready_settle` 6 帧；`hurt` 2 帧；`death` 4 帧。

- 合剪夹击 `boss_shears_close` → `heavy_windup` → `heavy` → `heavy_recover`，12/12/12 帧；配置时长 0.78/0.26/0.88 秒；名义姿势更新率 15.38/46.15/13.64 次/秒。
- 绯线封路 `boss_shears_thread` → `cast_windup` → `cast` → `cast_recover`，12/12/12 帧；配置时长 1.1/0.28/1.0 秒；名义姿势更新率 10.91/42.86/12.0 次/秒。
- 断线结阵 `boss_shears_knots` → `windup` → `attack` → `recover`，12/12/12 帧；配置时长 0.9/0.28/1.1 秒；名义姿势更新率 13.33/42.86/10.91 次/秒。
- 跃转双剪 `boss_shears_turn` → `phase_windup` → `phase` → `phase_recover`，12/12/12 帧；配置时长 0.76/0.8/1.12 秒；名义姿势更新率 15.79/15.0/10.71 次/秒。

四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。

### 灰冠螳将 · `saltwhite_contract_judge`

实际清单：[boss_behavior_manifest.json](../../godot/assets/sprites/original_creatures/saltwhite_contract_judge/boss_behavior_manifest.json)。

- `idle` 8 帧；`walk` 16 帧；`backstep` 12 帧；`ready_guard` 6 帧；`ready_settle` 6 帧；`hurt` 4 帧；`death` 4 帧。

- 交刃反击 `boss_mantis_guard` → `cast_windup` → `cast` → `cast_recover`，12/12/12 帧；配置时长 0.62/0.46/0.66 秒；名义姿势更新率 19.35/26.09/18.18 次/秒。
- 灰冠长突 `boss_mantis_lunge` → `windup` → `attack` → `recover`，12/12/12 帧；配置时长 0.58/0.34/0.82 秒；名义姿势更新率 20.69/35.29/14.63 次/秒。
- 冠刃下劈 `boss_mantis_overhead` → `heavy_windup` → `heavy` → `heavy_recover`，12/12/12 帧；配置时长 0.96/0.26/1.02 秒；名义姿势更新率 12.5/46.15/11.76 次/秒。
- 左右三连斩 `boss_mantis_flurry` → `phase_windup` → `phase` → `phase_recover`，12/12/12 帧；配置时长 0.76/1.08/1.24 秒；名义姿势更新率 15.79/11.11/9.68 次/秒。

四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。

### 铜根主教 · `broken_string_gardener`

实际清单：[boss_behavior_manifest.json](../../godot/assets/sprites/original_creatures/broken_string_gardener/boss_behavior_manifest.json)。

- `idle` 8 帧；`walk` 16 帧；`backstep` 12 帧；`ready_guard` 6 帧；`ready_settle` 6 帧；`hurt` 4 帧；`death` 4 帧。

- 根杖敲击 `boss_bishop_staff` → `heavy_windup` → `heavy` → `heavy_recover`，12/12/12 帧；配置时长 0.88/0.28/0.96 秒；名义姿势更新率 13.64/42.86/12.5 次/秒。
- 藤种布道 `boss_bishop_seeds` → `cast_windup` → `cast` → `cast_recover`，12/12/12 帧；配置时长 1.08/0.3/0.86 秒；名义姿势更新率 11.11/40.0/13.95 次/秒。
- 循地根刺 `boss_bishop_roots` → `windup` → `attack` → `recover`，12/12/12 帧；配置时长 1.0/0.28/1.16 秒；名义姿势更新率 12.0/42.86/10.34 次/秒。
- 交错根笼 `boss_bishop_cage` → `phase_windup` → `phase` → `phase_recover`，12/12/12 帧；配置时长 1.2/0.3/1.5 秒；名义姿势更新率 10.0/40.0/8.0 次/秒。

四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。

### 镜池新娘 · `silent_pilgrim_commander`

实际清单：[boss_behavior_manifest.json](../../godot/assets/sprites/original_creatures/silent_pilgrim_commander/boss_behavior_manifest.json)。

- `idle` 8 帧；`walk` 16 帧；`backstep` 12 帧；`ready_guard` 6 帧；`ready_settle` 6 帧；`hurt` 2 帧；`death` 4 帧。

- 镜杖弧扫 `boss_bride_crescent` → `heavy_windup` → `heavy` → `heavy_recover`，12/12/12 帧；配置时长 0.64/0.28/0.8 秒；名义姿势更新率 18.75/42.86/15.0 次/秒。
- 镜像侧刺 `boss_bride_mirror` → `cast_windup` → `cast` → `cast_recover`，12/12/12 帧；配置时长 1.05/0.28/0.94 秒；名义姿势更新率 11.43/42.86/12.77 次/秒。
- 镜池迟影 `boss_bride_pools` → `windup` → `attack` → `recover`，12/12/12 帧；配置时长 0.94/0.3/1.1 秒；名义姿势更新率 12.77/40.0/10.91 次/秒。
- 月镜掠袭 `boss_bride_dash` → `phase_windup` → `phase` → `phase_recover`，12/12/12 帧；配置时长 0.72/0.66/1.08 秒；名义姿势更新率 16.67/18.18/11.11 次/秒。

四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。

### 百钥守门人 · `silent_crown_core`

实际清单：[boss_behavior_manifest.json](../../godot/assets/sprites/original_creatures/silent_crown_core/boss_behavior_manifest.json)。

- `idle` 8 帧；`walk` 16 帧；`backstep` 12 帧；`ready_guard` 6 帧；`ready_settle` 6 帧；`hurt` 3 帧；`death` 4 帧。

- 百钥重劈 `boss_key_cleave` → `heavy_windup` → `heavy` → `heavy_recover`，12/12/12 帧；配置时长 0.98/0.3/1.04 秒；名义姿势更新率 12.24/40.0/11.54 次/秒。
- 回旋钥阵 `boss_key_return` → `cast_windup` → `cast` → `cast_recover`，12/12/12 帧；配置时长 1.12/0.28/1.16 秒；名义姿势更新率 10.71/42.86/10.34 次/秒。
- 冠门封线 `boss_key_gate` → `phase_windup` → `phase` → `phase_recover`，12/12/12 帧；配置时长 1.24/0.3/1.4 秒；名义姿势更新率 9.68/40.0/8.57 次/秒。
- 钥环震地 `boss_key_rings` → `windup` → `attack` → `recover`，12/12/12 帧；配置时长 1.02/0.3/1.4 秒；名义姿势更新率 11.76/40.0/8.57 次/秒。

四招均有完整前摇、出手、收招和专属特效登记；本次未发现两条指令选中同一身体动画。

## 二十 Boss 备用素材库

此库有动作，不应列为“缺失二十套 Boss”。正式六章由 `kind` 选择 `original_creatures`，因此注册表旧 `godot_demo_refs` 不等于这些图集正在被正式演员使用。未来增加对应战斗时，需要单独完成配置、AI、时钟和实机验收。

| 编号 | 素材库名称 | walk 左/右 | attack 左/右 | 三套特殊攻击左/右 |
| --- | --- | --- | --- | --- |
| boss_01 | 苔钟守母 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_02 | 绯线执剪者 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_03 | 灰冠螳将 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_04 | 铜根主教 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_05 | 镜池新娘 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_06 | 百钥看门人 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_07 | 烛脊兽 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_08 | 无面钟童 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_09 | 铁蔷薇女爵 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_10 | 菌墓驮碑者 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_11 | 金翅验尸官 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_12 | 绣骨圣徒 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_13 | 黑钟骑士 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_14 | 雨廊盲乐师 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_15 | 赤茧产婆 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_16 | 断阶巡礼王 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_17 | 银槲鹿灵 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_18 | 砂漏修女 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_19 | 青焰墓钟 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |
| boss_20 | 绯庭终礼者 | 16/16 | 8/8 | 8/8; 8/8; 8/8 |

## 静态错误

未发现缺少基础动作、攻击阶段、身体图集或越界裁切。

详细帧引用、可选命名动作缺口、每条招式和具体遭遇见同目录 JSON。制作优先级和人工验收清单见 [审计结论](20261109_character_animation_checklist.md)。
