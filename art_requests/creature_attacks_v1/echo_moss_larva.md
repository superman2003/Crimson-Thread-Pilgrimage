# echo_moss_larva

- 外觀：a squat pale porcelain larva with carved ivory shell segments, dark navy underside and crimson stitched cracks
- 出現：第 6 區 靜冠核心，共 3 隻
- 參考圖：`refs/echo_moss_larva.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 回声潜扑 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 迟发苔音 | 落圈 | **新畫專屬動作**：遲發苔音：抬起前半身鳴叫，裂紋發光，再把頭砸向地面 |

## 要生成的圖

### 1. 迟发苔音

- 檔名：`echo_larva_mark.png`
- 招式：迟发苔音（落圈，`echo_larva_mark`）
- 遊戲時長：前搖 0.6 秒、出招 0.24 秒、收招 0.5 秒
- 共 **12 格**，4 列 × 3 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | rears its front segments upward, crimson cracks along the shell starting to glow |
| 5–8 | 出招 | smashes its head down onto the ground, front segments flattening, cracks flaring |
| 9–12 | 收招 | lifts back up and returns to the squat idle posture |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_moss_larva.png): a squat pale porcelain larva with carved ivory shell segments, dark navy underside and crimson stitched cracks. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 12 cels on a 4-column x 3-row grid (1536 x 1152 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): rears its front segments upward, crimson cracks along the shell starting to glow.
Cels 5–8 (strike, 4 cels): smashes its head down onto the ground, front segments flattening, cracks flaring.
Cels 9–12 (recovery, 4 cels): lifts back up and returns to the squat idle posture.
```

### 2. 回声潜扑的蓄力循環、突進循環（現有動作補循環）

- 檔名：`echo_larva_burrow_loops.png`
- 共 **4 格**，4 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | dug half into the ground, shell trembling before the burrow lunge |
| 3–4 | 突進循環 | the SECOND strike pose in the reference strip (8th sprite) | burrowing forward low along the ground, shell segments rippling |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/echo_moss_larva.png): a squat pale porcelain larva with carved ivory shell segments, dark navy underside and crimson stitched cracks. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 4 cels in one row (1536 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); dug half into the ground, shell trembling before the burrow lunge; the two cels form a seamless cycle.
Cels 3-4 (travel loop): continue seamlessly from the SECOND strike pose in the reference strip (8th sprite); burrowing forward low along the ground, shell segments rippling; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
