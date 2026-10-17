# obsidian_spearman

- 外觀：a tall insect warrior in cracked volcanic black armor, a faded wine red cloak and a long obsidian spear
- 出現：第 5 區 黑曜巡禮路，共 3 隻
- 參考圖：`refs/obsidian_spearman.png`（依序：待機 1 格、現有前搖 4 格、現有出招 4 格、現有收招第 1 格）

## 招式安排

| 招式 | 類型 | 動畫 |
| --- | --- | --- |
| 黑曜直刺 | 突進 | 沿用現有前搖/出招/收招（參考圖那套） |
| 抬枪截空 | 近身 | **新畫專屬動作**：抬槍截空：長槍由下往上挑起，攔截空中的目標 |
| 跃空贯地（精英專屬） | 弧躍 | **新畫專屬動作**：躍空貫地：高高躍起，在空中翻身把長槍垂直往下刺 |

**精英怪**：`E12` 這一隻是精英，血量 ×1.75（無條件進位）、所有招式傷害 +1、體型 ×1.12，並多一招「跃空贯地」。精英與普通個體共用同一套美術，只有專屬招式需要新圖。

## 要生成的圖

### 1. 抬枪截空

- 檔名：`obsidian_raise.png`
- 招式：抬枪截空（近身，`obsidian_raise`）
- 遊戲時長：前搖 0.6 秒、出招 0.24 秒、收招 0.5 秒
- 共 **12 格**，4 列 × 3 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | lowers the long obsidian spear so the point almost touches the ground in front, crouching |
| 5–8 | 出招 | sweeps the spear upward in a rising arc until it points straight up, rising onto its toes |
| 9–12 | 收招 | brings the spear back level and returns to the idle stance |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/obsidian_spearman.png): a tall insect warrior in cracked volcanic black armor, a faded wine red cloak and a long obsidian spear. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 12 cels on a 4-column x 3-row grid (1536 x 1152 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): lowers the long obsidian spear so the point almost touches the ground in front, crouching.
Cels 5–8 (strike, 4 cels): sweeps the spear upward in a rising arc until it points straight up, rising onto its toes.
Cels 9–12 (recovery, 4 cels): brings the spear back level and returns to the idle stance.
```

### 2. 跃空贯地（精英）

- 檔名：`obsidian_elite_impale.png`
- 招式：跃空贯地（弧躍，`obsidian_elite_impale`）
- 遊戲時長：前搖 0.7 秒、出招 0.75 秒、收招 1.0 秒
- 共 **16 格**，4 列 × 4 行，從左到右、從上到下依序排列

| 格 | 段落 | 內容 |
| ---: | --- | --- |
| 1–4 | 前搖 | crouches deep with the obsidian spear held vertically, cloak spreading |
| 5–8 | 出招 | leaps high, flips the spear point down at the top of the jump and plunges straight down, spear first |
| 9–12 | 收招 | wrenches the spear out of the ground and returns to the idle stance |
| 13–14 | 蓄力循環 | crouched deep, spear vertical, cloak snapping |
| 15–16 | 突進循環 | high in the air, spear pointing straight down, cloak streaming upward |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/obsidian_spearman.png): a tall insect warrior in cracked volcanic black armor, a faded wine red cloak and a long obsidian spear. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 16 cels on a 4-column x 4-row grid (1536 x 1536 px canvas, one 384 px square per cel), read left-to-right then top-to-bottom; leave any cel after the last one empty and transparent.
Cels 1–4 (wind-up, 4 cels): crouches deep with the obsidian spear held vertically, cloak spreading.
Cels 5–8 (strike, 4 cels): leaps high, flips the spear point down at the top of the jump and plunges straight down, spear first.
Cels 9–12 (recovery, 4 cels): wrenches the spear out of the ground and returns to the idle stance.
Cels 13–14 (charge loop, 2 cels): crouched deep, spear vertical, cloak snapping.
Cels 15–16 (travel loop, 2 cels): high in the air, spear pointing straight down, cloak streaming upward.
Loop cels are a seamless two-cel cycle: the second loop cel must flow back into the first, and both continue directly from the cel before them.
```

### 3. 黑曜直刺的蓄力循環（現有動作補循環）

- 檔名：`obsidian_thrust_loops.png`
- 共 **2 格**，2 列 × 1 行

| 格 | 段落 | 接在哪一格後面 | 內容 |
| ---: | --- | --- | --- |
| 1–2 | 蓄力循環 | the LAST wind-up pose in the reference strip (6th sprite) | spear drawn back at the hip, cloak billowing behind |

提示詞：

```text
Use case: identity-preserve. Reference image is the existing animation strip of this exact creature (refs/obsidian_spearman.png): a tall insect warrior in cracked volcanic black armor, a faded wine red cloak and a long obsidian spear. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly, at the SAME character scale as the reference. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one creature, full body, facing RIGHT, fixed side-view camera, identical scale in every cel, feet (or hover height) on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 75% of the cel width and 80% of the cel height with generous fully transparent gutters; nothing touches a neighbouring cel. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, orbs, waves, beams, ground spikes, dust, smoke, sparks, motion trails or glow effects; the game draws all attack effects itself. Show the action only through the body, limbs, wings and weapon. Distinct hand-drawn poses, never copies or fades.
Layout: exactly 2 cels in one row (768 x 384 px canvas, one 384 px square per cel).
Cels 1-2 (charge loop): continue seamlessly from the LAST wind-up pose in the reference strip (6th sprite); spear drawn back at the hip, cloak billowing behind; the two cels form a seamless cycle.
```

## 交付

- 生成好的 PNG 放進 `art_requests/creature_attacks_v1/incoming/`，檔名照上面；同名 `.txt` 存當次實際用的提示詞。
- 只上傳選定的那一張；格數不對、角色走樣、帶了特效的圖我會退回並指出是哪一格。
