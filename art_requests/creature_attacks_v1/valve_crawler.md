# valve_crawler

- 外觀：a low crab like mechanical insect with an iron valve wheel shell and six jointed copper legs
- 出現：第 2 區 鑄雨渠，共 1 隻
- 參考圖：`refs/valve_crawler.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 阀轮滚撞 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 排汽横扫 | 直線 | **新畫專屬動作**：排汽橫掃：轉動背上的閥輪，側身把蒸汽橫掃出去 |

## 要生成的圖

### 1. 排汽横扫

- 檔名：`valve_vent.png`
- 招式：排汽横扫（直線，`valve_vent`）
- 遊戲時長：前搖 0.9 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | spins its iron valve wheel shell, legs bracing wide, steam building |
| 5–8 | 出招 | turns sideways and sweeps its body in a horizontal arc, venting steam from the valve |
| 9–12 | 收招 | stops the valve and returns to the low idle stance |
| 13–14 | 蓄力循環 | valve wheel spinning fast, steam hissing from the joints |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/valve_crawler.png): a low crab like mechanical insect with an iron valve wheel shell and six jointed copper legs. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): spins its iron valve wheel shell, legs bracing wide, steam building.
Cels 5–8 (strike, 4 cels): turns sideways and sweeps its body in a horizontal arc, venting steam from the valve.
Cels 9–12 (recovery, 4 cels): stops the valve and returns to the low idle stance.
Cels 13–14 (charge loop, 2 cels): valve wheel spinning fast, steam hissing from the joints.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 阀轮滚撞的蓄力循環（現有動作補循環）

- 檔名：`valve_roll_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | valve shell tilted forward, legs digging in |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/valve_crawler.png): a low crab like mechanical insect with an iron valve wheel shell and six jointed copper legs. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); valve shell tilted forward, legs digging in; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
