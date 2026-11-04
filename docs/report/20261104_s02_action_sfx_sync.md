# S02：玩家动作声音落在动作真正发生的那一帧

2026-11-04。台账 S02 的下一验收交付是“动作同步、个性与叠音限流”。逐个查玩家动作音的触发时刻，并用 ffmpeg 解出每个音效文件的起音与峰值时刻，比对动作的实际判定帧，发现：

| 动作 | 原来 | 问题 |
|---|---|---|
| 钟纹重击（attack_2） | 按键当帧播放打击音 `heavy_hit`（峰值在第 7ms） | 判定与刀光要 0.10 秒后才出现，声音早了约 0.1 秒 |
| 二段跳 | 复用地面跳跃音，只升调 1.16 | 生成包里早有专用“双线绷紧”声 `player_double_jump_wings`，一直没接 |
| 钟壳格挡挡下攻击 | 只有画面，没有声音 | `player_guard_block`／`player_guard_perfect` 已生成但未接 |
| 疗伤完成（生命回来那一帧） | 没有声音；开始时的引导声 0.95 秒，比 0.85 秒的引导还长 | `player_bind_tighten` 未接 |
| 疗伤被打断 | 没有声音，开始时的引导声继续响完 | `player_bind_interrupt` 未接 |

清单 `audio_visual_manifest.json` 里这几项的备注仍写着“二段跳／钟壳格挡尚未实现”，其实这些机制早已上线，只是声音一直没接上。

## 改动

- 钟纹重击的打击音移到判定帧（与刀光同一帧）；普攻挥空音保持按键时播放，它的峰值在 87–134ms，正好落在 0.06–0.24 秒的判定窗内。
- 二段跳改用 `player_double_jump_wings`，地面跳跃音不变。
- 格挡在挡下攻击的那一帧出声：完美格挡（前 0.14 秒）用 `guard_perfect`，其余用 `guard_block`。被挡下的攻击不放受伤音。
- 疗伤完成在生命回升的同一帧放 `bind_tighten`；被打断时当帧切掉引导声，并放 `bind_interrupt`。
- 新增 `_play_sfx_voice` 返回正在播放的节点，供引导声被提前切断时使用。`_play_sfx` 的签名不变，现有测试子类的覆盖不受影响。
- 清单中这 5 项从 `asset_ready` 改为 `wired`，补上 `implemented_in`。

## 验证

新套件 `player_action_sfx_sync`：真实地面、正式 Player 场景、经 InputMap 的按键，共 17 项检查，记录每次播放时的动作状态。

- 重击打击音在判定帧之后才出现（按键后 0.117 秒，起手 0.10 秒）；普攻只放一次挥空音。
- 二段跳在空中放展翼声，地面跳跃音只出现一次。
- 完美格挡和普通格挡各出一次对应的声音，受伤音一次都不出现。
- 疗伤完成时，“收紧”声与生命回升在同一帧。
- 疗伤被打断时：放“断线”声，不放“收紧”声，引导声当帧停止。

在改动前的代码上，同一套件失败 8 项。以下相关套件全部通过：

- `player_melee_feedback`、`player_action_buffer`、`player_basic_attack_vfx`
- `player_motion_continuity`、`seal_identity`、`combat_input_events`
- `player_contact_art`、`ability_movement`、`melee_recovery`、`audio_retirement`

清单校验也通过；软件 GL 下新套件约 5 秒。

## 边界

- 测的是触发帧与状态的对应，不是听感；新声音的音量和个性仍需实际试听。
- 线术技能的“准备／生效／命中”三段声音原本就按阶段触发，这次没有改动。
- 叠音限流沿用 AudioDirector 的声部契约，未改。
