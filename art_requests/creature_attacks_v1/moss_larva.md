# moss_larva

- 外觀：a squat moss covered caterpillar with a dark teal segmented belly, four tiny hooked feet and a weathered bronze bell shell
- 出現：第 1 區 苔鐘庭，共 4 隻
- 參考圖：`refs/moss_larva.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 蜷壳扑身 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 抬头咬击 | 近身 | **新畫專屬動作**：抬頭咬擊：前半身猛地抬起，張口向前咬下 |

## 要生成的圖

### 1. 抬头咬击

- 檔名：`larva_snap.png`
- 招式：抬头咬击（近身，`larva_snap`）
- 遊戲時長：前搖 0.25 秒、出招 0.24 秒、收招 0.55 秒
- 共 **12 格**，4 列 × 3 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | lifts its head and front segments up, mouth opening |
| 5–8 | 出招 | snaps its head forward and down in a quick bite, front feet lifting off the ground |
| 9–12 | 收招 | drops back onto all feet and returns to the squat idle posture |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/moss_larva.png): a squat moss covered caterpillar with a dark teal segmented belly, four tiny hooked feet and a weathered bronze bell shell. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 12 cels on a 4-column x 3-row grid (1536 x 1152 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): lifts its head and front segments up, mouth opening.
Cels 5–8 (strike, 4 cels): snaps its head forward and down in a quick bite, front feet lifting off the ground.
Cels 9–12 (recovery, 4 cels): drops back onto all feet and returns to the squat idle posture.
```

### 2. 蜷壳扑身的蓄力循環（現有動作補循環）

- 檔名：`larva_curl_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | curled tight inside its bell shell, rocking |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/moss_larva.png): a squat moss covered caterpillar with a dark teal segmented belly, four tiny hooked feet and a weathered bronze bell shell. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); curled tight inside its bell shell, rocking; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
