# echo_waterwheel_knight

- 外觀：an ivory porcelain beetle knight with a silver crown helmet, engraved wheel shield and fine crimson silk joints
- 出現：第 6 區 靜冠核心，共 3 隻
- 參考圖：`refs/echo_waterwheel_knight.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 回声盾反 | 格擋反擊 | 沿用現有前搖/出招/收招（參考圖那套） |
| 快慢双轮波 | 地波 | **新畫專屬動作**：快慢雙輪波：把輪盾高舉，滾地般往前砸下，推出兩道輪波 |
| 回响双轮（精英專屬） | 飛彈 | **新畫專屬動作**：迴響雙輪：輪盾一分為二的殘影，同時擲出兩面迴旋輪 |

**精英怪**：`E01` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「回响双轮」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 快慢双轮波

- 檔名：`echo_wheel_wave.png`
- 招式：快慢双轮波（地波，`echo_wheel_wave`）
- 遊戲時長：前搖 0.9 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | lifts the engraved wheel shield high in front of its body with both arms |
| 5–8 | 出招 | slams the shield edge down onto the ground and pushes it forward along the floor, leaning into it |
| 9–12 | 收招 | lifts the shield back to its side and returns to the idle stance |
| 13–14 | 蓄力循環 | holding the shield high, the wheel engraving spinning slowly |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_waterwheel_knight.png): an ivory porcelain beetle knight with a silver crown helmet, engraved wheel shield and fine crimson silk joints. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): lifts the engraved wheel shield high in front of its body with both arms.
Cels 5–8 (strike, 4 cels): slams the shield edge down onto the ground and pushes it forward along the floor, leaning into it.
Cels 9–12 (recovery, 4 cels): lifts the shield back to its side and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): holding the shield high, the wheel engraving spinning slowly.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 回响双轮（精英）

- 檔名：`echo_wheel_elite.png`
- 招式：回响双轮（飛彈，`echo_wheel_elite`）
- 遊戲時長：前搖 0.85 秒、出招 0.24 秒、收招 0.7 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | draws the engraved wheel shield back while a ghostly echo of the shield appears beside it |
| 5–8 | 出招 | hurls both the shield and its echo forward in a spread, ending with empty arms extended |
| 9–12 | 收招 | catches the returning shield, the echo fading, and returns to the idle stance |
| 13–14 | 蓄力循環 | shield drawn back, its ghostly echo pulsing beside it |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_waterwheel_knight.png): an ivory porcelain beetle knight with a silver crown helmet, engraved wheel shield and fine crimson silk joints. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): draws the engraved wheel shield back while a ghostly echo of the shield appears beside it.
Cels 5–8 (strike, 4 cels): hurls both the shield and its echo forward in a spread, ending with empty arms extended.
Cels 9–12 (recovery, 4 cels): catches the returning shield, the echo fading, and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): shield drawn back, its ghostly echo pulsing beside it.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 回声盾反的蓄力循環（現有動作補循環）

- 檔名：`echo_wheel_guard_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | crouched behind the raised shield, spear aimed over its rim |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_waterwheel_knight.png): an ivory porcelain beetle knight with a silver crown helmet, engraved wheel shield and fine crimson silk joints. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); crouched behind the raised shield, spear aimed over its rim; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
