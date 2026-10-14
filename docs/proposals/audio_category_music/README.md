# 六城补全：29首候选音乐

此包补充 reverse_music_v2 的12首探索/Boss候选曲。所有文件仍为提案，**没有接入运行时，也没有人工听感批准**。每项 human_listening_review=pending。所有音色来自可审阅的数学合成，不含外部录音、人声表演或素材库。

## 覆盖与设计

- 六区各一首 combat_layer 和 lullaby，共12首。拍速、区域调式和动机与旧包对应；战斗层改写为稀疏节奏应答，摇篮曲改写为跨小节呼吸。并非将探索曲移调或变速。循环为8小节；区域原曲16小节时，本包对齐其和声周期但不要求实际运行时相位锁定。实际 AudioDirector 独立启动战斗播放器，未来必须试听随机进入的叠加效果。
- 最终Boss三乐章共3首，映射 silent_crown_core 与 set_boss_phase(1/2/3)。分别采用空白双音、五城交错证词、绯线下降句；沿用实际HP三等分切换机制。
- 三个结局共3首：ending_a 重鸣保留压抑低音，ending_b 断冠由断裂钟令转向独立声部，ending_c 绯线改写以六区回答共同收束。非循环，尾端衰减。
- 钟道候车循环、离站和到站短句共3首。两条短句各6秒，分别上行未决与下行停驻。
- 5条已实现支线各有独立主题：bring_names_home、root_rescue、wax_lamps、lantern_watch、deserter_order。另有印记修复、守门者见证、王冠告解3首，合计8首。

音符、时值、声部与声像的完整乐谱在 score_events.json；每曲的拍网与分句边界在 manifest.json。NPC/任务主题映射为**未来选曲建议**，当前没有专用音乐切换入口；不可据此声称已实现新剧情或触发机制。

## 真实来源与映射

以 godot/scripts/audio_director.gd 的 CHAPTER_SLUGS、FINAL_BOSS_MOVEMENTS、STINGER_TRACKS、BELLWAY_TRANSIT_LOOP 为路径依据。manifest 的 existing_runtime_path 是已有运行文件目标名称，file 才是本候选包文件。角色和支线以 godot/data/world_narrative.json 为准，其17位NPC全部在下面的主题关联覆盖中出现；并不声称每位有独占曲目。章节描述里没有落地的烧三面旗任务未用于编写新机制。

|主题|实际NPC或机制|
|---|---|
|把名字带回来|npc_threadsmith_apprentice、npc_canal_child、npc_fugitive_scribe；quest_bring_names_complete；crimson印记|
|西门的灯|npc_root_prisoner；quest_root_rescue_complete|
|补好检修灯|npc_beeswax_vendor；quest_wax_lamps_complete|
|灯不召兵|npc_lantern_sister、npc_obsidian_guide；quest_lantern_watch_complete|
|不用回答的军号|npc_deserter_flagbearer、npc_blind_bell_knight；quest_deserter_order_complete|
|旧印归手|npc_rain_smith_liu、npc_salt_librarian_ye；seal_bell_repaired、seal_salt_restored|
|守门者的证词|npc_old_gardener、npc_broken_singer；testimony_04|
|第一百零一把钥匙|npc_first_pilgrim_echo、npc_crown_tongue、npc_six_mark_keeper、npc_black_tide_child；testimony_06|

结局后世界旗标（world_bells_restored、world_crown_severed、world_contract_rewritten 等）由原数据定义，三个结局曲表达相应状态，不增加世界旗标。本包不替代运行音效，也不改旧包的探索/Boss候选曲。

## 重建与验证

```sh
python -m pip install -r tools/proposals/audio_category_music/requirements.txt
python tools/proposals/audio_category_music/build.py
python tools/proposals/audio_category_music/verify_rebuild.py
```

需要 ffmpeg/ffprobe（libvorbis）。固定随机种子、48kHz立体声、Vorbis q0、bitexact标志和Ogg序列号。确定性保证针对 validation.json 记录的相同工具链，不承诺不同FFmpeg版本的编码比特一致。verify_rebuild.py 在重建前后比较整个包、乐谱和量化报告的SHA-256，实际再次执行全套合成。

量化闸门：每曲<350000字节、合集<6000000字节、解码帧数精确、真峰值<-3dBTP、目标响度±0.5LU、循环接缝步进不大于max(0.006,内部步进P99×4)。loop_end_sample_exclusive 为排他端点；音符尾音和反射在循环边界环形叠加，无首尾硬淡出。接缝量化只说明瞬态技术条件，不能替代循环听感评审。

推荐增益是候选资源试听增益，**不是覆盖 AudioDirector 现有音量常数的授权**。叠加探索、战斗、环境、对话duck及Boss切换的最终响度需接入阶段在游戏内审核。

## 本轮量化结果

29/29首通过技术闸门，OGG合计2,630,027字节，最大单曲185,549字节。最坏4倍过采样真峰值为−7.176dBTP，最大目标响度偏差0.16LU。完整逐曲数据见 validation.json；第二次真实全量重建的逐文件哈希见 reproducibility.json。coverage.json 记录17/17叙事NPC和5/5实际支线的交接覆盖。这里的“通过”仅指列出的机器测量，没有人工听感结论。
