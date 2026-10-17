# page_duelist

- 外觀：a graceful mantid sword fighter with folded ivory paper coat tails, crimson wax seals and a sharp needle rapier
- 出現：第 3 區 鹽白書庫，共 3 隻
- 參考圖：`refs/page_duelist.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 双段追刺 | 連擊 | 沿用現有前搖/出招/收招（參考圖那套） |
| 虚晃退刺 | 虛晃 | **新畫專屬動作**：虛晃退刺：假裝前刺，身體晃一下又退半步，再補一記快刺 |
| 千页连刺（精英專屬） | 連擊 | **新畫專屬動作**：千頁連刺：細劍連續快刺，紙衣下擺像書頁翻飛 |

**精英怪**：`E14` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「千页连刺」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 虚晃退刺

- 檔名：`page_feint.png`
- 招式：虚晃退刺（虛晃，`page_feint`）
- 遊戲時長：前搖 0.48 秒、出招 0.26 秒、收招 0.38 秒
- 共 **12 格**，4 列 × 3 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | raises the needle rapier in a fencing guard, coat tails lifting |
| 5–8 | 出招 | half-thrusts, pulls back with a small backward step, then snaps a quick real thrust forward on cel 4 |
| 9–12 | 收招 | returns the rapier to the fencing guard and settles into the idle stance |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/page_duelist.png): a graceful mantid sword fighter with folded ivory paper coat tails, crimson wax seals and a sharp needle rapier. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 12 cels on a 4-column x 3-row grid (1536 x 1152 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): raises the needle rapier in a fencing guard, coat tails lifting.
Cels 5–8 (strike, 4 cels): half-thrusts, pulls back with a small backward step, then snaps a quick real thrust forward on cel 4.
Cels 9–12 (recovery, 4 cels): returns the rapier to the fencing guard and settles into the idle stance.
```

### 2. 千页连刺（精英）

- 檔名：`page_elite_flurry.png`
- 招式：千页连刺（連擊，`page_elite_flurry`）
- 遊戲時長：前搖 0.7 秒、出招 0.8 秒、收招 0.8 秒
- 共 **16 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | draws the needle rapier back to its shoulder, coat tails flaring like pages, crimson seals glowing |
| 5–10 | 出招 | six rapid thrusts while stepping forward, alternating high and low, ending in a long lunge on cel 6 |
| 11–14 | 收招 | flicks the rapier, folds the coat tails back and returns to the fencing idle stance |
| 15–16 | 蓄力循環 | rapier drawn back, coat tails fluttering like a riffled book |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/page_duelist.png): a graceful mantid sword fighter with folded ivory paper coat tails, crimson wax seals and a sharp needle rapier. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 16 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): draws the needle rapier back to its shoulder, coat tails flaring like pages, crimson seals glowing.
Cels 5–10 (strike, 6 cels): six rapid thrusts while stepping forward, alternating high and low, ending in a long lunge on cel 6.
Cels 11–14 (recovery, 4 cels): flicks the rapier, folds the coat tails back and returns to the fencing idle stance.
Cels 15–16 (charge loop, 2 cels): rapier drawn back, coat tails fluttering like a riffled book.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 双段追刺的蓄力循環（現有動作補循環）

- 檔名：`page_combo_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | rapier aimed forward, weight coiled on the back foot |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/page_duelist.png): a graceful mantid sword fighter with folded ivory paper coat tails, crimson wax seals and a sharp needle rapier. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); rapier aimed forward, weight coiled on the back foot; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
