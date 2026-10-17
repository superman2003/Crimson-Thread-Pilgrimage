# thorn_bloom_mote

- 外觀：a hovering spiny rose seedpod insect with dusty pink petals, dark green thorns and a warm gold pollen core
- 出現：第 4 區 斷弦溫室，共 1 隻
- 參考圖：`refs/thorn_bloom_mote.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 花蕊针 | 飛彈 | 沿用現有前搖/出招/收招（參考圖那套） |
| 花种落刺 | 地刺 | **新畫專屬動作**：花種落刺：花瓣向上張開，把花種往下方抖落 |

## 要生成的圖

### 1. 花种落刺

- 檔名：`bloom_seeds.png`
- 招式：花种落刺（地刺，`bloom_seeds`）
- 遊戲時長：前搖 0.7 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | rises and opens its pink petals upward, gold pollen core exposed |
| 5–8 | 出招 | flips upside down and shakes, seeds falling from the core toward the ground |
| 9–12 | 收招 | rights itself, closes the petals and returns to the idle hover |
| 13–14 | 蓄力循環 | petals wide open, core glowing, thorns twitching |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/thorn_bloom_mote.png): a hovering spiny rose seedpod insect with dusty pink petals, dark green thorns and a warm gold pollen core. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): rises and opens its pink petals upward, gold pollen core exposed.
Cels 5–8 (strike, 4 cels): flips upside down and shakes, seeds falling from the core toward the ground.
Cels 9–12 (recovery, 4 cels): rights itself, closes the petals and returns to the idle hover.
Cels 13–14 (charge loop, 2 cels): petals wide open, core glowing, thorns twitching.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
