# pilgrim_chariot

- 外觀：a low broad crab shaped armored pilgrim with two heavy stone wheel shells and rust red hanging banners
- 出現：第 5 區 黑曜巡禮路，共 2 隻
- 參考圖：`refs/pilgrim_chariot.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 巡礼战车 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 灰钉阵 | 落圈 | **新畫專屬動作**：灰釘陣：側過身，用鉗子把背上的灰釘往前方撒出 |
| 回转战车（精英專屬） | 突進 | **新畫專屬動作**：迴轉戰車：衝過頭後原地甩尾掉頭，再衝回來 |

**精英怪**：`E02` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「回转战车」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 灰钉阵

- 檔名：`chariot_caltrops.png`
- 招式：灰钉阵（落圈，`chariot_caltrops`）
- 遊戲時長：前搖 0.8 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | turns its body sideways and reaches one claw back over its shell to grab a fistful of nails |
| 5–8 | 出招 | flings the claw forward in a wide sweep, scattering ash nails over the ground ahead |
| 9–12 | 收招 | turns back forward and returns to the idle stance |
| 13–14 | 蓄力循環 | claw raised behind the shell, banners swaying |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/pilgrim_chariot.png): a low broad crab shaped armored pilgrim with two heavy stone wheel shells and rust red hanging banners. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): turns its body sideways and reaches one claw back over its shell to grab a fistful of nails.
Cels 5–8 (strike, 4 cels): flings the claw forward in a wide sweep, scattering ash nails over the ground ahead.
Cels 9–12 (recovery, 4 cels): turns back forward and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): claw raised behind the shell, banners swaying.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 回转战车（精英）

- 檔名：`chariot_elite_drift.png`
- 招式：回转战车（突進，`chariot_elite_drift`）
- 遊戲時長：前搖 1.0 秒、出招 0.8 秒、收招 1.0 秒
- 共 **16 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | lowers its body, wheel shells spinning in place, banners whipping |
| 5–8 | 出招 | charges forward, skids into a sideways drift, spins around and faces back the way it came |
| 9–12 | 收招 | wheels slow down, banners settle, returns to the idle stance |
| 13–14 | 蓄力循環 | low to the ground, wheels spinning fast, dust pluming |
| 15–16 | 突進循環 | charging at full speed, wheels blurring, banners streaming back |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/pilgrim_chariot.png): a low broad crab shaped armored pilgrim with two heavy stone wheel shells and rust red hanging banners. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 16 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): lowers its body, wheel shells spinning in place, banners whipping.
Cels 5–8 (strike, 4 cels): charges forward, skids into a sideways drift, spins around and faces back the way it came.
Cels 9–12 (recovery, 4 cels): wheels slow down, banners settle, returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): low to the ground, wheels spinning fast, dust pluming.
Cels 15–16 (travel loop, 2 cels): charging at full speed, wheels blurring, banners streaming back.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 巡礼战车的蓄力循環、突進循環（現有動作補循環）

- 檔名：`chariot_charge_loops.png`
- 共 **4 格**，4 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | wheels spinning in place, body low, ready to charge |
| 3–4 | 突進循環 | the SECOND strike pose in the reference strip (8th sprite) | charging forward, wheel shells spinning, banners streaming back |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/pilgrim_chariot.png): a low broad crab shaped armored pilgrim with two heavy stone wheel shells and rust red hanging banners. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 4 cels in one row (1536 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); wheels spinning in place, body low, ready to charge; the two cels form a seamless cycle.
Cels 3-4 (travel loop): continue seamlessly from the SECOND strike pose in the reference strip (8th sprite); charging forward, wheel shells spinning, banners streaming back; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
