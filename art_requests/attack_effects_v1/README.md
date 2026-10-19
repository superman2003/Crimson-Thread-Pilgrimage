# 攻擊特效出圖清單（v1）

依 main `58a06c18` 審計。敵人的子彈、法術、地面危險和主角的技能、戰具效果，**目前全部由代碼即時畫幾何圖形**（圓、三角、線條），沒有任何圖片素材：

- 敵人：37 種怪物（含 5 個 Boss）共 63 招遠程或範圍攻擊，都由 `godot/scripts/enemy_attack_effect.gd` 繪製。子彈只有 4 種形狀（三角、圓球、四邊形、鑰匙），金屬彈和水輪沒有自己的畫法而退回三角；除 4 招精英招外，所有招式都是同一個土黃色。
- 主角：回聲針、鐘鳴震波、鹽印縛線三個技能和四件戰具，在 `godot/scripts/player_tool_effect.gd` 裡都是一個 16×10 的純色方塊。

本清單按「看起來是同一種東西」分家族出圖，不逐招各畫一套：**32 個敵人特效家族 + 7 個主角效果，共 39 張**。逐招對照表在最後。

## 先說清楚的規則

- **預警留給代碼畫**。落點圈、地刺、光束出手前的閃爍預警圈／預警通道，仍由遊戲按真實判定畫，不出圖。這部分已專門調過可讀性（見 `docs/ENEMY_ATTACK_WARNING_READABILITY.md`、`docs/ENEMY_BEAM_HITBOX_READABILITY.md`），圖片只負責「生效時長什麼樣」。
- **看到的大小要等於打到的大小**。每個家族都寫了遊戲內尺寸；接入時我按判定半徑縮放，讓圖的實心部分剛好覆蓋判定範圍，外圍柔光要淡，不能讓人誤以為範圍更大。
- **遊戲裡很小**。子彈只有二三十像素，所以要求輪廓簡單、核心對比強、實心部分帶細黑邊。細節畫得再多，縮小後也看不到。
- **共用家族會在遊戲裡上色**。備註寫「遊戲按怪物各自上色」的，請畫成偏淡的中性色；其他的直接畫成最終顏色。精英招一律由遊戲疊紅色，不另外出圖。
- 方向：子彈和地波一律朝右畫，遊戲會旋轉或翻轉。

## 通用要求

- 每張附上寫明的參考圖（路徑相對於 `art_requests/`）。參考圖只用來對配色和材質，**不要把怪物畫進去**。
- 真透明 PNG，柔和的半透明光暈邊緣可以；不要黑底、白底、棋盤格、地面、投影、文字、格線。
- 格數、排法照提示詞；生成器不支持該尺寸就用最接近的比例，格子數和順序不能變。
- 只上傳選定的那一張，放進 `art_requests/attack_effects_v1/incoming/`，檔名照清單；當次實際用的提示詞存成同名 `.txt`。
- 退回標準：格數不對、畫了角色或背景、循環接不上、大小比例和其他格不一致、縮到遊戲尺寸後看不清。

## 清單

| 順序 | 檔名 | 名稱 | 類型 | 幀數 | 用到的招數 |
| ---: | --- | --- | --- | ---: | ---: |
| 1 | `FX_P_thorn.png` | 荊針 | 子彈 | 8 | 3 |
| 2 | `FX_P_bolt.png` | 弩矢 | 子彈 | 8 | 2 |
| 3 | `FX_P_stinger.png` | 蠟針 | 子彈 | 8 | 1 |
| 4 | `FX_P_net.png` | 根網 | 子彈 | 8 | 1 |
| 5 | `FX_P_blade.png` | 影刃 | 子彈 | 8 | 4 |
| 6 | `FX_P_spore.png` | 孢子 | 子彈 | 8 | 2 |
| 7 | `FX_P_pollen.png` | 花粉團 | 子彈 | 8 | 2 |
| 8 | `FX_P_seed.png` | 藤種 | 子彈 | 8 | 1 |
| 9 | `FX_P_incense.png` | 香灰滴 | 子彈 | 8 | 1 |
| 10 | `FX_P_light.png` | 光珠 | 子彈 | 8 | 2 |
| 11 | `FX_P_page.png` | 書頁 | 子彈 | 8 | 3 |
| 12 | `FX_P_slug.png` | 管彈 | 子彈 | 8 | 1 |
| 13 | `FX_P_chime.png` | 鐘聲彈 | 子彈 | 8 | 2 |
| 14 | `FX_P_wheel.png` | 水輪刃 | 子彈 | 8 | 2 |
| 15 | `FX_P_key.png` | 鑰刃 | 子彈 | 8 | 1 |
| 16 | `FX_A_seal.png` | 印陣 | 地面危險 | 8 | 2 |
| 17 | `FX_A_fungus.png` | 菌圈 | 地面危險 | 8 | 2 |
| 18 | `FX_A_haze.png` | 煙圈 | 地面危險 | 8 | 2 |
| 19 | `FX_A_snare.png` | 根籠 | 地面危險 | 8 | 3 |
| 20 | `FX_A_caltrops.png` | 灰釘陣 | 地面危險 | 8 | 1 |
| 21 | `FX_A_shadow.png` | 影池 | 地面危險 | 8 | 2 |
| 22 | `FX_A_focus.png` | 聚光 | 地面危險 | 8 | 1 |
| 23 | `FX_A_slag.png` | 鐵渣灘 | 地面危險 | 8 | 1 |
| 24 | `FX_W_quake.png` | 震地裂波 | 地波 | 8 | 3 |
| 25 | `FX_W_chime.png` | 鐘聲地波 | 地波 | 8 | 5 |
| 26 | `FX_W_surge.png` | 渠水湧浪 | 地波 | 8 | 1 |
| 27 | `FX_R_roots.png` | 根刺 | 地刺 | 6 | 6 |
| 28 | `FX_R_spears.png` | 槍陣 | 地刺 | 6 | 2 |
| 29 | `FX_B_steam.png` | 蒸汽 | 光束 | 4 | 2 |
| 30 | `FX_B_erase.png` | 擦除線 | 光束 | 4 | 1 |
| 31 | `FX_B_thread.png` | 緋線 | 光束 | 4 | 1 |
| 32 | `FX_B_gate.png` | 冠門封線 | 光束 | 4 | 1 |
| 33 | `FX_H_needle.png` | 回聲針（技能） | 主角 | 8 | — |
| 34 | `FX_H_shockwave.png` | 鐘鳴震波（技能） | 主角 | 8 | — |
| 35 | `FX_H_snare.png` | 鹽印縛線（技能） | 主角 | 8 | — |
| 36 | `FX_H_shard.png` | 銅鈴投罐（戰具） | 主角 | 8 | — |
| 37 | `FX_H_mine.png` | 絆線釘（戰具） | 主角 | 8 | — |
| 38 | `FX_H_fog.png` | 鹽霧瓶（戰具） | 主角 | 8 | — |
| 39 | `FX_H_lure.png` | 回響誘鈴（戰具） | 主角 | 4 | — |

共 **39 張、288 幀**。優先順序：敵人子彈 → 地面危險、地波、地刺、光束 → 主角效果；同一類內照表格順序。

## 子彈（P）

### 荊針 · `FX_P_thorn.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/thorn_sentinel.png`、`creature_attacks_v1/refs/echo_thorn_sentinel.png`、`creature_attacks_v1/refs/thorn_bloom_mote.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；斷弦溫室、靜冠核心
- 備註：用於 thorn_sentinel「荆针轮射」、echo_thorn_sentinel「双环荆针」、thorn_bloom_mote「花蕊针」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a short sharp curved plant thorn, glossy dark green-brown with a pale bone tip, pointing right.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 弩矢 · `FX_P_bolt.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/kneeling_crossbowman.png`
- 遊戲內：子彈主體直徑約 22–24 px（判定以中心為準，半徑 11–12）；黑曜巡禮路
- 備註：用於 kneeling_crossbowman「锁线三矢」、kneeling_crossbowman「贴地重矢」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22–24 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a short heavy crossbow bolt with a dark iron head, a black shaft and small grey fletching, pointing right.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 蠟針 · `FX_P_stinger.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/wax_bee.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；斷弦溫室
- 備註：用於 wax_bee「双针连射」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a slim amber wax stinger needle with a bead of molten wax at its base, pointing right.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 根網 · `FX_P_net.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/root_cage_hunter.png`
- 遊戲內：子彈主體直徑約 28 px（判定以中心為準，半徑 14）；斷弦溫室
- 備註：用於 root_cage_hunter「根网投掷」。命中會讓主角減速，命中消散幀可畫成網張開罩住。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 28 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small tumbling bundle of brown roots and crimson thread that is unfolding into a net.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 影刃 · `FX_P_blade.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/phase_censor.png`、`creature_attacks_v1/refs/delayed_shadow.png`、`attack_effects_v1/refs/silent_pilgrim_commander.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；黑曜巡禮路、靜冠核心
- 備註：用於 phase_censor「侧移弯刃」、phase_censor「审灯三刃」、delayed_shadow「迟影侧刺」、靜音巡禮統帥「镜像侧刺」。三個怪物共用；畫成淡銀白，遊戲按怪物各自上色。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a thin pale silver crescent blade with a sharp leading edge pointing right and a slightly darker steel spine.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 孢子 · `FX_P_spore.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/spore_bellmaker.png`、`attack_effects_v1/refs/rust_crown_guardian.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；苔鐘庭
- 備註：用於 spore_bellmaker「孢子扇射」、苔鐘守母「守庭孢子」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a round moss-green spore pod with a pale yellow glowing centre and tiny soft hairs.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 花粉團 · `FX_P_pollen.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/bronze_moth.png`、`creature_attacks_v1/refs/pollen_lutist.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；苔鐘庭、斷弦溫室
- 備註：用於 bronze_moth「翼粉弧射」、pollen_lutist「弦音花粉」。pollen_arcs 命中會讓主角減速。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a soft clump of golden pollen with a few loose grains drifting behind it.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 藤種 · `FX_P_seed.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/broken_string_gardener.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；斷弦溫室
- 備註：用於 銅根主教「藤种布道」。命中會讓主角減速。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: an orange seed pod like the ones hanging from the bishop's crozier, with a short curling green vine tail.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 香灰滴 · `FX_P_incense.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/rain_censer_mote.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；鑄雨渠
- 備註：用於 rain_censer_mote「雨香落弹」。受重力下落；命中會讓主角減速。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a falling teardrop of grey-violet incense ash with a faint ember-orange core.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 光珠 · `FX_P_light.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/bell_mote.png`、`creature_attacks_v1/refs/isotope_lumen.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；鑄雨渠、靜冠核心
- 備註：用於 bell_mote「缓追钟珠」、isotope_lumen「光核环弹」。mote_seek 會緩慢追蹤主角。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small glowing pale gold orb with a bright white core and a thin dark rim.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 書頁 · `FX_P_page.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/index_scribe.png`、`creature_attacks_v1/refs/summoned_page.png`、`creature_attacks_v1/refs/echo_contract_scribe.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；鹽白書庫、靜冠核心
- 備註：用於 index_scribe「索引页扇」、summoned_page「环页散刃」、echo_contract_scribe「冠页斜射」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a single torn parchment page, slightly curled, with faint ink lines but no readable letters, spinning edge-on.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 管彈 · `FX_P_slug.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/pipe_thrower.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；鑄雨渠
- 備註：用於 pipe_thrower「管弹曲射」。拋物線曲射；落地後變成「鐵渣灘」，見 A_slag。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a short rusty iron pipe canister tumbling end over end, a little steam leaking from one end.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 鐘聲彈 · `FX_P_chime.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/silent_bugbler.png`、`creature_attacks_v1/refs/falling_clapper.png`
- 遊戲內：子彈主體直徑約 22 px（判定以中心為準，半徑 11）；黑曜巡禮路、靜冠核心
- 備註：用於 silent_bugbler「无声号阵」、falling_clapper「钟浪斜射」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small brass-coloured sound pulse shaped like a thick crescent ring segment, convex side to the right, with two thinner echo arcs behind it.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 水輪刃 · `FX_P_wheel.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/waterwheel_knight.png`、`creature_attacks_v1/refs/echo_waterwheel_knight.png`
- 遊戲內：子彈主體直徑約 34 px（判定以中心為準，半徑 17）；鑄雨渠、靜冠核心
- 備註：用於 waterwheel_knight「返轮刃」、echo_waterwheel_knight「回响双轮」。飛出後會折返回到主人身邊。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 34 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small spinning bronze waterwheel blade with six paddles, green patina and a few water droplets flung off its rim.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 鑰刃 · `FX_P_key.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/silent_crown_core.png`
- 遊戲內：子彈主體直徑約 26 px（判定以中心為準，半徑 13）；靜冠核心
- 備註：用於 無聲王冠「回旋钥阵」。飛出後會折返。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 26 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: an ornate golden key with a wheel-shaped bow, spinning end over end.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

## 落點地面危險（A）

### 印陣 · `FX_A_seal.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/index_scribe.png`、`creature_attacks_v1/refs/echo_contract_scribe.png`
- 遊戲內：地面範圍寬約 60–74 px（判定圓半徑 30–37，中心在地面上方 5 px）；鹽白書庫、靜冠核心
- 備註：用於 index_scribe「落点封印」、echo_contract_scribe「双落印」。index_seal 會讓主角減速。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 60–74 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a flat circular seal of black ink stamped on the ground, ringed with dark red sealing wax, glyph-like marks but no readable letters, faint ink wisps rising.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 菌圈 · `FX_A_fungus.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/spore_bellmaker.png`、`creature_attacks_v1/refs/echo_moss_larva.png`
- 遊戲內：地面範圍寬約 78–90 px（判定圓半徑 39–45，中心在地面上方 5 px）；苔鐘庭、靜冠核心
- 備註：用於 spore_bellmaker「菌圈落点」、echo_moss_larva「迟发苔音」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 78–90 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a ring of moss and small pale bell-shaped mushrooms pushing out of the ground, puffing a faint green spore haze.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 煙圈 · `FX_A_haze.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/rain_censer_mote.png`、`creature_attacks_v1/refs/pollen_lutist.png`
- 遊戲內：地面範圍寬約 72–96 px（判定圓半徑 36–48，中心在地面上方 5 px）；鑄雨渠、斷弦溫室
- 備註：用於 rain_censer_mote「香灰落圈」、pollen_lutist「错位花粉圈」。兩個怪物共用；畫成偏淡的中性色，遊戲按怪物各自上色。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 72–96 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a low hovering cloud of pale warm-grey smoke with drifting golden specks, hugging the ground.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 根籠 · `FX_A_snare.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/root_cage_hunter.png`、`attack_effects_v1/refs/broken_string_gardener.png`、`attack_effects_v1/refs/sunken_hammer_smith.png`
- 遊戲內：地面範圍寬約 62–68 px（判定圓半徑 31–34，中心在地面上方 5 px）；斷弦溫室、鑄雨渠
- 備註：用於 root_cage_hunter「根笼囚网」、銅根主教「交错根笼」、緋線執剪者「断线结阵」。cage_elite_snare 會讓主角減速。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 62–68 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a low cage of brown roots and taut crimson threads snapping up out of the ground and knotting together.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 灰釘陣 · `FX_A_caltrops.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/pilgrim_chariot.png`
- 遊戲內：地面範圍寬約 56 px（判定圓半徑 28，中心在地面上方 5 px）；黑曜巡禮路
- 備註：用於 pilgrim_chariot「灰钉阵」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 56 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a scatter of black iron caltrops lying on the ground, a dull ash-grey glint on their points.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 影池 · `FX_A_shadow.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/delayed_shadow.png`、`attack_effects_v1/refs/silent_pilgrim_commander.png`
- 遊戲內：地面範圍寬約 72 px（判定圓半徑 36，中心在地面上方 5 px）；靜冠核心、黑曜巡禮路
- 備註：用於 delayed_shadow「影落封圈」、靜音巡禮統帥「镜池迟影」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 72 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a dark navy mirror-like puddle on the ground with a pale silver rim, a faint blurred silhouette rising out of it.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 聚光 · `FX_A_focus.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/isotope_lumen.png`
- 遊戲內：地面範圍寬約 96 px（判定圓半徑 48，中心在地面上方 5 px）；靜冠核心
- 備註：用於 isotope_lumen「延迟聚光」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 96 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a short column of pale gold light focused down onto a bright disc on the ground.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 鐵渣灘 · `FX_A_slag.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/pipe_thrower.png`
- 遊戲內：地面範圍寬約 64 px（判定圓半徑 32，中心在地面上方 5 px）；鑄雨渠
- 備註：用於 pipe_thrower「管弹曲射」。管彈落地後的地面危險（半徑固定 32）。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 64 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a splash of glowing orange molten slag and rusty iron scraps on the ground, hissing steam.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

## 地波（W）

### 震地裂波 · `FX_W_quake.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/corridor_heavy.png`、`attack_effects_v1/refs/rust_crown_guardian.png`
- 遊戲內：沿地面移動，主體寬高約 40–46 px（判定圓半徑 20–23，中心在地面上方 18 px）；苔鐘庭
- 備註：用於 corridor_heavy「重壳震地」、corridor_heavy「连环震地」、苔鐘守母「钟冠重压」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 40–46 px wide wave, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a low crescent of cracked earth and rock shards heaving up out of the ground and rolling to the right.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The wave stands on an invisible ground line at 80% of the cel height, centred horizontally, about 60% of the cel width wide, and travels to the RIGHT.
Cel 1: rise: the wave just lifting off the ground.
Cel 2: rise: reaching full height.
Cel 3: travel loop frame 1.
Cel 4: travel loop frame 2.
Cel 5: travel loop frame 3.
Cel 6: travel loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: collapsing back toward the ground.
Cel 8: fade: last faint traces.
```

### 鐘聲地波 · `FX_W_chime.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/bellroot_acolyte.png`、`creature_attacks_v1/refs/silent_bugbler.png`、`creature_attacks_v1/refs/obsidian_bellwheel.png`、`creature_attacks_v1/refs/echo_waterwheel_knight.png`、`attack_effects_v1/refs/silent_crown_core.png`
- 遊戲內：沿地面移動，主體寬高約 22–46 px（判定圓半徑 11–23，中心在地面上方 18 px）；苔鐘庭、黑曜巡禮路、靜冠核心
- 備註：用於 bellroot_acolyte「贴地双钟波」、silent_bugbler「号口震波」、obsidian_bellwheel「双向钟涟」、echo_waterwheel_knight「快慢双轮波」、無聲王冠「钥环震地」。五招共用；畫成偏淡的黃銅色，遊戲按怪物各自上色。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 22–46 px wide wave, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a standing half-ring of brass sound ripples rolling along the ground to the right, two or three nested arcs.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The wave stands on an invisible ground line at 80% of the cel height, centred horizontally, about 60% of the cel width wide, and travels to the RIGHT.
Cel 1: rise: the wave just lifting off the ground.
Cel 2: rise: reaching full height.
Cel 3: travel loop frame 1.
Cel 4: travel loop frame 2.
Cel 5: travel loop frame 3.
Cel 6: travel loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: collapsing back toward the ground.
Cel 8: fade: last faint traces.
```

### 渠水湧浪 · `FX_W_surge.png`

- 幀數：8
- 附參考圖：`creature_attacks_v1/refs/rust_diver.png`
- 遊戲內：沿地面移動，主體寬高約 32 px（判定圓半徑 16，中心在地面上方 18 px）；鑄雨渠
- 備註：用於 rust_diver「潜盔涌浪」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 32 px wide wave, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a low surge of dark green canal water curling forward along the ground to the right, with a foamy crest.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The wave stands on an invisible ground line at 80% of the cel height, centred horizontally, about 60% of the cel width wide, and travels to the RIGHT.
Cel 1: rise: the wave just lifting off the ground.
Cel 2: rise: reaching full height.
Cel 3: travel loop frame 1.
Cel 4: travel loop frame 2.
Cel 5: travel loop frame 3.
Cel 6: travel loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: collapsing back toward the ground.
Cel 8: fade: last faint traces.
```

## 地刺（R）

### 根刺 · `FX_R_roots.png`

- 幀數：6
- 附參考圖：`creature_attacks_v1/refs/vine_crawler.png`、`creature_attacks_v1/refs/thorn_sentinel.png`、`creature_attacks_v1/refs/thorn_bloom_mote.png`、`creature_attacks_v1/refs/echo_thorn_sentinel.png`、`attack_effects_v1/refs/rust_crown_guardian.png`、`attack_effects_v1/refs/broken_string_gardener.png`
- 遊戲內：寬 44–52 px、高 100 px 的地刺（判定矩形從地面往上 92 px）；斷弦溫室、靜冠核心、苔鐘庭
- 備註：用於 vine_crawler「三段根刺」、thorn_sentinel「根墙封路」、thorn_bloom_mote「花种落刺」、echo_thorn_sentinel「间隔根刺」、苔鐘守母「根冠苏醒」、銅根主教「循地根刺」。六招共用。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 44–52 px wide, 100 px tall burst, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a tight cluster of sharp brown roots and green thorns bursting straight up out of the ground.
Layout: exactly 6 cels on a 3-column x 2-row grid (1536x1024 px canvas, one 512x512 px cel each), read left-to-right then top-to-bottom. The burst grows straight up from an invisible ground line at 90% of the cel height, centred horizontally, about 40% of the cel width wide and up to 85% of the cel height tall.
Cel 1: emerge: tips just breaking the ground.
Cel 2: emerge: shooting up to about two thirds height.
Cel 3: full height, hold frame 1.
Cel 4: full height, hold frame 2 (slight sway), loops with cel 3.
Cel 5: retract: cracking and sinking back down.
Cel 6: retract: almost gone, a few fragments at ground level.
```

### 槍陣 · `FX_R_spears.png`

- 幀數：6
- 附參考圖：`creature_attacks_v1/refs/echo_pilgrim_commander_minor.png`
- 遊戲內：寬 44 px、高 100 px 的地刺（判定矩形從地面往上 92 px）；靜冠核心
- 備註：用於 echo_pilgrim_commander_minor「军旗落阵」、echo_pilgrim_commander_minor「号令枪阵」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 44 px wide, 100 px tall burst, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a cluster of ghostly black spears with tattered grey pennants thrusting straight up out of the ground.
Layout: exactly 6 cels on a 3-column x 2-row grid (1536x1024 px canvas, one 512x512 px cel each), read left-to-right then top-to-bottom. The burst grows straight up from an invisible ground line at 90% of the cel height, centred horizontally, about 40% of the cel width wide and up to 85% of the cel height tall.
Cel 1: emerge: tips just breaking the ground.
Cel 2: emerge: shooting up to about two thirds height.
Cel 3: full height, hold frame 1.
Cel 4: full height, hold frame 2 (slight sway), loops with cel 3.
Cel 5: retract: cracking and sinking back down.
Cel 6: retract: almost gone, a few fragments at ground level.
```

## 光束（B）

### 蒸汽 · `FX_B_steam.png`

- 幀數：4
- 附參考圖：`creature_attacks_v1/refs/pipe_thrower.png`、`creature_attacks_v1/refs/valve_crawler.png`
- 遊戲內：光束粗 26–34 px、長 160–300 px（中段重複拼接到所需長度）；鑄雨渠
- 備註：用於 pipe_thrower「近身蒸汽反喷」、valve_crawler「排汽横扫」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 26–34 px thick beam, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters.
The effect: a straight jet of scalding white steam with a hot pale core.
Layout: exactly 4 cels stacked as 4 horizontal strips on a 1536x1024 px canvas (each strip 1536x256 px), top to bottom. The beam runs horizontally through the vertical centre of each strip and is about 25% of the strip height thick.
Cel 1: origin burst: where the beam leaves the attacker, a short flare on the LEFT third of the strip, the beam starting to its right.
Cel 2: middle segment frame A: the beam body running the FULL width of the strip, touching the left and right canvas edges, with no start or end, so it can be repeated side by side.
Cel 3: middle segment frame B: same as frame A with a slightly different shimmer, also touching both side edges.
Cel 4: end cap: the far end of the beam on the RIGHT third of the strip, the beam arriving from the left edge and ending in a small splash.
```

### 擦除線 · `FX_B_erase.png`

- 幀數：4
- 附參考圖：`creature_attacks_v1/refs/erasure_bailiff.png`
- 遊戲內：光束粗 36 px、長 455 px（中段重複拼接到所需長度）；鹽白書庫
- 備註：用於 erasure_bailiff「擦除直线」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 36 px thick beam, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters.
The effect: a straight band of erasing ink: rough black ink edges around a pale paper-white core, like a stroke being wiped out of a page.
Layout: exactly 4 cels stacked as 4 horizontal strips on a 1536x1024 px canvas (each strip 1536x256 px), top to bottom. The beam runs horizontally through the vertical centre of each strip and is about 25% of the strip height thick.
Cel 1: origin burst: where the beam leaves the attacker, a short flare on the LEFT third of the strip, the beam starting to its right.
Cel 2: middle segment frame A: the beam body running the FULL width of the strip, touching the left and right canvas edges, with no start or end, so it can be repeated side by side.
Cel 3: middle segment frame B: same as frame A with a slightly different shimmer, also touching both side edges.
Cel 4: end cap: the far end of the beam on the RIGHT third of the strip, the beam arriving from the left edge and ending in a small splash.
```

### 緋線 · `FX_B_thread.png`

- 幀數：4
- 附參考圖：`attack_effects_v1/refs/sunken_hammer_smith.png`
- 遊戲內：光束粗 30 px、長 650 px（中段重複拼接到所需長度）；鑄雨渠
- 備註：用於 緋線執剪者「绯线封路」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 30 px thick beam, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters.
The effect: a single taut glowing crimson thread with a few loose silk fibres.
Layout: exactly 4 cels stacked as 4 horizontal strips on a 1536x1024 px canvas (each strip 1536x256 px), top to bottom. The beam runs horizontally through the vertical centre of each strip and is about 25% of the strip height thick.
Cel 1: origin burst: where the beam leaves the attacker, a short flare on the LEFT third of the strip, the beam starting to its right.
Cel 2: middle segment frame A: the beam body running the FULL width of the strip, touching the left and right canvas edges, with no start or end, so it can be repeated side by side.
Cel 3: middle segment frame B: same as frame A with a slightly different shimmer, also touching both side edges.
Cel 4: end cap: the far end of the beam on the RIGHT third of the strip, the beam arriving from the left edge and ending in a small splash.
```

### 冠門封線 · `FX_B_gate.png`

- 幀數：4
- 附參考圖：`attack_effects_v1/refs/silent_crown_core.png`
- 遊戲內：光束粗 36 px、長 720 px（中段重複拼接到所需長度）；靜冠核心
- 備註：用於 無聲王冠「冠门封线」。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image(s) show the creature that uses this effect: match its palette and materials, but do NOT draw the creature. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 36 px thick beam, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters.
The effect: a straight bar of gold light with key-tooth notches along both edges.
Layout: exactly 4 cels stacked as 4 horizontal strips on a 1536x1024 px canvas (each strip 1536x256 px), top to bottom. The beam runs horizontally through the vertical centre of each strip and is about 25% of the strip height thick.
Cel 1: origin burst: where the beam leaves the attacker, a short flare on the LEFT third of the strip, the beam starting to its right.
Cel 2: middle segment frame A: the beam body running the FULL width of the strip, touching the left and right canvas edges, with no start or end, so it can be repeated side by side.
Cel 3: middle segment frame B: same as frame A with a slightly different shimmer, also touching both side edges.
Cel 4: end cap: the far end of the beam on the RIGHT third of the strip, the beam arriving from the left edge and ending in a small splash.
```

## 主角技能與戰具（H）

### 回聲針（技能） · `FX_H_needle.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：直線飛行 620 px/秒，射程 420；判定很小（敵人受擊框外擴 8 px），命中一個敵人或碰牆即消失。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 24 px wide sprite, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a thin crimson thread needle with a short trailing loop of red thread, pointing right.
Layout: exactly 8 cels on a 4-column x 2-row grid (1024x512 px canvas, one 256x256 px cel each), read left-to-right then top-to-bottom. The effect is centred in each cel and fills about 55% of the cel width.
Cel 1: flight loop frame 1, travelling to the right.
Cel 2: flight loop frame 2 (small rotation, flicker or flutter change).
Cel 3: flight loop frame 3.
Cel 4: flight loop frame 4, leading back seamlessly into cel 1.
Cel 5: impact: the effect hits something on its right side and starts to break apart.
Cel 6: impact: breaking apart into a few large fragments.
Cel 7: impact: fragments scattering and thinning.
Cel 8: impact: last faint fragments, almost gone.
```

### 鐘鳴震波（技能） · `FX_H_shockwave.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：地面向前 620 px/秒，射程 160，持續 0.8 秒；沿途命中所有敵人並使其踉蹌。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 60 px wide wave, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a forward-rolling ground wave of bronze bell resonance: nested brass arcs with a few kicked-up stone chips.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The wave stands on an invisible ground line at 80% of the cel height, centred horizontally, about 60% of the cel width wide, and travels to the RIGHT.
Cel 1: rise: the wave just lifting off the ground.
Cel 2: rise: reaching full height.
Cel 3: travel loop frame 1.
Cel 4: travel loop frame 2.
Cel 5: travel loop frame 3.
Cel 6: travel loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: collapsing back toward the ground.
Cel 8: fade: last faint traces.
```

### 鹽印縛線（技能） · `FX_H_snare.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：落在主角前方 90 px，判定半徑 36，持續約 1.4 秒；困住敵人。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 72 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a ring of pale salt-white threads snapping taut across the ground in a seal pattern, with a faint crimson core thread.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: appear: the hazard just starting to form on the ground.
Cel 2: appear: half formed.
Cel 3: active loop frame 1, fully formed.
Cel 4: active loop frame 2.
Cel 5: active loop frame 3.
Cel 6: active loop frame 4, leading back seamlessly into cel 3.
Cel 7: fade: breaking up and thinning.
Cel 8: fade: last faint traces.
```

### 銅鈴投罐（戰具） · `FX_H_shard.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：拋物線投出；落地後 0.35 秒亮橙色預警再爆裂，爆裂半徑 75。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 20 px jar and a 150 px wide burst, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small bronze bell-shaped clay jar sealed with red thread.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The jar is small and centred in cels 1-4; the burst in cels 5-8 fills about 80% of the cel.
Cel 1: thrown jar flight frame 1, tumbling.
Cel 2: flight frame 2.
Cel 3: landed: the jar glowing hot orange, warning.
Cel 4: landed: cracks of orange light spreading, about to burst.
Cel 5: burst: a round blast of bronze shards and crimson thread.
Cel 6: burst at full size.
Cel 7: burst breaking up.
Cel 8: last faint fragments.
```

### 絆線釘（戰具） · `FX_H_mine.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：放在地面，判定半徑 36，最多 2 個、持續 6 秒；被觸發時絆倒敵人後消失。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 72 px wide ground patch, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small iron stake driven into the ground with a taut crimson tripwire.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The hazard sits on an invisible ground line at 70% of the cel height, centred horizontally, about 80% of the cel width wide and at most half as tall as it is wide.
Cel 1: placed: being driven into the ground.
Cel 2: armed idle frame 1.
Cel 3: armed idle frame 2 (small glint), loops with cel 2.
Cel 4: triggered: the wire snapping.
Cel 5: triggered: the stake jerking and the wire whipping up.
Cel 6: triggered: spent, the wire slack.
Cel 7: fade: breaking up.
Cel 8: fade: last faint traces.
```

### 鹽霧瓶（戰具） · `FX_H_fog.png`

- 幀數：8
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：在主角前方原地展開，半徑 130，持續 4 秒；干擾敵人索敵，不造成傷害。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 260 px wide cloud, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a cloud of pale salt-white mist with glittering salt crystals.
Layout: exactly 8 cels on a 4-column x 2-row grid (1536x768 px canvas, one 384x384 px cel each), read left-to-right then top-to-bottom. The cloud is centred and up to 85% of the cel width wide.
Cel 1: the bottle shattering, mist bursting out.
Cel 2: mist spreading quickly.
Cel 3: cloud loop frame 1, full size.
Cel 4: cloud loop frame 2.
Cel 5: cloud loop frame 3.
Cel 6: cloud loop frame 4, leading back seamlessly into cel 3.
Cel 7: thinning.
Cel 8: last faint wisps.
```

### 回響誘鈴（戰具） · `FX_H_lure.png`

- 幀數：4
- 附參考圖：`attack_effects_v1/refs/hero_style.png`
- 遊戲內：放下即響，吸引 320 範圍內的小怪來查看；遊戲裡只存在一瞬間，畫成短促的響鈴動畫。

```text
Use case: game VFX sprite sheet. Production effect sprites for the 2D side-scrolling game Crimson Thread Pilgrimage, a hand-painted dark fantasy insect world: muted earthy palette, crisp dark ink contours, textured painted shading; not neon, not pixel art, not a 3D render. The reference image shows the player character: match the crimson thread, bronze and salt-white accents of the character's kit, but do NOT draw the character. Every cel shows ONLY the effect, at the same scale in every cel. The game shrinks it to about a 40 px wide bell, so it needs one bold, simple silhouette, a high-contrast core and a thin dark ink rim around its solid parts so it reads on both dark and pale backgrounds. Genuine transparent alpha background (soft semi-transparent glow edges are fine): no black or white fill, no checkerboard, no scenery, no ground surface, no cast shadow, no text, no numbers, no grid lines, no characters. Generous fully transparent gutters; nothing touches a neighbouring cel or the canvas edge.
The effect: a small brass hand bell lying on the ground, ringing.
Layout: exactly 4 cels on a 4-column x 1-row grid (1536x384 px canvas, one 384x384 px cel each), read left-to-right. The bell sits on an invisible ground line at 80% of the cel height.
Cel 1: the bell set down, still.
Cel 2: the bell swinging, small sound arcs spreading from it.
Cel 3: the bell swinging the other way, sound arcs wider.
Cel 4: settling, last faint arcs.
```

## 逐招對照表

| 怪物 | 地區 | 招式 | 類型 | 半徑 | 家族 |
| --- | --- | --- | --- | ---: | --- |
| bellroot_acolyte | 苔鐘庭 | 贴地双钟波 `root_bell_wave` | wave | 11 | `FX_W_chime` |
| bronze_moth | 苔鐘庭 | 翼粉弧射 `moth_dust` | fan | 11 | `FX_P_pollen` |
| corridor_heavy | 苔鐘庭 | 连环震地（精英） `heavy_elite_quake` | wave | 22 | `FX_W_quake` |
| corridor_heavy | 苔鐘庭 | 重壳震地 `heavy_stamp` | wave | 20 | `FX_W_quake` |
| 苔鐘守母 | 苔鐘庭 | 根冠苏醒 `boss_moss_roots` | rootline | 25 | `FX_R_roots` |
| 苔鐘守母 | 苔鐘庭 | 守庭孢子 `boss_moss_spores` | fan | 11 | `FX_P_spore` |
| 苔鐘守母 | 苔鐘庭 | 钟冠重压 `boss_moss_stamp` | wave | 23 | `FX_W_quake` |
| spore_bellmaker | 苔鐘庭 | 菌圈落点 `bell_fungus` | pool | 45 | `FX_A_fungus` |
| spore_bellmaker | 苔鐘庭 | 孢子扇射 `bell_spores` | fan | 11 | `FX_P_spore` |
| bell_mote | 鑄雨渠 | 缓追钟珠 `mote_seek` | projectile | 11 | `FX_P_light` |
| pipe_thrower | 鑄雨渠 | 近身蒸汽反喷 `pipe_backblast` | beam | 17 | `FX_B_steam` |
| pipe_thrower | 鑄雨渠 | 管弹曲射 `pipe_mortar` | mortar | 11 | `FX_P_slug` + `FX_A_slag` |
| rain_censer_mote | 鑄雨渠 | 香灰落圈 `censer_cloud` | pool | 48 | `FX_A_haze` |
| rain_censer_mote | 鑄雨渠 | 雨香落弹 `censer_rain` | fan | 11 | `FX_P_incense` |
| rust_diver | 鑄雨渠 | 潜盔涌浪 `diver_splash` | wave | 16 | `FX_W_surge` |
| 緋線執剪者 | 鑄雨渠 | 断线结阵 `boss_shears_knots` | pool | 31 | `FX_A_snare` |
| 緋線執剪者 | 鑄雨渠 | 绯线封路 `boss_shears_thread` | beam | 15 | `FX_B_thread` |
| valve_crawler | 鑄雨渠 | 排汽横扫 `valve_vent` | beam | 13 | `FX_B_steam` |
| waterwheel_knight | 鑄雨渠 | 返轮刃 `wheel_return` | projectile | 17 | `FX_P_wheel` |
| erasure_bailiff | 鹽白書庫 | 擦除直线 `bailiff_erase` | beam | 18 | `FX_B_erase` |
| index_scribe | 鹽白書庫 | 索引页扇 `index_pages` | fan | 11 | `FX_P_page` |
| index_scribe | 鹽白書庫 | 落点封印 `index_seal` | pool | 37 | `FX_A_seal` |
| summoned_page | 鹽白書庫 | 环页散刃 `page_orbit` | nova | 11 | `FX_P_page` |
| 銅根主教 | 斷弦溫室 | 交错根笼 `boss_bishop_cage` | pool | 34 | `FX_A_snare` |
| 銅根主教 | 斷弦溫室 | 循地根刺 `boss_bishop_roots` | rootline | 26 | `FX_R_roots` |
| 銅根主教 | 斷弦溫室 | 藤种布道 `boss_bishop_seeds` | fan | 11 | `FX_P_seed` |
| pollen_lutist | 斷弦溫室 | 弦音花粉 `pollen_arcs` | fan | 11 | `FX_P_pollen` |
| pollen_lutist | 斷弦溫室 | 错位花粉圈 `pollen_spots` | pool | 36 | `FX_A_haze` |
| root_cage_hunter | 斷弦溫室 | 根笼囚网（精英） `cage_elite_snare` | pool | 34 | `FX_A_snare` |
| root_cage_hunter | 斷弦溫室 | 根网投掷 `cage_net` | projectile | 14 | `FX_P_net` |
| thorn_bloom_mote | 斷弦溫室 | 花蕊针 `bloom_needle` | projectile | 11 | `FX_P_thorn` |
| thorn_bloom_mote | 斷弦溫室 | 花种落刺 `bloom_seeds` | rootline | 25 | `FX_R_roots` |
| thorn_sentinel | 斷弦溫室 | 荆针轮射 `thorn_ring` | nova | 11 | `FX_P_thorn` |
| thorn_sentinel | 斷弦溫室 | 根墙封路 `thorn_wall` | rootline | 24 | `FX_R_roots` |
| vine_crawler | 斷弦溫室 | 三段根刺 `vine_roots` | rootline | 24 | `FX_R_roots` |
| wax_bee | 斷弦溫室 | 双针连射 `bee_stingers` | fan | 11 | `FX_P_stinger` |
| kneeling_crossbowman | 黑曜巡禮路 | 锁线三矢 `crossbow_burst` | fan | 11 | `FX_P_bolt` |
| kneeling_crossbowman | 黑曜巡禮路 | 贴地重矢 `crossbow_low` | projectile | 12 | `FX_P_bolt` |
| obsidian_bellwheel | 黑曜巡禮路 | 双向钟涟 `bellwheel_waves` | wave | 19 | `FX_W_chime` |
| phase_censor | 黑曜巡禮路 | 侧移弯刃 `censor_blink` | blink | 11 | `FX_P_blade` |
| phase_censor | 黑曜巡禮路 | 审灯三刃 `censor_fan` | fan | 11 | `FX_P_blade` |
| pilgrim_chariot | 黑曜巡禮路 | 灰钉阵 `chariot_caltrops` | pool | 28 | `FX_A_caltrops` |
| silent_bugbler | 黑曜巡禮路 | 号口震波 `bugle_pulse` | wave | 19 | `FX_W_chime` |
| silent_bugbler | 黑曜巡禮路 | 无声号阵 `bugle_volley` | fan | 11 | `FX_P_chime` |
| 靜音巡禮統帥 | 黑曜巡禮路 | 镜像侧刺 `boss_bride_mirror` | blink | 11 | `FX_P_blade` |
| 靜音巡禮統帥 | 黑曜巡禮路 | 镜池迟影 `boss_bride_pools` | pool | 36 | `FX_A_shadow` |
| delayed_shadow | 靜冠核心 | 迟影侧刺 `shadow_blink` | blink | 11 | `FX_P_blade` |
| delayed_shadow | 靜冠核心 | 影落封圈 `shadow_echo` | pool | 36 | `FX_A_shadow` |
| echo_contract_scribe | 靜冠核心 | 冠页斜射 `echo_scribe_pages` | fan | 11 | `FX_P_page` |
| echo_contract_scribe | 靜冠核心 | 双落印 `echo_scribe_seals` | pool | 30 | `FX_A_seal` |
| echo_moss_larva | 靜冠核心 | 迟发苔音 `echo_larva_mark` | pool | 39 | `FX_A_fungus` |
| echo_pilgrim_commander_minor | 靜冠核心 | 军旗落阵 `minor_banner` | rootline | 22 | `FX_R_spears` |
| echo_pilgrim_commander_minor | 靜冠核心 | 号令枪阵（精英） `minor_elite_rally` | rootline | 22 | `FX_R_spears` |
| echo_thorn_sentinel | 靜冠核心 | 双环荆针 `echo_thorn_double` | nova | 11 | `FX_P_thorn` |
| echo_thorn_sentinel | 靜冠核心 | 间隔根刺 `echo_thorn_roots` | rootline | 22 | `FX_R_roots` |
| echo_waterwheel_knight | 靜冠核心 | 回响双轮（精英） `echo_wheel_elite` | projectile | 17 | `FX_P_wheel` |
| echo_waterwheel_knight | 靜冠核心 | 快慢双轮波 `echo_wheel_wave` | wave | 11 | `FX_W_chime` |
| falling_clapper | 靜冠核心 | 钟浪斜射 `clapper_wave` | fan | 11 | `FX_P_chime` |
| isotope_lumen | 靜冠核心 | 延迟聚光 `lumen_focus` | pool | 48 | `FX_A_focus` |
| isotope_lumen | 靜冠核心 | 光核环弹 `lumen_orbits` | nova | 11 | `FX_P_light` |
| 無聲王冠 | 靜冠核心 | 冠门封线 `boss_key_gate` | beam | 18 | `FX_B_gate` |
| 無聲王冠 | 靜冠核心 | 回旋钥阵 `boss_key_return` | fan | 13 | `FX_P_key` |
| 無聲王冠 | 靜冠核心 | 钥环震地 `boss_key_rings` | wave | 23 | `FX_W_chime` |

## 不在清單內

- **預警圈和預警通道**：由代碼按真實判定繪製，理由見上。
- **主角近戰刀光、契印與能力光環**：已由遊戲繪製並按判定調好，這次不動。
- **被彈反的子彈**：遊戲把原子彈改成淡金色並反向飛行，不另外出圖。

## 收到後

逐張檢查 → 切幀、統一錨點（子彈以中心、地面類以地面線、光束以起點）→ 按判定半徑縮放 → `enemy_attack_effect.gd` 和 `player_tool_effect.gd` 改為按家族播放序列幀（保留代碼預警、判定與上色）→ 跑敵人特效生命週期、判定可讀性和相關真實渲染回歸，附前後對比截圖開 PR。

本檔由 `build_list.py` 生成，改內容請改腳本後重跑；腳本會檢查遊戲裡每一招遠程或範圍攻擊都恰好歸入一個家族。
