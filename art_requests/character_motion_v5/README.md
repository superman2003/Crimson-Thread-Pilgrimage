# 角色動作素材出圖清單（v5，仍需出圖）

2026-10-19 依 main `cae227c1` 重新核對。主角（原 A–D 組與上劈/下劈弧線重畫）已在 #102 及之後的提交接入，不再列出；下面每一項都用目前遊戲實際讀到的幀確認過問題仍在。

## 清單

| 順序 | 組 | 檔名 | 幀數 | 依賴 |
| ---: | --- | --- | ---: | --- |
| 1 | E | `E_phase_broken_string_gardener.png` | 4 |  |
| 2 | E | `E_phase_rust_crown_guardian.png` | 4 |  |
| 3 | E | `E_phase_saltwhite_contract_judge.png` | 4 |  |
| 4 | E | `E_phase_sunken_hammer_smith.png` | 4 |  |
| 5 | G | `G_ash_banner_imp_attack0.png` | 1 |  |
| 6 | G | `G_ash_banner_imp_windup.png` | 4 | 先做 `G_ash_banner_imp_attack0.png` |
| 7 | G | `G_ash_banner_imp_recover.png` | 2 |  |
| 8 | G | `G_echo_contract_scribe_attack3.png` | 1 |  |
| 9 | G | `G_wax_lancer_recover.png` | 2 |  |
| 10 | F | `F_recover_broken_string_gardener_heavy.png` | 2 |  |
| 11 | F | `F_recover_broken_string_gardener_cast.png` | 2 |  |
| 12 | F | `F_recover_broken_string_gardener_phase.png` | 2 | 先做 `E_phase_broken_string_gardener.png` |
| 13 | F | `F_recover_rust_crown_guardian_heavy.png` | 2 |  |
| 14 | F | `F_recover_rust_crown_guardian_cast.png` | 2 |  |
| 15 | F | `F_recover_rust_crown_guardian_phase.png` | 2 | 先做 `E_phase_rust_crown_guardian.png` |
| 16 | F | `F_recover_saltwhite_contract_judge_heavy.png` | 2 |  |
| 17 | F | `F_recover_saltwhite_contract_judge_cast.png` | 2 |  |
| 18 | F | `F_recover_saltwhite_contract_judge_phase.png` | 2 | 先做 `E_phase_saltwhite_contract_judge.png` |
| 19 | F | `F_recover_sunken_hammer_smith_heavy.png` | 2 |  |
| 20 | F | `F_recover_sunken_hammer_smith_cast.png` | 2 |  |
| 21 | F | `F_recover_sunken_hammer_smith_phase.png` | 2 | 先做 `E_phase_sunken_hammer_smith.png` |
| 22 | F | `F_recover_silent_crown_core_heavy.png` | 2 |  |
| 23 | F | `F_recover_silent_crown_core_cast.png` | 2 |  |
| 24 | F | `F_recover_silent_crown_core_phase.png` | 2 |  |
| 25 | F | `F_recover_silent_pilgrim_commander_heavy.png` | 2 |  |
| 26 | F | `F_recover_silent_pilgrim_commander_cast.png` | 2 |  |
| 27 | F | `F_recover_silent_pilgrim_commander_phase.png` | 2 |  |
| 28 | H | `H_broken_string_gardener_death3.png` | 1 |  |
| 29 | H | `H_delayed_shadow_recover0.png` | 1 |  |
| 30 | H | `H_pipe_thrower_hurt2.png` | 1 |  |
| 31 | H | `H_npc_blind_bell_knight_talk3.png` | 1 |  |
| 32 | H | `H_npc_deserter_flagbearer_talk6.png` | 1 |  |

共 **32 張、67 幀**：E 16、G 10、F 36、H 5。順序就是建議的出圖順序（優先 1 的 E、G 在前）。

## 通用要求

- 每張附上下面寫明的參考圖（在 `refs/`），提示詞整段複製，不要刪減。
- 一律面朝右、真透明 PNG、不要地面陰影和文字；畫面上只有角色和武器，**不要任何特效**（刀光、殘影、光波、塵土都由遊戲繪製）。
- 尺寸照提示詞裡的畫布；生成器不支持就用最接近的比例，格子數和順序不能變。
- 角色大小要和參考圖裡同一角色一致，同一張內每格一樣大。導入時我會統一縮放和腳底對齊，但不會修姿勢。
- 只上傳選定的那一張，放進 `incoming/`，檔名照清單；當次實際用的提示詞存成同名 `.txt`。
- 退回標準：格數不對、角色走樣、帶特效或背景、被裁邊、接不上前後幀。

## E. Boss 二階段攻擊專屬出招（4 張 × 4 幀，優先 1）

這 4 個 Boss 的二階段出招 4 幀和普通攻擊的像素完全相同（10-19 逐幀比對 4/4 相同）。參考圖依序是：待機 1、二階段前搖 4、目前被複製的普通攻擊 4。新出招要從第 5 個（前搖最後一幀）接下去，而且**不能**畫得像最後 4 個。

#### 銅根主教（broken_string_gardener） · `E_phase_broken_string_gardener.png`

- 幀數：4
- 附參考圖：`refs/50_boss_phase_broken_string_gardener.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/50_boss_phase_broken_string_gardener.png): a hunched root-bishop: a tall pale wooden mitre-shaped head with two small black eyes, a crown of orange coral-like root hair, a layered dark green leafy feather cloak, long cream lace stoles hanging from the shoulders, gnarled root-claw feet, and a twisted wooden crozier staff whose spiral head carries small hanging orange seed pods. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: idle 1, second-phase wind-up 4, current normal attack 4. Draw a NEW four-cel second-phase signature strike that continues directly from the LAST wind-up figure (the 5th figure). It must be a larger, more violent and clearly different attack from the normal attack (the last four figures); do not reuse those poses.
Layout: exactly 4 cels on a 2-column x 2-row grid (1536x1024 px canvas, one 768x512 px cel each), read left-to-right then top-to-bottom.
Cel 1: steps forward out of the tall wind-up and swings the crozier up overhead with both hands, root-hair crown flaring, leafy cloak lifting.
Cel 2: brings the crozier down in a huge overhead arc in front of the body, lace stoles and leaf cloak whipping forward.
Cel 3: deep forward lunge, the crozier head slammed onto the ground line well in front of the feet, root claws gripping, leafy mantle splayed wide.
Cel 4: holds the impact low and heavy, hunched over the crozier still planted on the ground ahead.
```
#### 苔鐘守母（rust_crown_guardian） · `E_phase_rust_crown_guardian.png`

- 幀數：4
- 附參考圖：`refs/50_boss_phase_rust_crown_guardian.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/50_boss_phase_rust_crown_guardian.png): a tall moss mantis matriarch: a pale bone skull-mask head with long curling antennae that end in two small brass bells, a huge drooping cloak of mossy green fern fronds dotted with tiny white flowers, a dark bronze bell-shaped armoured torso, slender brown wooden limbs and root feet, and two long bone-white scythe forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: idle 1, second-phase wind-up 4, current normal attack 4. Draw a NEW four-cel second-phase signature strike that continues directly from the LAST wind-up figure (the 5th figure). It must be a larger, more violent and clearly different attack from the normal attack (the last four figures); do not reuse those poses.
Layout: exactly 4 cels on a 2-column x 2-row grid (1536x1024 px canvas, one 768x512 px cel each), read left-to-right then top-to-bottom.
Cel 1: launches from the raised wind-up into a long low lunge, both scythes thrust far ahead, fern cloak streaming back, bells swinging.
Cel 2: twists the torso and sweeps both scythes wide outward at full reach, one high and one low.
Cel 3: continues the turn, both scythes swung around overhead in a big crossing arc, cloak flung open.
Cel 4: plants low and wide with both scythes crossed and driven down at the ground line in front.
```
#### 灰冠螳將（saltwhite_contract_judge） · `E_phase_saltwhite_contract_judge.png`

- 幀數：4
- 附參考圖：`refs/50_boss_phase_saltwhite_contract_judge.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/50_boss_phase_saltwhite_contract_judge.png): a spiky mantis general: a charcoal-black insect body on thin long legs, a jagged brown spiked crown head with glowing amber eyes, bone-white serrated blade plates covering the shoulders and back, a long tattered crimson cloak and red ribbons, a small gold clasp at the waist, and two very long bone-white curved scythe blades for forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: idle 1, second-phase wind-up 4, current normal attack 4. Draw a NEW four-cel second-phase signature strike that continues directly from the LAST wind-up figure (the 5th figure). It must be a larger, more violent and clearly different attack from the normal attack (the last four figures); do not reuse those poses.
Layout: exactly 4 cels on a 2-column x 2-row grid (1536x1024 px canvas, one 768x512 px cel each), read left-to-right then top-to-bottom.
Cel 1: rising diagonal sweep with the front scythe blade from low behind to high in front, body uncoiling from the wind-up.
Cel 2: reverse diagonal sweep with the rear blade from high to low, torso twisting the other way, crimson cloak whipping.
Cel 3: deep lunge with both blades thrust straight forward and crossed in an X at full extension.
Cel 4: exhausted low stance, both blades lowered and crossed near the ground, shoulders dropped, cloak settling.
```
#### 緋線執剪者（sunken_hammer_smith） · `E_phase_sunken_hammer_smith.png`

- 幀數：4
- 附參考圖：`refs/50_boss_phase_sunken_hammer_smith.png`
- 緋線執剪者普通攻擊第 4 幀縮小的問題我會用調比例修，不用另外畫。

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/50_boss_phase_sunken_hammer_smith.png): a crimson bird-like shear wielder: a hooked beak, a tall comb crest of bronze quills, long thin red whip antennae sweeping back, a deep crimson ragged feather cloak, a pale cream segmented belly, thin dark clawed legs, and enormous ornate bronze shears with ring handles held in front of the body. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: idle 1, second-phase wind-up 4, current normal attack 4. Draw a NEW four-cel second-phase signature strike that continues directly from the LAST wind-up figure (the 5th figure). It must be a larger, more violent and clearly different attack from the normal attack (the last four figures); do not reuse those poses.
Layout: exactly 4 cels on a 2-column x 2-row grid (1536x1024 px canvas, one 768x512 px cel each), read left-to-right then top-to-bottom.
Cel 1: leaps up and forward out of the wind-up with the enormous shears held wide open overhead, feet off the ground.
Cel 2: airborne, body curled in a tight forward spin, the open shears hugged close, crimson feather cloak wrapping around.
Cel 3: still airborne, uncurls and snaps the shears shut in a horizontal sweep at full arm extension in front of the chest.
Cel 4: lands in a deep low crouch, the closed shears pointing forward along the ground line. Same body size as every other cel; do not shrink.
```
## G. 普通怪銜接和畫面錯誤（5 張共 10 幀，優先 1）

#### ash_banner_imp：出招第 1 幀（旗色錯） · `G_ash_banner_imp_attack0.png`

- 幀數：1
- 附參考圖：`refs/60_ash_banner_imp_full_attack.png`
- 先做這張；前搖第 4 幀要接上它。

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/60_ash_banner_imp_full_attack.png): a small nimble ash grey beetle imp: a pale bone skull face with black eye holes, two curved white horns, a round grey shell on its back, thin dark limbs, red silk ribbons tied around its neck, and a tall spear that carries a ragged black banner edged with red silk. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: idle 1, wind-up 4, strike 4, recovery 2. Redraw ONLY strike figure 1 (the 6th figure): the same low forward lunge with the banner spear thrust forward at hip height. The banner and its red silk must look like they do in strike figures 2-4 (the 7th to 9th figures), so the four strike cels share one consistent banner color.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
#### ash_banner_imp：前搖 4 幀（現在和待機幾乎一樣） · `G_ash_banner_imp_windup.png`

- 幀數：4
- 附參考圖：`refs/60_ash_banner_imp_full_attack.png`＋你選定的 `G_ash_banner_imp_attack0.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/60_ash_banner_imp_full_attack.png): a small nimble ash grey beetle imp: a pale bone skull face with black eye holes, two curved white horns, a round grey shell on its back, thin dark limbs, red silk ribbons tied around its neck, and a tall spear that carries a ragged black banner edged with red silk. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference image 2 is the new strike figure 1. Draw a NEW four-cel wind-up that clearly reads as preparing a lunge: it starts from the upright idle stance (first figure of reference 1) and ends one step before the low lunge of reference image 2.
Cel 1: weight shifts back, the upright banner spear starts to tilt forward.
Cel 2: spear brought down to shoulder height and drawn back, body coiling, banner swinging behind.
Cel 3: deep crouch, spear held level and pulled far back at the hip, horns lowered.
Cel 4: front foot sliding forward, body low and stretched, spear tip aimed forward low, about to lunge into reference image 2.
Layout: exactly 4 cels on a 2-column x 2-row grid (1536x1024 px canvas, one 768x512 px cel each), read left-to-right then top-to-bottom.
```
#### ash_banner_imp：收招過渡 2 幀 · `G_ash_banner_imp_recover.png`

- 幀數：2
- 附參考圖：`refs/60_ash_banner_imp_full_attack.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/60_ash_banner_imp_full_attack.png): a small nimble ash grey beetle imp: a pale bone skull face with black eye holes, two curved white horns, a round grey shell on its back, thin dark limbs, red silk ribbons tied around its neck, and a tall spear that carries a ragged black banner edged with red silk. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Draw exactly two in-between poses that bridge from strike figure 4 (the 9th figure, low forward thrust) to recovery figure 1 (the 10th figure, standing upright holding the banner high).
Cel 1: pulls the spear back and rises halfway, spear angled up at about 45 degrees, banner starting to lift.
Cel 2: almost upright, spear nearly vertical, banner falling into place, one short step from the 10th figure.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### echo_contract_scribe：出招第 4 幀（縮成一團） · `G_echo_contract_scribe_attack3.png`

- 幀數：1
- 附參考圖：`refs/62_echo_contract_scribe_attack3.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/62_echo_contract_scribe_attack3.png): a slender paper scribe insect: a pale bone mask face with black eyes and two curved antennae, a tattered cream parchment cloak, a crimson scarf and a long red sash with small gold seal ornaments, thin black limbs, and a long golden quill-spear. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: strike 1-4, then recovery 1. Strike figure 4 (the 4th figure) is wrong: the body curls up like a hurt pose. Redraw it as the follow-through of the thrust: still in the low wide stance of the 3rd figure, the golden quill-spear tip lowered toward the ground ahead and beginning to draw back, head up and facing right, body not curled. It must flow from the 3rd figure into the 5th figure.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
#### wax_lancer：收招過渡 2 幀 · `G_wax_lancer_recover.png`

- 幀數：2
- 附參考圖：`refs/63_wax_lancer_attack_to_recover.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/63_wax_lancer_attack_to_recover.png): an amber wax wasp knight: glossy golden-orange wax armour plates, a black head with dark eyes and two antennae, translucent amber wings, a deep crimson cape, dark segmented limbs, and a long melting wax lance dripping with amber wax. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: strike 1-4, recovery 1-4. Draw exactly two in-between poses that bridge from strike figure 4 (the 4th figure, low horizontal lance thrust) to recovery figure 1 (the 5th figure, standing with the lance upright).
Cel 1: pulls the lance back toward the chest and rises halfway, lance tilted up at about 45 degrees.
Cel 2: almost upright, lance nearly vertical beside the body, cape settling, one short step from the 5th figure.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
## F. Boss 招式收招過渡（18 張 × 2 幀，優先 2）

6 個 Boss 的重擊（heavy）、施法（cast）、二階段攻擊（phase）結束後都直接跳到同一套通用收招。參考圖 `51_boss_recover_<Boss>_<招式>.png` 依序是：該招最後一幀、通用收招第 1 幀、待機第 1 幀。要畫的是第 1 個和第 2 個之間的 2 幀。

**例外**：銅根主教、苔鐘守母、灰冠螳將、緋線執剪者的 `phase` 要等 E 組定稿後再做，起點改成你選定的 E 圖第 4 格（參考圖 2），終點仍是 `51_…_phase.png` 的第 2 個。

### 銅根主教（broken_string_gardener）

#### 銅根主教 重擊 · `F_recover_broken_string_gardener_heavy.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_broken_string_gardener_heavy.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_broken_string_gardener_heavy.png): a hunched root-bishop: a tall pale wooden mitre-shaped head with two small black eyes, a crown of orange coral-like root hair, a layered dark green leafy feather cloak, long cream lace stoles hanging from the shoulders, gnarled root-claw feet, and a twisted wooden crozier staff whose spiral head carries small hanging orange seed pods. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 銅根主教 施法 · `F_recover_broken_string_gardener_cast.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_broken_string_gardener_cast.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_broken_string_gardener_cast.png): a hunched root-bishop: a tall pale wooden mitre-shaped head with two small black eyes, a crown of orange coral-like root hair, a layered dark green leafy feather cloak, long cream lace stoles hanging from the shoulders, gnarled root-claw feet, and a twisted wooden crozier staff whose spiral head carries small hanging orange seed pods. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 銅根主教 二階段攻擊 · `F_recover_broken_string_gardener_phase.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_broken_string_gardener_phase.png`＋你選定的 `E_phase_broken_string_gardener.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_broken_string_gardener_phase.png): a hunched root-bishop: a tall pale wooden mitre-shaped head with two small black eyes, a crown of orange coral-like root hair, a layered dark green leafy feather cloak, long cream lace stoles hanging from the shoulders, gnarled root-claw feet, and a twisted wooden crozier staff whose spiral head carries small hanging orange seed pods. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference image 2 is the new second-phase strike sheet. Draw exactly two in-between poses that bridge from the LAST cel of reference image 2 (end of the strike) to the SECOND figure of reference image 1 (first pose of the shared recovery); ignore the first figure of reference image 1.
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
### 苔鐘守母（rust_crown_guardian）

#### 苔鐘守母 重擊 · `F_recover_rust_crown_guardian_heavy.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_rust_crown_guardian_heavy.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_rust_crown_guardian_heavy.png): a tall moss mantis matriarch: a pale bone skull-mask head with long curling antennae that end in two small brass bells, a huge drooping cloak of mossy green fern fronds dotted with tiny white flowers, a dark bronze bell-shaped armoured torso, slender brown wooden limbs and root feet, and two long bone-white scythe forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 苔鐘守母 施法 · `F_recover_rust_crown_guardian_cast.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_rust_crown_guardian_cast.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_rust_crown_guardian_cast.png): a tall moss mantis matriarch: a pale bone skull-mask head with long curling antennae that end in two small brass bells, a huge drooping cloak of mossy green fern fronds dotted with tiny white flowers, a dark bronze bell-shaped armoured torso, slender brown wooden limbs and root feet, and two long bone-white scythe forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 苔鐘守母 二階段攻擊 · `F_recover_rust_crown_guardian_phase.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_rust_crown_guardian_phase.png`＋你選定的 `E_phase_rust_crown_guardian.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_rust_crown_guardian_phase.png): a tall moss mantis matriarch: a pale bone skull-mask head with long curling antennae that end in two small brass bells, a huge drooping cloak of mossy green fern fronds dotted with tiny white flowers, a dark bronze bell-shaped armoured torso, slender brown wooden limbs and root feet, and two long bone-white scythe forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference image 2 is the new second-phase strike sheet. Draw exactly two in-between poses that bridge from the LAST cel of reference image 2 (end of the strike) to the SECOND figure of reference image 1 (first pose of the shared recovery); ignore the first figure of reference image 1.
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
### 灰冠螳將（saltwhite_contract_judge）

#### 灰冠螳將 重擊 · `F_recover_saltwhite_contract_judge_heavy.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_saltwhite_contract_judge_heavy.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_saltwhite_contract_judge_heavy.png): a spiky mantis general: a charcoal-black insect body on thin long legs, a jagged brown spiked crown head with glowing amber eyes, bone-white serrated blade plates covering the shoulders and back, a long tattered crimson cloak and red ribbons, a small gold clasp at the waist, and two very long bone-white curved scythe blades for forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 灰冠螳將 施法 · `F_recover_saltwhite_contract_judge_cast.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_saltwhite_contract_judge_cast.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_saltwhite_contract_judge_cast.png): a spiky mantis general: a charcoal-black insect body on thin long legs, a jagged brown spiked crown head with glowing amber eyes, bone-white serrated blade plates covering the shoulders and back, a long tattered crimson cloak and red ribbons, a small gold clasp at the waist, and two very long bone-white curved scythe blades for forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 灰冠螳將 二階段攻擊 · `F_recover_saltwhite_contract_judge_phase.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_saltwhite_contract_judge_phase.png`＋你選定的 `E_phase_saltwhite_contract_judge.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_saltwhite_contract_judge_phase.png): a spiky mantis general: a charcoal-black insect body on thin long legs, a jagged brown spiked crown head with glowing amber eyes, bone-white serrated blade plates covering the shoulders and back, a long tattered crimson cloak and red ribbons, a small gold clasp at the waist, and two very long bone-white curved scythe blades for forearms. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference image 2 is the new second-phase strike sheet. Draw exactly two in-between poses that bridge from the LAST cel of reference image 2 (end of the strike) to the SECOND figure of reference image 1 (first pose of the shared recovery); ignore the first figure of reference image 1.
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
### 緋線執剪者（sunken_hammer_smith）

#### 緋線執剪者 重擊 · `F_recover_sunken_hammer_smith_heavy.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_sunken_hammer_smith_heavy.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_sunken_hammer_smith_heavy.png): a crimson bird-like shear wielder: a hooked beak, a tall comb crest of bronze quills, long thin red whip antennae sweeping back, a deep crimson ragged feather cloak, a pale cream segmented belly, thin dark clawed legs, and enormous ornate bronze shears with ring handles held in front of the body. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 緋線執剪者 施法 · `F_recover_sunken_hammer_smith_cast.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_sunken_hammer_smith_cast.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_sunken_hammer_smith_cast.png): a crimson bird-like shear wielder: a hooked beak, a tall comb crest of bronze quills, long thin red whip antennae sweeping back, a deep crimson ragged feather cloak, a pale cream segmented belly, thin dark clawed legs, and enormous ornate bronze shears with ring handles held in front of the body. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 緋線執剪者 二階段攻擊 · `F_recover_sunken_hammer_smith_phase.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_sunken_hammer_smith_phase.png`＋你選定的 `E_phase_sunken_hammer_smith.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_sunken_hammer_smith_phase.png): a crimson bird-like shear wielder: a hooked beak, a tall comb crest of bronze quills, long thin red whip antennae sweeping back, a deep crimson ragged feather cloak, a pale cream segmented belly, thin dark clawed legs, and enormous ornate bronze shears with ring handles held in front of the body. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference image 2 is the new second-phase strike sheet. Draw exactly two in-between poses that bridge from the LAST cel of reference image 2 (end of the strike) to the SECOND figure of reference image 1 (first pose of the shared recovery); ignore the first figure of reference image 1.
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
### 無聲王冠（silent_crown_core）

#### 無聲王冠 重擊 · `F_recover_silent_crown_core_heavy.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_silent_crown_core_heavy.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_silent_crown_core_heavy.png): an armoured key king: a dark insect body in black plate armour, a pale bone crescent-horned crown head hung with small chains and keys, a tall golden organ-pipe crown of keys rising behind the head, a white ermine fur collar, a long red royal cloak with gold embroidery, and a giant ornate golden key with a wheel-shaped bow carried like a polearm. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 無聲王冠 施法 · `F_recover_silent_crown_core_cast.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_silent_crown_core_cast.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_silent_crown_core_cast.png): an armoured key king: a dark insect body in black plate armour, a pale bone crescent-horned crown head hung with small chains and keys, a tall golden organ-pipe crown of keys rising behind the head, a white ermine fur collar, a long red royal cloak with gold embroidery, and a giant ornate golden key with a wheel-shaped bow carried like a polearm. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 無聲王冠 二階段攻擊 · `F_recover_silent_crown_core_phase.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_silent_crown_core_phase.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_silent_crown_core_phase.png): an armoured key king: a dark insect body in black plate armour, a pale bone crescent-horned crown head hung with small chains and keys, a tall golden organ-pipe crown of keys rising behind the head, a white ermine fur collar, a long red royal cloak with gold embroidery, and a giant ornate golden key with a wheel-shaped bow carried like a polearm. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
### 靜音巡禮統帥（silent_pilgrim_commander）

#### 靜音巡禮統帥 重擊 · `F_recover_silent_pilgrim_commander_heavy.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_silent_pilgrim_commander_heavy.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_silent_pilgrim_commander_heavy.png): a tall slender veiled commander: a white oval mask face, a crown of pale spikes hung with small crystal pendants, a long translucent lavender veil, a layered cream petal gown set with large oval silver mirror panels, thin dark legs on heeled feet, and a long thin silver lance. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 靜音巡禮統帥 施法 · `F_recover_silent_pilgrim_commander_cast.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_silent_pilgrim_commander_cast.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_silent_pilgrim_commander_cast.png): a tall slender veiled commander: a white oval mask face, a crown of pale spikes hung with small crystal pendants, a long translucent lavender veil, a layered cream petal gown set with large oval silver mirror panels, thin dark legs on heeled feet, and a long thin silver lance. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
#### 靜音巡禮統帥 二階段攻擊 · `F_recover_silent_pilgrim_commander_phase.png`

- 幀數：2
- 附參考圖：`refs/51_boss_recover_silent_pilgrim_commander_phase.png`

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/51_boss_recover_silent_pilgrim_commander_phase.png): a tall slender veiled commander: a white oval mask face, a crown of pale spikes hung with small crystal pendants, a long translucent lavender veil, a layered cream petal gown set with large oval silver mirror panels, thin dark legs on heeled feet, and a long thin silver lance. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Reference figure order: last pose of this attack, first pose of the shared recovery, idle. Draw exactly two in-between poses that bridge from the FIRST figure (end of the attack) to the SECOND figure (start of the recovery).
Cel 1 is about one third of the way, cel 2 about two thirds of the way: the body, cloak and weapon move smoothly and consistently, with no new gesture that appears in neither end pose.
Layout: exactly 2 cels on a 2-column x 1-row grid (1536x1024 px canvas, one 768x1024 px cel each), read left-to-right.
```
## H. 被裁到邊的單幀（5 張 × 1 幀，優先 3）

原圖在生成時就被裁到，邊緣是一條直線。畫同一個姿勢，只是完整不被裁。

#### 銅根主教 死亡第 4 幀 · `H_broken_string_gardener_death3.png`

- 幀數：1
- 附參考圖：`refs/70_crop_broken_string_gardener_death3.png`（要重畫的是第 2 個）

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/70_crop_broken_string_gardener_death3.png): a hunched root-bishop: a tall pale wooden mitre-shaped head with two small black eyes, a crown of orange coral-like root hair, a layered dark green leafy feather cloak, long cream lace stoles hanging from the shoulders, gnarled root-claw feet, and a twisted wooden crozier staff whose spiral head carries small hanging orange seed pods. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Redraw ONLY the second figure of the reference, in exactly the same pose, so that it is complete: in the reference its right edge is cut off by a straight line. Show the whole figure, cloak and weapon with clear transparent space on every side.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
#### delayed_shadow 收招第 1 幀 · `H_delayed_shadow_recover0.png`

- 幀數：1
- 附參考圖：`refs/70_crop_delayed_shadow_recover0.png`（要重畫的是第 1 個）

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/70_crop_delayed_shadow_recover0.png): a dark navy feathered shadow insect: a white oval mask face, two long dark plume antennae, a red scarf streaming back, a tattered navy feather cloak with small pale eye spots, thin dark limbs, and a long thin silver needle rapier. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Redraw ONLY the first figure of the reference, in exactly the same pose, so that it is complete: in the reference its top edge is cut off by a straight line. Show the whole figure, cloak and weapon with clear transparent space on every side.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
#### pipe_thrower 受擊第 3 幀 · `H_pipe_thrower_hurt2.png`

- 幀數：1
- 附參考圖：`refs/70_crop_pipe_thrower_hurt2.png`（要重畫的是第 2 個）

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/70_crop_pipe_thrower_hurt2.png): a hunched worker beetle: a rust-orange shell, a white oval mask face with long antennae, a tattered blue work coat, a brown belt with pouches, thin dark limbs, and a short heavy iron pipe. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Redraw ONLY the second figure of the reference, in exactly the same pose, so that it is complete: in the reference its right edge is cut off by a straight line. Show the whole figure, cloak and weapon with clear transparent space on every side.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
#### 盲鐘騎士 交談第 4 幀 · `H_npc_blind_bell_knight_talk3.png`

- 幀數：1
- 附參考圖：`refs/70_crop_npc_blind_bell_knight_talk3.png`（要重畫的是第 2 個）

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/70_crop_npc_blind_bell_knight_talk3.png): a stout armoured beetle knight: two dark curved horns, a white bandage blindfold over the face, dark plate armour, a tattered red cape and white sash, a large round brass shield, small brass bells hanging at the waist, and a tall spear with a bell and red tassel below its blade. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Redraw ONLY the second figure of the reference, in exactly the same pose, so that it is complete: in the reference its top edge (the spear tip) is cut off by a straight line. Show the whole figure, cloak and weapon with clear transparent space on every side.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
#### 逃旗手 交談第 7 幀 · `H_npc_deserter_flagbearer_talk6.png`

- 幀數：1
- 附參考圖：`refs/70_crop_npc_deserter_flagbearer_talk6.png`（要重畫的是第 2 個）

```text
Use case: identity-preserve. Reference image 1 is the existing animation strip of this exact character (refs/70_crop_npc_deserter_flagbearer_talk6.png): a tall thin insect flagbearer: a long pale bone-white head with an amber eye and long thin antennae, a tattered red-and-black cloak, a cream tabard with brass medallions, thin jointed legs, and a tall wooden pole carrying a ragged red pennant. Preserve its design, colors, proportions, crisp dark ink contours and hand-painted dark fantasy insect style exactly. Production animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage. Every cel shows ONLY this one character, full body and full weapon, facing RIGHT, fixed side-view camera, identical character scale in every cel and the same scale as the reference figures, feet on the same baseline unless the action leaves the ground. Each figure stays inside its own cel within 80% of the cel width and 85% of the cel height with generous fully transparent gutters; no part of the body, cloak or weapon touches a neighbouring cel or the canvas edge. Genuine transparent alpha background: no white, no checkerboard, no floor, no shadow, no text, no numbers, no grid lines. Do NOT draw projectiles, waves, beams, ground spikes, dust, smoke, sparks, motion trails, afterimages or glow; the game draws all attack effects itself. Show the action only through the body, limbs, cloak and weapon. Distinct hand-drawn poses, never copies, blends or fades.
Redraw ONLY the second figure of the reference, in exactly the same pose, so that it is complete: in the reference its left edge is cut off by a straight line. Show the whole figure, cloak and weapon with clear transparent space on every side.
Layout: exactly ONE cel, the figure centred on a 1024x1024 px canvas.
```
## 不在清單內

- **主角待機披風過渡（原 A 組）**：10-17 交過一版，A1、A2 稍有改善，A3 沒有改善。用不用要看對比動圖決定，決定之前不重畫。
- **delayed_shadow 前搖與出招順序、銅根主教重擊與二階段前搖、corridor_heavy 前搖**：像是幀順序問題，我先調順序，不行再補出圖。
- **緋線執剪者普通攻擊第 4 幀縮小**：先用比例修正。
- **生成地圖的 36 個佔位 NPC**：只在 `GeneratedMain.tscn` 試玩場景出現，主遊戲不用，不建議做（36 × 16 = 576 幀）。

## 上傳方式

本機直接放進 `art_requests/character_motion_v5/incoming/`，不用自己 commit。在別的電腦就上傳到新分支（例如 `art/character-motion-v5`）的同一資料夾，不要直接傳 main。

## 收到後

逐張檢查（透明、裁切、身份、動作語義、前後銜接）→ 統一比例和腳底 → 寫入 manifest 與生成記錄 → 接入遊戲（Boss 二階段換圖；收招新增「招式專屬過渡 → 通用收招」；普通怪換對應幀）→ 跑 `test:character-motion`、`test:boss-assets` 和相關真實渲染回歸，附前後對比截圖開 PR。

本檔由 `build_list.py` 生成，改內容請改腳本後重跑。
