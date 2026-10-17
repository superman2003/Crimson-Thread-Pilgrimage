# thorn_sentinel

- 外觀：a sturdy beetle guard in bark and thorn plate armor with a leaf shield and a serrated thorn blade
- 出現：第 4 區 斷弦溫室，共 2 隻
- 參考圖：`refs/thorn_sentinel.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 根墙封路 | 地刺 | 沿用現有前搖/出招/收招（參考圖那套） |
| 荆针轮射 | 環射 | **新畫專屬動作**：荊針輪射：把葉盾高舉過頭轉一圈，甲上荊針全部射出 |

## 要生成的圖

### 1. 荆针轮射

- 檔名：`thorn_ring.png`
- 招式：荆针轮射（環射，`thorn_ring`）
- 遊戲時長：前搖 0.85 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | raises the leaf shield over its head and starts to spin it, crouching |
| 5–8 | 出招 | spins in place with the shield overhead, all thorn plates flaring outward |
| 9–12 | 收招 | stops, lowers the shield and returns to the guarded idle stance |
| 13–14 | 蓄力循環 | shield raised overhead, rotating slowly |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/thorn_sentinel.png): a sturdy beetle guard in bark and thorn plate armor with a leaf shield and a serrated thorn blade. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): raises the leaf shield over its head and starts to spin it, crouching.
Cels 5–8 (strike, 4 cels): spins in place with the shield overhead, all thorn plates flaring outward.
Cels 9–12 (recovery, 4 cels): stops, lowers the shield and returns to the guarded idle stance.
Cels 13–14 (charge loop, 2 cels): shield raised overhead, rotating slowly.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
