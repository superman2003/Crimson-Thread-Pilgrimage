# erasure_bailiff

- 外觀：a heavy pale shell beetle enforcer with an ink black face, weathered contract seals and a broad stone cleaver
- 出現：第 3 區 鹽白書庫，共 2 隻
- 參考圖：`refs/erasure_bailiff.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 断页大刀 | 近身 | 沿用現有前搖/出招/收招（參考圖那套） |
| 擦除直线 | 直線 | **新畫專屬動作**：擦除直線：大刀平舉向前，刀面朝前發出一道擦除直線 |
| 断契回斩（精英專屬） | 近身 | **新畫專屬動作**：斷契迴斬：拖著大刀轉一整圈，橫掃身體四周 |

**精英怪**：`E13` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「断契回斩」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 擦除直线

- 檔名：`bailiff_erase.png`
- 招式：擦除直线（直線，`bailiff_erase`）
- 遊戲時長：前搖 1.1 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | turns the broad stone cleaver flat and draws it back to its shoulder, contract seals lifting |
| 5–8 | 出招 | thrusts the cleaver straight forward with the flat face toward the enemy, body braced low |
| 9–12 | 收招 | lowers the cleaver and returns to the idle stance |
| 13–14 | 蓄力循環 | braced with the flat cleaver at its shoulder, seals fluttering wildly |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/erasure_bailiff.png): a heavy pale shell beetle enforcer with an ink black face, weathered contract seals and a broad stone cleaver. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): turns the broad stone cleaver flat and draws it back to its shoulder, contract seals lifting.
Cels 5–8 (strike, 4 cels): thrusts the cleaver straight forward with the flat face toward the enemy, body braced low.
Cels 9–12 (recovery, 4 cels): lowers the cleaver and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): braced with the flat cleaver at its shoulder, seals fluttering wildly.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 断契回斩（精英）

- 檔名：`bailiff_elite_sweep.png`
- 招式：断契回斩（近身，`bailiff_elite_sweep`）
- 遊戲時長：前搖 1.0 秒、出招 0.3 秒、收招 1.1 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | drags the stone cleaver low behind it and twists its whole shell body away from the enemy |
| 5–8 | 出招 | spins a full circle with the cleaver held out at arm's length, sweeping all around it, contract seals flying |
| 9–12 | 收招 | lets the cleaver's weight carry it to a stop, plants it and returns to the idle stance |
| 13–14 | 蓄力循環 | twisted away with the cleaver dragging, seals fluttering, legs braced |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/erasure_bailiff.png): a heavy pale shell beetle enforcer with an ink black face, weathered contract seals and a broad stone cleaver. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): drags the stone cleaver low behind it and twists its whole shell body away from the enemy.
Cels 5–8 (strike, 4 cels): spins a full circle with the cleaver held out at arm's length, sweeping all around it, contract seals flying.
Cels 9–12 (recovery, 4 cels): lets the cleaver's weight carry it to a stop, plants it and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): twisted away with the cleaver dragging, seals fluttering, legs braced.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 断页大刀的蓄力循環（現有動作補循環）

- 檔名：`bailiff_cleave_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | cleaver raised high overhead, shaking with the weight |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/erasure_bailiff.png): a heavy pale shell beetle enforcer with an ink black face, weathered contract seals and a broad stone cleaver. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); cleaver raised high overhead, shaking with the weight; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
