# pipe_thrower

- 外觀：a wiry insect canal worker with a patched slate blue apron, rust copper shell and a small iron pipe held for throwing
- 出現：第 2 區 鑄雨渠，共 3 隻
- 參考圖：`refs/pipe_thrower.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 近身蒸汽反喷 | 直線 | 沿用現有前搖/出招/收招（參考圖那套） |
| 管弹曲射 | 曲射 | **新畫專屬動作**：管彈曲射：把鐵管扛上肩，朝天斜上方拋射管彈 |

## 要生成的圖

### 1. 管弹曲射

- 檔名：`pipe_mortar.png`
- 招式：管弹曲射（曲射，`pipe_mortar`）
- 遊戲時長：前搖 0.8 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | hoists the iron pipe onto its shoulder angled steeply upward, crouching |
| 5–8 | 出招 | fires the pipe upward with a recoil that pushes its shoulder down, then lowers it |
| 9–12 | 收招 | takes the pipe off its shoulder and returns to the idle stance |
| 13–14 | 蓄力循環 | pipe on the shoulder aimed high, apron flapping, adjusting the angle |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/pipe_thrower.png): a wiry insect canal worker with a patched slate blue apron, rust copper shell and a small iron pipe held for throwing. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): hoists the iron pipe onto its shoulder angled steeply upward, crouching.
Cels 5–8 (strike, 4 cels): fires the pipe upward with a recoil that pushes its shoulder down, then lowers it.
Cels 9–12 (recovery, 4 cels): takes the pipe off its shoulder and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): pipe on the shoulder aimed high, apron flapping, adjusting the angle.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 近身蒸汽反喷的蓄力循環（現有動作補循環）

- 檔名：`pipe_backblast_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | pipe aimed forward at the hip, steam leaking from its end |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/pipe_thrower.png): a wiry insect canal worker with a patched slate blue apron, rust copper shell and a small iron pipe held for throwing. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); pipe aimed forward at the hip, steam leaking from its end; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
