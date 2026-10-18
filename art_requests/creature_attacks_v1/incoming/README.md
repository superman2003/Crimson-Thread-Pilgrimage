# 专属攻击源图：逐张上传记录

依据 PR #107 的逐格说明，内置 image_gen 生图；每张上传成功并验证远端分支后，才生成下一张。

已交付源图 **82 张、760 格**；本次补齐最后 **11 张、110 格**。每张只保留选定源图、实际提示词和逐帧坐标记录。

生成器保留原生透明 PNG 字节，实际画布尺寸见同名 JSON，与提示词请求尺寸有差异；不要直接等格切片。角色骨架缩放、根节点、阶段衔接和循环播放仍需运行时验收，源图数量齐全不代表最终动作验收通过。

| 角色 | 已上传图 | 帧数 |
| --- | --- | ---: |
| ash_banner_imp | [imp_retreat.png](imp_retreat.png) | 12 |
| bell_mote | [mote_seek.png](mote_seek.png) | 14 |
| bellroot_acolyte | [root_bell_wave.png](root_bell_wave.png) | 14 |
| bronze_moth | [moth_dust.png](moth_dust.png) | 12 |
| bronze_moth | [moth_dive_loops.png](moth_dive_loops.png) | 2 |
| corridor_heavy | [heavy_stamp.png](heavy_stamp.png) | 14 |
| corridor_heavy | [heavy_elite_quake.png](heavy_elite_quake.png) | 14 |
| corridor_heavy | [heavy_roll_loops.png](heavy_roll_loops.png) | 4 |
| delayed_shadow | [shadow_echo.png](shadow_echo.png) | 12 |
| delayed_shadow | [shadow_blink_loops.png](shadow_blink_loops.png) | 2 |
| drain_leech | [leech_leap.png](leech_leap.png) | 14 |
| echo_contract_scribe | [echo_scribe_seals.png](echo_scribe_seals.png) | 12 |
| echo_contract_scribe | [echo_scribe_pages_loops.png](echo_scribe_pages_loops.png) | 2 |
| echo_moss_larva | [echo_larva_mark.png](echo_larva_mark.png) | 12 |
| echo_moss_larva | [echo_larva_burrow_loops.png](echo_larva_burrow_loops.png) | 4 |
| echo_pilgrim_commander_minor | [minor_banner.png](minor_banner.png) | 14 |
| echo_pilgrim_commander_minor | [minor_elite_rally.png](minor_elite_rally.png) | 14 |
| echo_pilgrim_commander_minor | [minor_lances_loops.png](minor_lances_loops.png) | 2 |
| echo_thorn_sentinel | [echo_thorn_double.png](echo_thorn_double.png) | 14 |
| echo_thorn_sentinel | [echo_thorn_roots_loops.png](echo_thorn_roots_loops.png) | 2 |
| echo_waterwheel_knight | [echo_wheel_wave.png](echo_wheel_wave.png) | 14 |
| echo_waterwheel_knight | [echo_wheel_elite.png](echo_wheel_elite.png) | 14 |
| echo_waterwheel_knight | [echo_wheel_guard_loops.png](echo_wheel_guard_loops.png) | 2 |
| erasure_bailiff | [bailiff_erase.png](bailiff_erase.png) | 14 |
| erasure_bailiff | [bailiff_elite_sweep.png](bailiff_elite_sweep.png) | 14 |
| erasure_bailiff | [bailiff_cleave_loops.png](bailiff_cleave_loops.png) | 2 |
| falling_clapper | [clapper_wave.png](clapper_wave.png) | 14 |
| falling_clapper | [clapper_fall_loops.png](clapper_fall_loops.png) | 4 |
| gear_sentinel | [gear_guard.png](gear_guard.png) | 14 |
| gear_sentinel | [gear_elite_spin.png](gear_elite_spin.png) | 16 |
| index_scribe | [index_seal.png](index_seal.png) | 12 |
| index_scribe | [index_pages_loops.png](index_pages_loops.png) | 2 |
| isotope_lumen | [lumen_focus.png](lumen_focus.png) | 12 |
| isotope_lumen | [lumen_orbits_loops.png](lumen_orbits_loops.png) | 2 |
| kneeling_crossbowman | [crossbow_low.png](crossbow_low.png) | 14 |
| kneeling_crossbowman | [crossbow_burst_loops.png](crossbow_burst_loops.png) | 2 |
| moss_larva | [larva_snap.png](larva_snap.png) | 12 |
| moss_larva | [larva_curl_loops.png](larva_curl_loops.png) | 2 |
| obsidian_bellwheel | [bellwheel_waves.png](bellwheel_waves.png) | 14 |
| obsidian_bellwheel | [bellwheel_roll_loops.png](bellwheel_roll_loops.png) | 4 |
| obsidian_spearman | [obsidian_raise.png](obsidian_raise.png) | 12 |
| obsidian_spearman | [obsidian_elite_impale.png](obsidian_elite_impale.png) | 16 |
| obsidian_spearman | [obsidian_thrust_loops.png](obsidian_thrust_loops.png) | 2 |
| page_duelist | [page_feint.png](page_feint.png) | 12 |
| page_duelist | [page_elite_flurry.png](page_elite_flurry.png) | 16 |
| page_duelist | [page_combo_loops.png](page_combo_loops.png) | 2 |
| phase_censor | [censor_blink.png](censor_blink.png) | 14 |
| phase_censor | [censor_fan_loops.png](censor_fan_loops.png) | 2 |
| pilgrim_chariot | [chariot_caltrops.png](chariot_caltrops.png) | 14 |
| pilgrim_chariot | [chariot_elite_drift.png](chariot_elite_drift.png) | 16 |
| pilgrim_chariot | [chariot_charge_loops.png](chariot_charge_loops.png) | 4 |
| pipe_thrower | [pipe_mortar.png](pipe_mortar.png) | 14 |
| pipe_thrower | [pipe_backblast_loops.png](pipe_backblast_loops.png) | 2 |
| pollen_lutist | [pollen_spots.png](pollen_spots.png) | 14 |
| pollen_lutist | [pollen_arcs_loops.png](pollen_arcs_loops.png) | 2 |
| rain_censer_mote | [censer_cloud.png](censer_cloud.png) | 12 |
| rain_censer_mote | [censer_rain_loops.png](censer_rain_loops.png) | 2 |
| root_cage_hunter | [cage_pounce.png](cage_pounce.png) | 14 |
| root_cage_hunter | [cage_elite_snare.png](cage_elite_snare.png) | 14 |
| root_cage_hunter | [cage_net_loops.png](cage_net_loops.png) | 2 |
| rust_diver | [diver_splash.png](diver_splash.png) | 14 |
| rust_diver | [diver_vault_loops.png](diver_vault_loops.png) | 2 |
| salt_bookmite | [book_bite.png](book_bite.png) | 12 |
| salt_bookmite | [book_burrow_loops.png](book_burrow_loops.png) | 2 |
| silent_bugbler | [bugle_pulse.png](bugle_pulse.png) | 14 |
| silent_bugbler | [bugle_volley_loops.png](bugle_volley_loops.png) | 2 |
| spore_bellmaker | [bell_fungus.png](bell_fungus.png) | 12 |
| spore_bellmaker | [bell_spores_loops.png](bell_spores_loops.png) | 2 |
| summoned_page | [page_orbit.png](page_orbit.png) | 14 |
| summoned_page | [page_skim_loops.png](page_skim_loops.png) | 2 |
| thorn_bloom_mote | [bloom_seeds.png](bloom_seeds.png) | 14 |
| thorn_sentinel | [thorn_ring.png](thorn_ring.png) | 14 |
| valve_crawler | [valve_vent.png](valve_vent.png) | 14 |
| valve_crawler | [valve_roll_loops.png](valve_roll_loops.png) | 2 |
| vine_crawler | [vine_roots.png](vine_roots.png) | 14 |
| waterwheel_knight | [wheel_return.png](wheel_return.png) | 14 |
| waterwheel_knight | [wheel_elite_ride.png](wheel_elite_ride.png) | 16 |
| waterwheel_knight | [wheel_charge_loops.png](wheel_charge_loops.png) | 2 |
| wax_bee | [bee_stingers.png](bee_stingers.png) | 14 |
| wax_bee | [bee_dive_loops.png](bee_dive_loops.png) | 4 |
| wax_lancer | [wax_high.png](wax_high.png) | 12 |
| wax_lancer | [wax_charge_loops.png](wax_charge_loops.png) | 4 |

同名 .txt 为实际提示词，.json 为参考/图像哈希、逐帧坐标和目检记录。源图保留原生成字节，尚未接入运行时；动作质量与连续循环仍需项目方验收。

重画记录（2026-10-18）：`wheel_elite_ride.png` — 以原参考和已认可的 wheel_return 为标尺，将轮盾缩为站立高度约一半，接地盾顶位于腰胸之间；保留 16 格并修正重复盾牌。

重画记录（2026-10-18）：`bee_stingers.png` — 重画为大幅腹部下卷及前伸，第 5／7 格分别为两次明显腹刺前弹，第 6／8 格后坐；清除两格出招中多余的后向尾刺，保留 14 格。

重画记录（2026-10-18）：`wax_high.png` — 重画前四格前摇，枪尖明显低于双手并压到前脚脚底线附近；出招逐步上挑，收招四格恢复竖枪，保留 12 格。

重画记录（2026-10-18）：`crossbow_low.png` — 单膝跪地、拉弦、低位瞄准、明显后坐及起身回收分开绘制；保留 14 格与原骨弩比例。

重画记录（2026-10-18）：`echo_wheel_wave.png` — 14 格均保留原长剑与一面轮盾，分开抬盾、下砸推进及回收动作，补回原版缺失的剑。

重画记录（2026-10-18）：`echo_wheel_elite.png` — 长剑在 14 格全程可见；第 6–9 格持盾手为空，接回后只保留一面盾牌，移除投盾残影。

重画记录（2026-10-18）：`echo_thorn_double.png` — 第 6–8 格改为直立张开双臂，第 7 格全身附着甲片外翻，红刃向后下方展开；不再画成前刺，保留 14 格。

重画记录（2026-10-18）：`bloom_seeds.png` — 第 6–8 格整只倒立，绿色荆棘背壳在上、金色核心朝下，并区分左右抖动；第 13–14 格均朝上盛开，保留 14 格。
