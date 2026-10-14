# S02：动作、交互与地图 NPC 声音候选包

51 个原创程序合成单次音效，WAV 总计 2,042,244 字节（约 1.95 MiB），48 kHz / 单声道 / PCM16，时长 0.15–0.90 秒。全部为待审素材，不改动运行时代码、数据、旧资源包或 CI。**人工听感审核 pending；没有实机接入、混音验收或听感通过声明。**

## 事件覆盖

| 类别 | 数量 | 覆盖与共用规则 |
| --- | ---: | --- |
| 三契印疗伤 | 9 | crimson 缝名、bell 司铸、salt 校录，每种 started/completed/interrupted 独立 |
| 六线术 | 12 | cleave/needle/snare/ward/shockwave/crosscut，各施放+命中；ward 命中指挡击接触 |
| 四战具 | 8 | shard/mine/fog/lure，各使用+实际生效 |
| 移动、死亡与恢复 | 10 | 跳跃、冲刺、轻/重落地、反弹、攀壁附着、钩索挂接/收卷、死亡、恢复 |
| 世界交互反馈 | 6 | 购买、拒绝、任务/证词、钟龛安坐/恢复、拾取 |
| 六区地图 NPC | 6 | 绑定 cartography_sellers.json 的真实 npc_id；非语义器物提示 |

逐项事件、触发时序及现有/提议映射见 [coverage.md](coverage.md)；播放建议保存在 manifest 每项。旧 assets/proposals/reverse_audio 六区 warning/attack_body/attack_detail/hurt 共 24 份干声继续复用；本包不重复生成。普通攻击、受伤、地表脚步变体、持续攀壁滑动已有音源，保留现有实现，不为数量新增。UI 菜单导航、展开、关闭交由 S03。

## 真实事件与接入边界

- 疗伤 `heal_state_changed("started"|"completed"|"interrupted")` 已存在；开始时 `_crest()` 决定材质。三契印 catalog 的疗伤时长均为 0.8 秒，本包开始音 0.76 秒。完成音必须等实际 completed 信号；打断时停止开始音，立即播打断音。不能把三段拼成“必定成功”的长音。
- 六线术的 `skill_cast(skill_id)` 已存在，但目前施放公用 `skill` 音；本包候选需要未来有选择地替换它，不能直接叠播。命中是代码分支而非已存在独立音频事件。needle/shockwave/snare 的 `_apply_special_skill()` 生成 effect payload 没有保留来源技能 ID；未来应携带来源 ID 后再选择命中音，禁止凭当前已切换技能猜测。ward 的候选用于实际可防御接触，不表示伤害，也不把进入架势当成功。
- 战具使用只在 `cast_tool` 成功、次数交易提交后播；当前 `perform_build_action` 失败会恢复次数，因此失败不得播使用音。铜罐落地后 0.35 秒才爆发；绊线要等实际目标触发；雾只播首个干扰；诱铃按实例而非受影响敌人数播一次。
- 购买/拒绝目前只有返回结果、toast 等流程，没有独立专用音频 ID。manifest 标记 proposed_hook，覆盖表明确调用点。拒绝可共用主动交易失败和动作拒绝，但不得自动刷新/悬停连响。
- `ui_testimony_complete` 是真实证词集齐事件；一般支线任务完成可复用此音，但需要首次完成 hook，不宣称现有任务皆已接线。
- `shrine_rest_ch01..ch06` 表示六个实际键的共享候选。地区钟龛个性由 S01 环境/音乐层承接；本包安坐、恢复不按六区复制。
- 六个地图 NPC 都来自 `cartography_sellers.json`。`play_npc_voice(npc_id,line,profile)` 是真实函数，目前基于 profile 程序产生短音，本包是未来按 NPC 替换的候选。全为器物音色和节拍，非录音、非语音、无伪中文；文字字幕承载语义。关闭对话应停止，下一问候替换前一问候。

## 声部与混音建议

manifest priority 沿用 AudioDirector 0 最高、1 动作、2 背景的语义；本包死亡/恢复 0，NPC 2（与现有问候一致），其余 1。所有项最长 900 ms，符合当前名义声部账期。max_voices 为 1 或 2，min_interval_seconds 多数 0.08，NPC 0.45；仍服从运行时全局24声部。开始/打断/成功必须同组互斥；同次技能多目标只留一个确认音。参数是建议而非已接入配置。

合成峰值 -6 dBFS；动作/反馈推荐初始播放 -10 dB，NPC -15 dB，为后续实机试听留空间，不等同于响度匹配。推荐禁用随机音高直到听感审核；普通移动全区共享。已有敌人主体和细节音与新增命中确认层叠加须再次审核遮蔽、峰值和可辨识度。

## 重建与技术证据

仓库根目录执行：

```sh
python tools/proposals/audio_category_sfx/generate.py
python tools/proposals/audio_category_sfx/validate.py
```

生成器仅使用 Python 标准库；验证需要 ffmpeg。种子来自 ID 的 SHA-256 前 8 字节，波形不依赖系统随机状态；输入构筑/地图 NPC 表只读。`validation.json` 记录每份 PCM 的实际帧数、峰值、RMS、1 ms 头尾 RMS、零端点、非零占比与 SHA-256，并用 ffmpeg 真正解码、逐字节比对 PCM。另在临时目录完整重新生成 manifest 和 51 WAV、对比全部52哈希。确定性结果适用于记录的 Python/平台环境；跨平台 math 实现的最后位差异未保证。

5 ms 二次淡入、25 ms 线性淡出；无完全静音或削波文件；所有音频内容哈希唯一。技术验证不能替代耳机/扬声器试听，也不证明素材已装入游戏。
