# C01：小怪受击框贴合画面上的身体

2026-11-03。台账 C01 的下一验收交付是“判定对齐”。逐种测量 40 种小怪待机帧的不透明轮廓与受击框（玩家攻击、战具判定命中的范围）：受击框高度按美术高度缩放，宽度却写死为 48px，而画面上的身体宽 70–190px：

- `drain_leech` 身体约 180px 宽，只有 25% 能被打到；`waterwheel_knight`、`pilgrim_chariot`、`rust_diver` 不到 30%——砍在画面上的身体两侧会打空；
- 蜡蜂 `wax_bee`、旗手小鬼 `ash_banner_imp` 的受击框中心偏离身体，46%／81% 的受击框落在身体外的空气里。

## 改动

`enemy_actor._fit_hurtbox_to_art()`：建好精灵后，取待机动画所有帧不透明部分的平均尺寸，受击框宽 = 平均宽度的 62%（40–160px，且不小于原来的 48px，只会放宽），高 = 平均高度的 84%，垂直中心对齐身体中心。不改：

- Boss（受击框原本 168–184px，已覆盖身体九成以上）和数据里显式写了受击框的敌人；
- 接触伤害用的身体碰撞框（另一个 `body_size`）；
- 攻击突进时与地形扫掠的盒子：新增 `get_motion_rect()` 保留原尺寸，`enemy_motion_sweep` 改用它，贴墙突进的行为与之前完全一致。

## 结果

| 指标（40 种小怪，画面当前帧） | 修改前 | 修改后 |
|---|---|---|
| 身体被受击框覆盖的比例，最低 | 25% | 41% |
| 同上，平均 | 41% | 51% |
| 受击框落在身体上的比例，最低 | 46% | 93% |

新套件 `enemy_hurtbox_fit`：每种小怪的受击框 ≥90% 落在身体上、身体 ≥38% 可被打到、宽度不小于 48px、突进扫掠盒仍为原 48px。修改前 17 项失败，修改后通过。`combat`、`enemy_attack_motion`、`enemy_wave_sweep`、`enemy_ai_behavior`、`enemy_tactical_roles`、`enemy_encounter_roles`、`enemy_lifecycle_regression`、`player_attack_window`、`melee_recovery`、`player_projectile_contact`、`damage_receipt`、`world_enemy_residency`、`combat_resource_cycle`、`spike_pogo`、`optional_challenges`、`challenge_claim`、`boss_trial`、`player_melee_feedback` 通过；`seal_combat` 软件 GL 通过。

## 边界

62% 是让武器、尾巴、伸出的触手不计入的经验值；手感上是否仍觉得“砍到边缘没中”需要人工试打（T04）。只用待机帧，攻击帧伸出的部分不扩大受击框。
