# ash_banner_imp

- 外觀：a small nimble ash grey beetle imp carrying a ragged black banner edged with red silk
- 出現：第 5 區 黑曜巡禮路，共 1 隻
- 參考圖：`refs/ash_banner_imp.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 旗枪三连 | 連擊 | 沿用現有前搖/出招/收招（參考圖那套） |
| 回旗退刺 | 退刺 | **新畫專屬動作**：回旗退刺：抽旗收身、向後跳開，同時把旗槍往前反刺 |

## 要生成的圖

### 1. 回旗退刺

- 檔名：`imp_retreat.png`
- 招式：回旗退刺（退刺，`imp_retreat`）
- 遊戲時長：前搖 0.45 秒、出招 0.3 秒、收招 0.5 秒
- 共 **12 格**，4 列 × 3 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | plants its back foot and pulls the banner spear back against its chest, crouching for a backward hop |
| 5–8 | 出招 | springs backward off the ground while thrusting the banner spear forward one-handed, the black banner whipping toward the enemy, landing on the back foot on cel 4 |
| 9–12 | 收招 | lands balanced, swings the banner upright and returns to the idle stance |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/ash_banner_imp.png): a small nimble ash grey beetle imp carrying a ragged black banner edged with red silk. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 12 cels on a 4-column x 3-row grid (1536 x 1152 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): plants its back foot and pulls the banner spear back against its chest, crouching for a backward hop.
Cels 5–8 (strike, 4 cels): springs backward off the ground while thrusting the banner spear forward one-handed, the black banner whipping toward the enemy, landing on the back foot on cel 4.
Cels 9–12 (recovery, 4 cels): lands balanced, swings the banner upright and returns to the idle stance.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
