# corridor_heavy

- 外觀：a broad hunched arthropod in layered mossy stone armor, carrying a heavy cracked bell hammer
- 出現：第 1 區 苔鐘庭，共 2 隻
- 參考圖：`refs/corridor_heavy.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 钟壳滚撞 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 重壳震地 | 地波 | **新畫專屬動作**：重殼震地：整個身體往後仰起，把鐘錘舉過頭，再全身砸向地面 |
| 连环震地（精英專屬） | 地波 | **新畫專屬動作**：連環震地：鐘錘連砸三下，一下比一下重 |

**精英怪**：`E13` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「连环震地」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 重壳震地

- 檔名：`heavy_stamp.png`
- 招式：重壳震地（地波，`heavy_stamp`）
- 遊戲時長：前搖 0.9 秒、出招 0.24 秒、收招 1 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | rears its whole armored body upward, lifting the bell hammer high over its back |
| 5–8 | 出招 | crashes down, driving the bell hammer and its front legs into the ground, stone armor plates jolting |
| 9–12 | 收招 | drags the hammer back and settles into the hunched idle stance |
| 13–14 | 蓄力循環 | holds reared up with the hammer raised, armor plates grinding and shaking |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/corridor_heavy.png): a broad hunched arthropod in layered mossy stone armor, carrying a heavy cracked bell hammer. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): rears its whole armored body upward, lifting the bell hammer high over its back.
Cels 5–8 (strike, 4 cels): crashes down, driving the bell hammer and its front legs into the ground, stone armor plates jolting.
Cels 9–12 (recovery, 4 cels): drags the hammer back and settles into the hunched idle stance.
Cels 13–14 (charge loop, 2 cels): holds reared up with the hammer raised, armor plates grinding and shaking.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 连环震地（精英）

- 檔名：`heavy_elite_quake.png`
- 招式：连环震地（地波，`heavy_elite_quake`）
- 遊戲時長：前搖 1.0 秒、出招 0.24 秒、收招 1.1 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | rears up on its back legs with the bell hammer high, mossy armor plates cracking open |
| 5–8 | 出招 | slams the bell hammer down three times in rhythm, left, right and a final double-handed blow, the body bouncing with each hit |
| 9–12 | 收招 | drags the hammer back, plates settling, and returns to the hunched idle stance |
| 13–14 | 蓄力循環 | reared up with the hammer high, armor plates grinding and stone dust falling |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/corridor_heavy.png): a broad hunched arthropod in layered mossy stone armor, carrying a heavy cracked bell hammer. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): rears up on its back legs with the bell hammer high, mossy armor plates cracking open.
Cels 5–8 (strike, 4 cels): slams the bell hammer down three times in rhythm, left, right and a final double-handed blow, the body bouncing with each hit.
Cels 9–12 (recovery, 4 cels): drags the hammer back, plates settling, and returns to the hunched idle stance.
Cels 13–14 (charge loop, 2 cels): reared up with the hammer high, armor plates grinding and stone dust falling.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 钟壳滚撞的蓄力循環、突進循環（現有動作補循環）

- 檔名：`heavy_roll_loops.png`
- 共 **4 格**，4 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | crouched behind its shell ready to roll, rocking back and forth |
| 3–4 | 突進循環 | the SECOND strike pose in the reference strip (8th sprite) | tucked inside its rolling shell, rotating forward |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/corridor_heavy.png): a broad hunched arthropod in layered mossy stone armor, carrying a heavy cracked bell hammer. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 4 cels in one row (1536 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); crouched behind its shell ready to roll, rocking back and forth; the two cels form a seamless cycle.
Cels 3-4 (travel loop): continue seamlessly from the SECOND strike pose in the reference strip (8th sprite); tucked inside its rolling shell, rotating forward; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
