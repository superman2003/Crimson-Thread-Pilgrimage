# echo_pilgrim_commander_minor

- 外觀：a mid sized porcelain insect officer with a crimson crest, silver spear and layered crown plate armor
- 出現：第 6 區 靜冠核心，共 1 隻
- 參考圖：`refs/echo_pilgrim_commander_minor.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 巡礼三枪 | 連擊 | 沿用現有前搖/出招/收招（參考圖那套） |
| 军旗落阵 | 地刺 | **新畫專屬動作**：軍旗落陣：把長槍當旗杆高舉，用力插進地面 |
| 号令枪阵（精英專屬） | 地刺 | **新畫專屬動作**：號令槍陣：高舉長槍發號，前方地面一排槍尖竄出 |

**精英怪**：`E08` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「号令枪阵」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 军旗落阵

- 檔名：`minor_banner.png`
- 招式：军旗落阵（地刺，`minor_banner`）
- 遊戲時長：前搖 0.85 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | lifts the silver spear vertically overhead like a standard, crimson crest flaring |
| 5–8 | 出招 | drives the spear point straight down into the ground in front of it with both hands, kneeling on one knee |
| 9–12 | 收招 | pulls the spear free and returns to the idle stance |
| 13–14 | 蓄力循環 | holds the spear raised overhead, crest and cloth snapping in the wind |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_pilgrim_commander_minor.png): a mid sized porcelain insect officer with a crimson crest, silver spear and layered crown plate armor. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): lifts the silver spear vertically overhead like a standard, crimson crest flaring.
Cels 5–8 (strike, 4 cels): drives the spear point straight down into the ground in front of it with both hands, kneeling on one knee.
Cels 9–12 (recovery, 4 cels): pulls the spear free and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): holds the spear raised overhead, crest and cloth snapping in the wind.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 号令枪阵（精英）

- 檔名：`minor_elite_rally.png`
- 招式：号令枪阵（地刺，`minor_elite_rally`）
- 遊戲時長：前搖 0.95 秒、出招 0.24 秒、收招 0.8 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | raises the silver spear high and throws its head back as if shouting an order, crimson crest flaring |
| 5–8 | 出招 | sweeps the spear down and forward along the ground in a long commanding arc, kneeling into it |
| 9–12 | 收招 | rises, lifts the spear upright and returns to the idle stance |
| 13–14 | 蓄力循環 | spear raised high, head thrown back, crest and armor plates trembling |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_pilgrim_commander_minor.png): a mid sized porcelain insect officer with a crimson crest, silver spear and layered crown plate armor. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): raises the silver spear high and throws its head back as if shouting an order, crimson crest flaring.
Cels 5–8 (strike, 4 cels): sweeps the spear down and forward along the ground in a long commanding arc, kneeling into it.
Cels 9–12 (recovery, 4 cels): rises, lifts the spear upright and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): spear raised high, head thrown back, crest and armor plates trembling.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 巡礼三枪的蓄力循環（現有動作補循環）

- 檔名：`minor_lances_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | spear drawn back at the hip, weight on the back foot, tip trembling |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_pilgrim_commander_minor.png): a mid sized porcelain insect officer with a crimson crest, silver spear and layered crown plate armor. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); spear drawn back at the hip, weight on the back foot, tip trembling; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
