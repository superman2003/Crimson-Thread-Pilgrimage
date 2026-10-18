# gear_sentinel

- 外觀：a compact clockwork beetle guard with tarnished bronze plate armor, a toothed gear shield and a short spear
- 出現：第 1 區 苔鐘庭，共 2 隻
- 參考圖：`refs/gear_sentinel.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 齿矛长刺 | 近身 | 沿用現有前搖/出招/收招（參考圖那套） |
| 架盾反突 | 格擋反擊 | **新畫專屬動作**：架盾反突：齒輪盾舉到身前站穩，然後用盾猛撞反擊 |
| 齿轮旋矛（精英專屬） | 連擊 | **新畫專屬動作**：齒輪旋矛：盾與矛一起旋轉，邊轉邊向前推進連擊 |

**精英怪**：`E14` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「齿轮旋矛」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 架盾反突

- 檔名：`gear_guard.png`
- 招式：架盾反突（格擋反擊，`gear_guard`）
- 遊戲時長：前搖 0.7 秒、出招 0.25 秒、收招 0.7 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | plants its feet and raises the toothed gear shield squarely in front of its body |
| 5–8 | 出招 | bashes forward with the shield, spear tucked behind it, shield teeth leading |
| 9–12 | 收招 | lowers the shield and returns to the idle stance |
| 13–14 | 蓄力循環 | braced behind the raised shield, the gear teeth slowly turning |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/gear_sentinel.png): a compact clockwork beetle guard with tarnished bronze plate armor, a toothed gear shield and a short spear. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): plants its feet and raises the toothed gear shield squarely in front of its body.
Cels 5–8 (strike, 4 cels): bashes forward with the shield, spear tucked behind it, shield teeth leading.
Cels 9–12 (recovery, 4 cels): lowers the shield and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): braced behind the raised shield, the gear teeth slowly turning.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 齿轮旋矛（精英）

- 檔名：`gear_elite_spin.png`
- 招式：齿轮旋矛（連擊，`gear_elite_spin`）
- 遊戲時長：前搖 0.75 秒、出招 0.7 秒、收招 0.8 秒
- 共 **16 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | plants its feet, swings the gear shield out to the side and draws the spear back, body twisting like a wound spring |
| 5–10 | 出招 | spins forward in two full turns, shield and spear whirling around it like gear teeth, hitting on every half turn |
| 11–14 | 收招 | staggers out of the spin, plants the spear and returns to the guarded idle stance |
| 15–16 | 蓄力循環 | twisted and coiled, shield gear teeth spinning, feet grinding the floor |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/gear_sentinel.png): a compact clockwork beetle guard with tarnished bronze plate armor, a toothed gear shield and a short spear. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 16 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): plants its feet, swings the gear shield out to the side and draws the spear back, body twisting like a wound spring.
Cels 5–10 (strike, 6 cels): spins forward in two full turns, shield and spear whirling around it like gear teeth, hitting on every half turn.
Cels 11–14 (recovery, 4 cels): staggers out of the spin, plants the spear and returns to the guarded idle stance.
Cels 15–16 (charge loop, 2 cels): twisted and coiled, shield gear teeth spinning, feet grinding the floor.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
