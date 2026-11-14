# 待美术与待新机制清单（2026-11-14）

依据：main `0c7218dba` 上的 46 项状态表（`docs/ledger/status/`）、`art_requests/creature_redraw_v1/progress.json`、`tools/creature_redraw_art.py`、`godot/data/audio_visual_manifest.json` 与运行时代码。只列代码已经准备好、卡在“缺素材”或“缺一个尚不存在的机制”的事项；只能由人验收的部分不在这里。

## 一、需要美术

### 1. 怪物动作重画：剩 56 段、1344 帧

清单共 261 段，已完成 205 段、3130 张原画。剩余按角色：

| 角色 | 段数 | 片段 |
|---|---|---|
| echo_pilgrim_commander_minor | 7 | windup、attack、minor_banner_windup／recover、minor_elite_rally_windup／本体／recover |
| isotope_lumen | 6 | windup、attack、recover、lumen_focus_windup／本体／recover |
| thorn_bloom_mote | 5 | windup、attack、bloom_seeds_windup／本体／recover |
| delayed_shadow | 5 | attack、recover、shadow_echo_windup／本体／recover |
| rain_censer_mote | 4 | windup、recover、censer_cloud_windup／recover |
| echo_contract_scribe | 4 | windup、attack、echo_scribe_seals_windup／本体 |
| echo_waterwheel_knight | 4 | attack、recover、echo_wheel_wave、echo_wheel_elite_recover |
| falling_clapper | 4 | attack、recover、clapper_wave_windup／recover |
| valve_crawler | 3 | windup、attack、valve_vent_windup |
| kneeling_crossbowman | 3 | windup、recover、crossbow_low_windup |
| silent_bugbler | 2 | attack、bugle_pulse_recover |
| waterwheel_knight | 2 | windup、recover |
| obsidian_bellwheel | 2 | bellwheel_waves、bellwheel_waves_recover |
| echo_thorn_sentinel | 2 | windup、echo_thorn_double |
| thorn_sentinel | 2 | windup、thorn_ring_windup |
| phase_censor | 1 | windup |

交付流程不变：按 `art_requests/creature_redraw_v1/` 的冻结参考出图，`tools/creature_redraw_art.py` 打包并过体量、邻帧、画风门槛。另有既有步态返工 224 张，单独记账。

### 2. 已合并但需复看的 7 段：强调色丢失

画风门槛（#638）合并前进入 main 的片段里，有 7 段的高饱和像素占比不到被替换原片段的 55%（纹样、红色部件变淡或消失）。它们按源图指纹登记在 `LEGACY_ACCENT_SOURCES`，重画时会重新受检：

| 角色 / 片段 | 说明 |
|---|---|
| bronze_moth / moth_dust | 最严重，强调色只剩原来的约 23% |
| bronze_moth / moth_dust_windup | |
| bronze_moth / moth_dust_recover | |
| bronze_moth / windup | |
| corridor_heavy / heavy_stamp | |
| index_scribe / attack | |
| saltwhite_contract_judge / windup | |

建议先由人对照原片段看一遍，确认需要重画的再出图。

### 3. 转身、急停衔接帧：45 个角色未做

46 种怪物里只有苔铃幼虫（moss_larva）有转身（`turn`）和急停（`brake`）片段（V02）。其余 45 种没有这两类片段。运行时的衔接框架已就绪（`enemy_motion_transitions`），补的是每个角色按运动类型各一套原画。

### 4. NPC 其余交互动作

25 位 NPC 已有待机、招呼、发声、聆听 400 帧（V02）。台账 V02 的“下一步”列着“NPC 其余交互”，具体要补哪些动作还没有定，需要先列出动作清单再出图。

### 5. 伏击、报警、支援的专属动作帧（B01）

这三种战术职责的行为、声音和画面提示都已实现：现身、报警、支援各有专属音效和光环，现身后停顿 0.35 秒（`enemy_actor.gd::_role_cue`）。缺的是角色本身的专属动作帧（台账 B01 标为“需美术”）。

### 6. 能力门牌（A01 / V01）

能力门上的图标目前是代码绘制的图形（`ability_gate_sign.gd`，7 种能力各一个），可读但不是手绘画风。需要 7 枚手绘门牌图标，替换后代码只需换贴图。

### 7. 场景美术（V03）

- 岩体仍有较弱的对称团（镜像万花筒已去掉）。
- 普通房间缺前、中、后景层次。

两项都需要新的场景素材或手绘修订，改完需要人看效果。

### 8. 房间专属声源（S03）

六区 24 个房间已有底声和固定声源。其余房间还没有专属来源声，需要新的环境声素材。

## 二、需要新机制

### 1. 花粉风（断弦温室）

断弦温室第 2 拍的声音素材已备好（`ch04_broken_string_greenhouse_beat_02_audio`，清单状态 `asset_ready`），但地区里没有“花粉风”这个机制：既没有风的触发区，也没有对玩家或场景的作用。要先设计这个机制（只是氛围，还是会推动玩家／吹开花粉遮挡），再接声音。

### 2. 按用途重排房间（W02）

台账 W02 的剩余内容：按生产、居住用途设计房间与灾变、挑战分布，拆掉复制出来的检修工房和长跳台链。这是关卡设计改动，需要先定每个地区的用途方案，再改地图数据，过 `audit_stranding`、`audit_shortcut_bypass` 等审计。

## 三、本次核对时更正的过时记录

台账 S02 的“下一步”仍写着“钟道启程／到站的场景音仍等对应机制”。实际上钟道（钟龛回访网络）已经存在，三段声音都已接线：`bellway_transit_loop` 由 `audio_director.gd::_update_transit_loop` 播放，`bellway_depart`／`bellway_arrive` 由 `shrine_return_network.gd` 在出发和到站时触发。本 PR 同时把 S02 那一行改为只剩花粉风。
