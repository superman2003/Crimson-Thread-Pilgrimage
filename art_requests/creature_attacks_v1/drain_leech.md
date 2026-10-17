# drain_leech

- 外觀：a low slithering armored leech with wet charcoal blue segments, rust red jaw plates and tiny brass sensory whiskers
- 出現：第 2 區 鑄雨渠，共 2 隻
- 參考圖：`refs/drain_leech.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 吸血咬 | 近身 | 沿用現有前搖/出招/收招（參考圖那套） |
| 渠虫弧跃 | 弧躍 | **新畫專屬動作**：渠蟲弧躍：身體壓縮成弓形，彈起畫出一道弧線撲下 |

## 要生成的圖

### 1. 渠虫弧跃

- 檔名：`leech_leap.png`
- 招式：渠虫弧跃（弧躍，`leech_leap`）
- 遊戲時長：前搖 0.55 秒、出招 0.65 秒、收招 0.8 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | compresses its body into a tight S coil, head low, jaw plates opening |
| 5–8 | 出招 | launches upward in a long arc, body stretched straight, then curls head first downward with jaws open on cel 4 |
| 9–12 | 收招 | lands in a sprawl and slithers back into the low idle posture |
| 13–14 | 突進循環 | stretched mid-air in the arc, segments rippling, jaws open |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/drain_leech.png): a low slithering armored leech with wet charcoal blue segments, rust red jaw plates and tiny brass sensory whiskers. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): compresses its body into a tight S coil, head low, jaw plates opening.
Cels 5–8 (strike, 4 cels): launches upward in a long arc, body stretched straight, then curls head first downward with jaws open on cel 4.
Cels 9–12 (recovery, 4 cels): lands in a sprawl and slithers back into the low idle posture.
Cels 13–14 (travel loop, 2 cels): stretched mid-air in the arc, segments rippling, jaws open.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
