# waterwheel_knight

- 外觀：a broad beetle knight in riveted gunmetal armor carrying a circular waterwheel shield and blunt poleaxe
- 出現：第 2 區 鑄雨渠，共 3 隻
- 參考圖：`refs/waterwheel_knight.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 轮盾推进 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 返轮刃 | 飛彈 | **新畫專屬動作**：返輪刃：把水車盾當迴旋刃擲出，空手擺出接盾姿勢 |
| 轮盾滚袭（精英專屬） | 突進 | **新畫專屬動作**：輪盾滾襲：把水車盾立在地上當輪子，衝刺滾撞 |

**精英怪**：`E14` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「轮盾滚袭」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 返轮刃

- 檔名：`wheel_return.png`
- 招式：返轮刃（飛彈，`wheel_return`）
- 遊戲時長：前搖 0.75 秒、出招 0.24 秒、收招 0.5 秒
- 共 **14 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | draws the circular waterwheel shield back across its body with both arms |
| 5–8 | 出招 | hurls the shield forward spinning, then stands with empty arms extended |
| 9–12 | 收招 | catches the returning shield and returns to the idle stance |
| 13–14 | 蓄力循環 | shield drawn back, body twisted, ready to throw |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/waterwheel_knight.png): a broad beetle knight in riveted gunmetal armor carrying a circular waterwheel shield and blunt poleaxe. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 14 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): draws the circular waterwheel shield back across its body with both arms.
Cels 5–8 (strike, 4 cels): hurls the shield forward spinning, then stands with empty arms extended.
Cels 9–12 (recovery, 4 cels): catches the returning shield and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): shield drawn back, body twisted, ready to throw.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 2. 轮盾滚袭（精英）

- 檔名：`wheel_elite_ride.png`
- 招式：轮盾滚袭（突進，`wheel_elite_ride`）
- 遊戲時長：前搖 0.8 秒、出招 0.65 秒、收招 0.9 秒
- 共 **16 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | drops the waterwheel shield onto its edge in front of it and crouches behind it, gripping the top |
| 5–8 | 出招 | charges forward pushing the spinning shield like a wheel, then shoves it hard forward on cel 4 |
| 9–12 | 收招 | hauls the shield back up onto its arm and returns to the idle stance |
| 13–14 | 蓄力循環 | crouched behind the upright shield, the wheel paddles turning faster |
| 15–16 | 突進循環 | running behind the rolling shield, body low, gunmetal armor rattling |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/waterwheel_knight.png): a broad beetle knight in riveted gunmetal armor carrying a circular waterwheel shield and blunt poleaxe. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 16 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): drops the waterwheel shield onto its edge in front of it and crouches behind it, gripping the top.
Cels 5–8 (strike, 4 cels): charges forward pushing the spinning shield like a wheel, then shoves it hard forward on cel 4.
Cels 9–12 (recovery, 4 cels): hauls the shield back up onto its arm and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): crouched behind the upright shield, the wheel paddles turning faster.
Cels 15–16 (travel loop, 2 cels): running behind the rolling shield, body low, gunmetal armor rattling.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 轮盾推进的蓄力循環（現有動作補循環）

- 檔名：`wheel_charge_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | shield raised forward, poleaxe held behind it |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/waterwheel_knight.png): a broad beetle knight in riveted gunmetal armor carrying a circular waterwheel shield and blunt poleaxe. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); shield raised forward, poleaxe held behind it; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
