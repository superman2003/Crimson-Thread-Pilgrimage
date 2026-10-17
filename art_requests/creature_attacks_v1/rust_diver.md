# rust_diver

- 外觀：a squat beetle diver with a worn bronze diving bell helmet, green algae seams and rope bound iron armor
- 出現：第 2 區 鑄雨渠，共 3 隻
- 參考圖：`refs/rust_diver.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 锈枪跃刺 | 弧躍 | 沿用現有前搖/出招/收招（參考圖那套） |
| 潜盔涌浪 | 地波 | **新畫專屬動作**：潛盔湧浪：把潛水鐘頭盔往地面重重一砸，濺起湧浪 |

## 要生成的圖

### 1. 潜盔涌浪

- 檔名：`diver_splash.png`
- 招式：潜盔涌浪（地波，`diver_splash`）
- 遊戲時長：前搖 0.7 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | bends far forward, lifting its heavy diving bell helmet high |
| 5–8 | 出招 | headbutts the helmet down into the ground, water and algae bursting around it |
| 9–12 | 收招 | straightens up, shaking its helmet, and returns to the idle stance |
| 13–14 | 蓄力循環 | bent over with the helmet raised, bubbles leaking from its seams |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/rust_diver.png): a squat beetle diver with a worn bronze diving bell helmet, green algae seams and rope bound iron armor. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): bends far forward, lifting its heavy diving bell helmet high.
Cels 5–8 (strike, 4 cels): headbutts the helmet down into the ground, water and algae bursting around it.
Cels 9–12 (recovery, 4 cels): straightens up, shaking its helmet, and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): bent over with the helmet raised, bubbles leaking from its seams.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 锈枪跃刺的突進循環（現有動作補循環）

- 檔名：`diver_vault_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 突進循環 | the SECOND strike pose in the reference strip (8th sprite) | leaping forward with the spear thrust out, rope armor trailing |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/rust_diver.png): a squat beetle diver with a worn bronze diving bell helmet, green algae seams and rope bound iron armor. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (travel loop): continue seamlessly from the SECOND strike pose in the reference strip (8th sprite); leaping forward with the spear thrust out, rope armor trailing; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
