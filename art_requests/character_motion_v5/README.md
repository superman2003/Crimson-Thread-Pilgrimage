# 全項目角色動作素材出圖清單（v5）

依據 2026-10-17 對 main `c0918c0` 的全項目審計。審計沒有直接採用 PR #101 報告的結論，而是從遊戲代碼實際請求的動作出發，逐個角色核對運行時讀到的幀。

## 審計範圍與結論

| 範圍 | 數量 | 結論 |
| --- | ---: | --- |
| 主角 | 1 | **缺得最多**：待機披風跳幀、沒有跑攻、3 個技能/道具動作借用別的動作的圖、空中循環只有 1 幀 |
| 普通怪 | 40 | 每種都有 idle4 / walk8 / windup4 / attack4 / recover4 / hurt / death，沒有缺動作。**3 種有銜接或畫面錯誤要補圖，另有 2 種可能只是幀順序問題** |
| Boss | 6 | 動作齊全。**4 個 Boss 的二階段攻擊直接複製普通攻擊的圖**；6 個 Boss 的重擊、施法、二階段攻擊結束後都接通用收招，跳變明顯 |
| 正式 NPC | 25 | 全部有獨立的 idle4 / talk8 / greet2 / rest2，沒有缺動作。2 張圖被裁到邊 |
| 生成地圖的佔位 NPC | 36 | 只出現在 `GeneratedMain.tscn`（生成地圖試玩場景），不在主遊戲 World 裡。共用 6 個章節 NPC 的圖。**不建議做**，見最後一節 |

自動檢查覆蓋 71 個正式角色的 2028 個幀引用：空幀、裁邊、重複像素、跨動作複製、相鄰幀尺寸跳變、狀態銜接處的輪廓跳變。然後逐一人工看過 71 個角色的全部幀，以及 64 條「待機→前搖→出招→收招→待機」的銜接序列。

普通怪在遊戲數據裡沒有中文名，以下用代碼 ID 稱呼。

## 通用要求（每一張都適用）

- **人物一致**：主角以 `refs/00_style_run_v4_8frames.png` 為畫風參考；怪物、Boss、NPC 以清單裡列出的該角色現有幀為參考，要求「同一角色、同一畫風」（identity-preserve）。
- **朝向**：一律面朝右。
- **背景**：真透明 PNG。不要白底、灰底或棋盤格，也不要陰影、地面、文字和邊框。
- **排版**：一張 sheet 放一個動作的全部幀，從左到右、從上到下依序排列。每幀之間留寬一點的空白，角色和武器都不能被裁到或互相重疊。
- **鏡頭**：同一張 sheet 內鏡頭和比例固定，與參考圖的角色大小一致，腳底在同一條水平線上（飛行和空中動作除外）。
- **解析度**：每格至少 400×400。
- **檔名**：用清單裡的「檔名」欄。只上傳最後選定的那一張。
- **提示詞**：當次用的提示詞存成同名 `.txt` 一起放上來，我會寫進生成記錄。

## 清單總覽

| 優先 | 組 | 內容 | 幀數 |
| --- | --- | --- | ---: |
| 1 | A | 主角待機披風過渡幀 | 3 |
| 1 | B | 主角跑攻（新動作） | 6 |
| 1 | E | Boss 二階段攻擊專屬出招幀（4 個 Boss） | 16 |
| 1 | G | 普通怪銜接和畫面錯誤（3 種） | 10 |
| 2 | C | 主角獨立技能/道具動作 | 12 |
| 2 | D | 主角空中循環 | 4 |
| 2 | F | Boss 招式收招過渡幀（6 個 Boss × 3 招） | 36 |
| 3 | H | 被裁到邊的單幀重畫 | 5 |

**必做（優先 1）35 幀；全部 92 幀。** 另外有 2 項可能不用出圖，我會先試著調整幀順序，見 G 組最後。

---

## 主角

### A. 待機披風過渡幀（3 幀）· `A_idle_cloth_bridges.png`

待機是一張固定身體，加上 7 張循環播放的披風圖。7 張披風的輪廓分成兩組，在 cel2→cel4、cel6→cel7、cel7→cel1 三處跳得明顯。要畫的是 3 張「中間形狀」：

- A1：介於 cel2 和 cel4 之間
- A2：介於 cel6 和 cel7 之間
- A3：介於 cel7 和 cel1 之間

參考圖：`11_bridge_A1/A2/A3_*.png`（每張左右兩個是要銜接的兩端）、`10_idle_cloth_cel*.png`。

**只畫披風加圍巾**，透明背景，右上角是領口掛點，布料往左下飄。領口位置、大小、線條粗細、上色方式和現有披風圖完全一致，只改下擺和圍巾尾端的形狀。3 張橫排。

> Cloth-only sprite cels for a 2D game: a red scarf and a teal tattered cape, attached at the top-right collar point, flowing to the lower left in a gentle idle breeze. Exactly 3 cels in one row, generous transparent gutters. Cel 1 is the in-between shape of reference A1 left and right, cel 2 of A2, cel 3 of A3. Keep the collar position, scale, line weight and painted shading identical to the references; only the hem and scarf tail shapes change. No body, no character, no background, no text, genuine transparency.

### B. 跑攻（6 幀）· `B_run_attack.png`

現在地面攻擊不管有沒有在跑，播的都是站姿攻擊圖，跑步中出刀時腳步會突然停住。新動作讓雙腿維持跑步步幅、上半身揮劍：1–2 前搖、3–4 水平斬、5–6 收回跑步持劍。3 列 × 2 行。參考：`00_style_run_v4_8frames.png`、`20_v3_attack_1.png`。

> Same black-haired swordsman with red scarf, teal cape, dark costume and boots as the reference. Six sequential right-facing poses of a running horizontal sword slash in 3 columns x 2 rows: 1-2 wind-up raising the sword while running, 3-4 forward horizontal slash with full arm extension, 5-6 recovery back to running sword hold. Legs keep a real running stride throughout. Fixed camera and scale, full body and sword visible, generous gutters, genuine transparency, no text or background. Preserve the reference drawing style exactly.

### C. 獨立技能/道具動作（3 × 4 幀）

現在這三個動作直接借用別的動作的圖。每個 4 幀橫排：起手 → 發動 → 持續 → 收招。

| 檔名 | 內容 | 目前借用 | 參考 |
| --- | --- | --- | --- |
| `C_skill_melee.png` | 蓄力重斬，幅度比普攻大，可帶少量紅色線光 | attack_2 | `20_v3_attack_2.png` |
| `C_skill_wave.png` | 向前揮出劍氣，劍身前方一道紅色弧形光波，不蓋住身體 | skill_control | `30_v3_skill_control_used_by_skill_wave.png` |
| `C_item_use.png` | 左手從腰間取出小型戰具往前拋出或啟動，右手持劍放低 | skill_projectile | `30_v3_skill_projectile_used_by_item_use.png` |

> Same swordsman as the reference. Four sequential right-facing poses in one row: [動作描述]. Start, activation, sustain, recovery. Fixed camera and scale, feet on the same baseline, full body and sword visible, generous gutters, genuine transparency, no text or background. Preserve the reference drawing style exactly.

### D. 空中循環（2 × 2 幀）

| 檔名 | 內容 | 參考 |
| --- | --- | --- |
| `D_jump_loop.png` | 上升途中，膝蓋收起，披風和圍巾往下飄；2 幀只差布料擺動 | `40_v3_jump.png` |
| `D_fall_loop.png` | 下落途中，雙腿往下伸準備落地，披風和圍巾往上揚；2 幀只差布料擺動 | `40_v3_landing.png` |

---

## Boss

### E. 二階段攻擊專屬出招幀（4 × 4 幀）

下面 4 個 Boss 的 `phase`（二階段攻擊）只有前搖是自己的，出招 4 幀**和普通攻擊的像素完全一樣**，玩家看不出這是另一招。每個要畫 4 幀新的出招，比普通攻擊更大、更狠，並且要能接上二階段前搖的最後一幀。

| 檔名 | Boss | 參考（順序：待機、二階段前搖 4 幀、目前複製的普通攻擊 4 幀） |
| --- | --- | --- |
| `E_phase_broken_string_gardener.png` | 銅根主教（broken_string_gardener） | `50_boss_phase_broken_string_gardener.png` |
| `E_phase_rust_crown_guardian.png` | 苔鐘守母（rust_crown_guardian） | `50_boss_phase_rust_crown_guardian.png` |
| `E_phase_saltwhite_contract_judge.png` | 灰冠螳將（saltwhite_contract_judge） | `50_boss_phase_saltwhite_contract_judge.png` |
| `E_phase_sunken_hammer_smith.png` | 緋線執剪者（sunken_hammer_smith） | `50_boss_phase_sunken_hammer_smith.png` |

緋線執剪者的普通攻擊第 4 幀（attack[3]）也有問題：整個角色縮小了約三分之一（`52_boss_sunken_attack3_scale.png`）。二階段攻擊換新圖後，這一幀我會先試著用調整比例的方式修，修不好再請你補 1 幀。

> Use case identity-preserve. Same [Boss 外觀描述] as the reference, same hand-drawn ink and watercolor style. Four sequential right-facing poses in one row of a second-phase signature attack that continues from the last wind-up pose of the reference: a larger, more violent strike than the normal attack. Fixed camera and scale matching the reference, feet on the same baseline, full body and weapon visible, generous gutters, genuine transparency, no text or background.

### F. 招式收招過渡幀（6 × 3 × 2 幀，優先 2）

6 個 Boss 的 heavy（重擊）、cast（施法）、phase（二階段攻擊）結束後，都直接接同一套通用收招，姿勢跳變很明顯。每招補 2 幀過渡：從該招最後一幀過渡到通用收招第一幀。

參考：`51_boss_recover_<Boss>_<招式>.png`。每張依序是該招最後一幀、通用收招第一幀、待機第一幀。要畫的就是第一張和第二張之間的 2 幀。

檔名：`F_recover_<Boss>_<heavy|cast|phase>.png`，共 18 張，每張 2 幀橫排。例如 `F_recover_sunken_hammer_smith_heavy.png`。

> Use case identity-preserve. Same character and style as the reference. Exactly 2 in-between poses in one row that bridge from the left reference pose to the middle reference pose, smooth recovery after the attack. Fixed camera and scale matching the reference, feet on the same baseline, generous gutters, genuine transparency, no text or background.

---

## 普通怪

### G. 銜接和畫面錯誤

| 檔名 | 怪物 | 問題 | 要畫 | 參考 |
| --- | --- | --- | ---: | --- |
| `G_ash_banner_imp_windup.png` | ash_banner_imp | 前搖 4 幀和待機幾乎一樣，看不出要出招 | 4 | `60_ash_banner_imp_full_attack.png` |
| `G_ash_banner_imp_attack0.png` | ash_banner_imp | 出招第 1 幀的旗子變成黑色，其他幀都是紅色 | 1 | 同上 |
| `G_ash_banner_imp_recover.png` | ash_banner_imp | 出招結束是壓低突刺，收招第 1 幀直接跳回站直舉旗 | 2 | 同上 |
| `G_echo_contract_scribe_attack3.png` | echo_contract_scribe | 出招第 4 幀縮成一團，像受擊姿勢 | 1 | `62_echo_contract_scribe_attack3.png` |
| `G_wax_lancer_recover.png` | wax_lancer | 出招是水平突刺，收招 4 幀全是豎槍站姿，中間沒有過渡 | 2 | `63_wax_lancer_attack_to_recover.png` |

小計 10 幀。ash_banner_imp 的前搖：從待機姿勢開始，逐步把旗槍往後拉、身體下壓，最後一幀接上出招第 1 幀的突刺。

下面兩項我會先試著**只調整幀的順序**，不行才請你出圖：

- **delayed_shadow**（`61_delayed_shadow_full_attack.png`）：前搖 4 幀已經是持刃前刺的姿勢，出招第 1 幀反而是高舉蓄力，前搖和出招的姿勢像是排反了。
- **銅根主教**（broken_string_gardener）的重擊前搖和二階段前搖、**corridor_heavy** 的前搖：姿勢高、低、高來回跳，可能只是順序問題。

---

## 被裁到邊的單幀（H，優先 3）

下面 5 幀在原始生成圖裡就被裁到了，邊緣是一條直線。範圍都很小（槍尖、旗角、觸鬚、尾巴），玩家不一定注意得到。

| 檔名 | 角色 | 被裁位置 | 參考（第 2 張是要重畫的幀） |
| --- | --- | --- | --- |
| `H_broken_string_gardener_death3.png` | 銅根主教 死亡第 4 幀 | 右側 | `70_crop_broken_string_gardener_death3.png` |
| `H_delayed_shadow_recover0.png` | delayed_shadow 收招第 1 幀 | 頂部（第 1 張是要重畫的幀） | `70_crop_delayed_shadow_recover0.png` |
| `H_pipe_thrower_hurt2.png` | pipe_thrower 受擊第 3 幀 | 右側 | `70_crop_pipe_thrower_hurt2.png` |
| `H_npc_blind_bell_knight_talk3.png` | 盲鐘騎士（npc_blind_bell_knight）交談第 4 幀 | 頂部槍尖 | `70_crop_npc_blind_bell_knight_talk3.png` |
| `H_npc_deserter_flagbearer_talk6.png` | 逃旗手（npc_deserter_flagbearer）交談第 7 幀 | 左側旗角 | `70_crop_npc_deserter_flagbearer_talk6.png` |

每個檔案畫 1 幀，姿勢和參考的那一幀相同，只是完整不被裁。

---

## 不建議做：生成地圖的 36 個佔位 NPC

`GeneratedMain.tscn` 裡有 36 個 NPC（`npc_ch01_05_1` 這類編號），沒有自己的圖，按章節共用 6 個正式 NPC 的圖。這個場景是生成地圖的試玩版，主遊戲 World 不會用到。要給它們各自的外觀，需要設計 36 個新角色，每個 16 幀，共 576 幀，投入太大。除非你打算正式使用生成地圖，否則不建議做。

## 上傳方式

這台電腦上的倉庫在 `~/code/Crimson-Thread-Pilgrimage`，直接把檔案放進 `art_requests/character_motion_v5/incoming/` 就好，不用自己 commit，我會用 Git LFS 提交。

如果是在別的電腦上傳到 GitHub，請傳到新分支（例如 `art/character-motion-v5`）的同一個資料夾，不要直接傳到 main。

## 我收到後會做什麼

1. 逐張檢查：透明度、裁切完整、角色和畫風一致、動作語義正確、能接上前後幀。不合格的會指出是哪一幀、問題在哪。
2. 裁切、統一比例和腳底注冊，寫入 manifest 和生成記錄（提示詞、參考圖、選幀）。
3. 接入遊戲：
   - 主角：待機換新的披風循環；跑攻要新增狀態和切換邏輯；技能、道具、空中動作改用各自的素材。
   - Boss：二階段出招換新圖；收招支援「招式專屬收招 → 通用收招」，目前代碼只會找 `<招式>_recover`，找不到就直接用通用收招。
   - 普通怪：替換對應幀。
4. 跑 `test:character-motion`、相關的 Godot 真實渲染回歸，並截實機畫面給你看。
5. 開 PR，附上前後對比。

---

## 追加：上劈/下劈弧線重畫（4 套 × 6 幀）

現在的上劈、下劈在出刀的兩幀裡劍幾乎不動（例如地面上劈 52°→45°、空中下劈 -44°→-44°），而且沒有揮到頭頂或腳下，看起來像直直戳出去。重畫要讓劍身逐幀掃過一道弧線。角度以面朝右為準：0° = 正前方（3 點鐘）、90° = 正上方（12 點鐘）、-90° = 正下方（6 點鐘）。

| 檔名（覆蓋原檔） | 1 架勢 | 2 前搖 | 3 出刀開始 | 4 出刀結束 | 5 隨勢 | 6 收招 | 角度示意圖 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `E_attack_up.png` 地面上劈 | 10° | -150° | 0° | 90° | 125° | 10° | `refs/80_arc_guide_E_attack_up.png` |
| `F_air_attack_up.png` 空中上劈 | 10° | -150° | 0° | 90° | 125° | 10° | `refs/81_arc_guide_F_air_attack_up.png` |
| `E_attack_down_ground.png` 地面下劈 | 10° | 120° | 20° | -80° | -60° | 10° | `refs/82_arc_guide_E_attack_down_ground.png` |
| `E_attack_down.png` 空中下劈 | 10° | 110° | 20° | -85° | -60° | 10° | `refs/83_arc_guide_E_attack_down.png` |

每次生成附 3 張參考圖：① `refs/00_style_run_v4_8frames.png`（畫風）② 要覆蓋的那張舊圖（人物、站姿/空中腿姿）③ 對應的角度示意圖（只參考劍的方向，不參考畫風）。提示詞見對話或下方。

**不要畫刀光、殘影、光暈或弧形特效**，弧線特效由遊戲繪製；畫面上只要人物和劍。

### 共用開頭（4 個提示詞都以這段開始）

```text
Use case: stylized-concept.
Asset type: production source animation sheet for the 2D side-scrolling game Crimson Thread Pilgrimage.
Reference image 1 is the style reference (refs/00_style_run_v4_8frames.png): match this exact character identity, proportions, crisp dark ink contours, textured hand-painted anime rendering and muted palette: black ponytail, red scarf, worn teal cape, charcoal tunic and trousers, brown leather belt and boots, ONE short straight steel sword with a gold cross-guard, held in the RIGHT (front) hand, both hands on the grip when swinging. Reference image 2 is the previous version of this sheet: keep its character scale and leg stance. Reference image 3 is a stick-figure guide that shows ONLY the sword direction for each cel; follow its blade angles exactly but do not copy its drawing style.
All poses face RIGHT, fixed side-view camera, identical character scale and identical sword length in every cel.
Layout: exactly SIX cels in 3 columns x 2 rows, read left-to-right then top-to-bottom, on a 1536x1024 canvas. The character occupies at most 55% of the cel height so that a fully raised or lowered sword stays inside its own cel. Generous fully transparent gutters between cels and around the edges; nothing touches a neighbouring cel.
Background: genuine transparent alpha, no white fill, no checkerboard, no floor, no shadow, no text, no frame numbers, no panel borders.
Do NOT draw any slash trail, motion blur, afterimage, glow, speed lines or arc effect; the game draws the swing arc itself. Only the character and the sword.
The sword must visibly sweep along a continuous arc across the six cels; the blade angle must change between every consecutive cel, especially between cel 3 and cel 4.
```

### ① 地面上劈 `E_attack_up.png`

```text
[共用開頭]
Action: grounded rising upward slash, feet planted on the same ground line in all six cels.
Cel 1 guard: balanced stance, sword held forward at waist height, blade pointing forward (about 3 o'clock).
Cel 2 wind-up: crouch and twist back, sword drawn low behind the body, blade tip pointing back and down (about 8 o'clock).
Cel 3 slash begins: sword swung forward past the hip, blade horizontal pointing straight forward (3 o'clock), body rising.
Cel 4 slash ends: arms fully extended overhead, blade pointing straight UP (12 o'clock), body stretched upward, front heel slightly lifted.
Cel 5 follow-through: blade continues slightly past vertical toward the back (about 11 o'clock), weight settling.
Cel 6 recover: return to the cel-1 guard, blade forward (about 3 o'clock).
```

### ② 空中上劈 `F_air_attack_up.png`

```text
[共用開頭]
Action: airborne rising upward slash; in all six cels the character is in mid-air with the same tucked jumping legs as reference image 2, never standing.
Cel 1 guard: sword held forward at chest height, blade pointing forward (about 3 o'clock).
Cel 2 wind-up: sword drawn low behind the hip, blade tip pointing back and down (about 8 o'clock), shoulders twisted back.
Cel 3 slash begins: blade swung forward to horizontal, pointing straight forward (3 o'clock).
Cel 4 slash ends: arms fully extended above the head, blade pointing straight UP (12 o'clock), body stretched upward.
Cel 5 follow-through: blade slightly past vertical toward the back (about 11 o'clock).
Cel 6 recover: back to the cel-1 guard, blade forward (about 3 o'clock).
```

### ③ 地面下劈 `E_attack_down_ground.png`

```text
[共用開頭]
Action: grounded downward chopping slash aimed at the ground just in front of the feet; feet planted on the same ground line in all six cels.
Cel 1 guard: balanced stance, sword held forward at waist height, blade pointing forward (about 3 o'clock).
Cel 2 wind-up: sword raised high above and slightly behind the head, blade pointing up and back (about 11 o'clock).
Cel 3 slash begins: sword coming down in front of the body, blade pointing forward and slightly up (about 2 o'clock).
Cel 4 slash ends: deep lunge with bent front knee, blade pointing almost straight DOWN at the ground in front of the front foot (between 5 and 6 o'clock), tip just above the ground line.
Cel 5 follow-through: blade eases back to point down and forward (about 5 o'clock).
Cel 6 recover: return to the cel-1 guard, blade forward (about 3 o'clock).
```

### ④ 空中下劈 `E_attack_down.png`

```text
[共用開頭]
Action: airborne downward slash striking straight below the body; in all six cels the character is in mid-air with the same tucked legs as reference image 2, never standing.
Cel 1 guard: sword held forward at chest height, blade pointing forward (about 3 o'clock).
Cel 2 wind-up: sword raised above and slightly behind the head with both hands, blade pointing up and back (about 11 o'clock).
Cel 3 slash begins: sword coming down in front of the chest, blade pointing forward and slightly up (about 2 o'clock).
Cel 4 slash ends: both arms driven down, blade pointing straight DOWN beneath the body (6 o'clock), legs tucked up and out of the blade's way.
Cel 5 follow-through: blade eases to point down and forward (about 5 o'clock).
Cel 6 recover: back to the cel-1 guard, blade forward (about 3 o'clock).
```
