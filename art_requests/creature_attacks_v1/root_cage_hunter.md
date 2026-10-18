# root_cage_hunter

- 外觀：a stalking wooden mantid with a cage of bent roots around its torso, green leaf armor and hooked forearms
- 出現：第 4 區 斷弦溫室，共 3 隻
- 參考圖：`refs/root_cage_hunter.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 根网投掷 | 飛彈 | 沿用現有前搖/出招/收招（參考圖那套） |
| 根笼扑刺 | 弧躍 | **新畫專屬動作**：根籠撲刺：伏低身子，彈跳撲向前方，雙鉤臂向下刺 |
| 根笼囚网（精英專屬） | 落圈 | **新畫專屬動作**：根籠囚網：把胸前根籠扯開，往前方地面甩出兩團根網 |

**精英怪**：`E12` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「根笼囚网」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 根笼扑刺

- 檔名：`cage_pounce.png`
- 招式：根笼扑刺（弧躍，`cage_pounce`）
- 遊戲時長：前搖 0.55 秒、出招 0.6 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | crouches very low, hooked forearms folded, root cage tightening |
| 5–8 | 出招 | leaps forward in an arc, then comes down with both hooked forearms stabbing down on cel 4 |
| 9–12 | 收招 | lands crouched and rises back to the stalking idle stance |
| 13–14 | 突進循環 | mid-air, forearms raised high, leaf armor fluttering |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/root_cage_hunter.png): a stalking wooden mantid with a cage of bent roots around its torso, green leaf armor and hooked forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): crouches very low, hooked forearms folded, root cage tightening.
Cels 5–8 (strike, 4 cels): leaps forward in an arc, then comes down with both hooked forearms stabbing down on cel 4.
Cels 9–12 (recovery, 4 cels): lands crouched and rises back to the stalking idle stance.
Cels 13–14 (travel loop, 2 cels): mid-air, forearms raised high, leaf armor fluttering.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 根笼囚网（精英）

- 檔名：`cage_elite_snare.png`
- 招式：根笼囚网（落圈，`cage_elite_snare`）
- 遊戲時長：前搖 0.8 秒、出招 0.24 秒、收招 0.7 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | grips the bent roots of its own torso cage with both hooked forearms and pulls them open |
| 5–8 | 出招 | flings both arms forward, hurling two tangles of roots toward the ground ahead |
| 9–12 | 收招 | folds its arms back, the torso cage closing, and returns to the stalking idle stance |
| 13–14 | 蓄力循環 | cage pried open, roots writhing between its forearms |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/root_cage_hunter.png): a stalking wooden mantid with a cage of bent roots around its torso, green leaf armor and hooked forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): grips the bent roots of its own torso cage with both hooked forearms and pulls them open.
Cels 5–8 (strike, 4 cels): flings both arms forward, hurling two tangles of roots toward the ground ahead.
Cels 9–12 (recovery, 4 cels): folds its arms back, the torso cage closing, and returns to the stalking idle stance.
Cels 13–14 (charge loop, 2 cels): cage pried open, roots writhing between its forearms.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 根网投掷的蓄力循環（現有動作補循環）

- 檔名：`cage_net_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | root net wound up behind its head, swaying |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/root_cage_hunter.png): a stalking wooden mantid with a cage of bent roots around its torso, green leaf armor and hooked forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); root net wound up behind its head, swaying; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
