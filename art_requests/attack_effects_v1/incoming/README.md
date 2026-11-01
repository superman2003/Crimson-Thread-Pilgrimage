# 攻击特效源图交付（PR #140）

本目录使用内置 imagegen 按 [PR #140](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/140) 的清单制作透明源图。已交付 **39 张、288 格**：怪物飞行物 15 张、地面危害 8 张、地波 3 张、地刺 2 张、光束 4 张、主角技能与战具 7 张。检查状态见 [delivery_status.json](delivery_status.json)。

每项包含原始透明 `.png`、当次实际使用的同名 `.txt` 提示词和同名 `.json` 检查记录。生成器的原始 PNG 字节保持不变；未统一缩放、重新排版或切帧。

生成尺寸与提示词要求可能不同，切帧应读取 JSON 的 `frames[].rect_xyxy`（左、上、右、下，右下不包含），不要按提示词尺寸或盲目等分切片。坐标沿图形间空隙划分；极淡的光晕可能接近切线。光束的左右接边属于设计需要。

本次交付为源图。运行时导入、锚点、判定范围对齐、循环速度、逐帧淡出、光束拼接和缩小后的辨识度仍需在游戏中验收。

## 怪物飞行物

- [FX_P_thorn.png](FX_P_thorn.png) — 荊針，8 格；[提示词](FX_P_thorn.txt)、[检查记录](FX_P_thorn.json)。
- [FX_P_bolt.png](FX_P_bolt.png) — 弩矢，8 格；[提示词](FX_P_bolt.txt)、[检查记录](FX_P_bolt.json)。
- [FX_P_stinger.png](FX_P_stinger.png) — 蠟針，8 格；[提示词](FX_P_stinger.txt)、[检查记录](FX_P_stinger.json)。
- [FX_P_net.png](FX_P_net.png) — 根網，8 格；[提示词](FX_P_net.txt)、[检查记录](FX_P_net.json)。
- [FX_P_blade.png](FX_P_blade.png) — 影刃，8 格；[提示词](FX_P_blade.txt)、[检查记录](FX_P_blade.json)。
- [FX_P_spore.png](FX_P_spore.png) — 孢子，8 格；[提示词](FX_P_spore.txt)、[检查记录](FX_P_spore.json)。
- [FX_P_pollen.png](FX_P_pollen.png) — 花粉團，8 格；[提示词](FX_P_pollen.txt)、[检查记录](FX_P_pollen.json)。
- [FX_P_seed.png](FX_P_seed.png) — 藤種，8 格；[提示词](FX_P_seed.txt)、[检查记录](FX_P_seed.json)。
- [FX_P_incense.png](FX_P_incense.png) — 香灰滴，8 格；[提示词](FX_P_incense.txt)、[检查记录](FX_P_incense.json)。
- [FX_P_light.png](FX_P_light.png) — 光珠，8 格；[提示词](FX_P_light.txt)、[检查记录](FX_P_light.json)。
- [FX_P_page.png](FX_P_page.png) — 書頁，8 格；[提示词](FX_P_page.txt)、[检查记录](FX_P_page.json)。
- [FX_P_slug.png](FX_P_slug.png) — 管彈，8 格；[提示词](FX_P_slug.txt)、[检查记录](FX_P_slug.json)。
- [FX_P_chime.png](FX_P_chime.png) — 鐘聲彈，8 格；[提示词](FX_P_chime.txt)、[检查记录](FX_P_chime.json)。
- [FX_P_wheel.png](FX_P_wheel.png) — 水輪刃，8 格；[提示词](FX_P_wheel.txt)、[检查记录](FX_P_wheel.json)。
- [FX_P_key.png](FX_P_key.png) — 鑰刃，8 格；[提示词](FX_P_key.txt)、[检查记录](FX_P_key.json)。

## 地面危害

- [FX_A_seal.png](FX_A_seal.png) — 印陣，8 格；[提示词](FX_A_seal.txt)、[检查记录](FX_A_seal.json)。
- [FX_A_fungus.png](FX_A_fungus.png) — 菌圈，8 格；[提示词](FX_A_fungus.txt)、[检查记录](FX_A_fungus.json)。
- [FX_A_haze.png](FX_A_haze.png) — 煙圈，8 格；[提示词](FX_A_haze.txt)、[检查记录](FX_A_haze.json)。
- [FX_A_snare.png](FX_A_snare.png) — 根籠，8 格；[提示词](FX_A_snare.txt)、[检查记录](FX_A_snare.json)。
- [FX_A_caltrops.png](FX_A_caltrops.png) — 灰釘陣，8 格；[提示词](FX_A_caltrops.txt)、[检查记录](FX_A_caltrops.json)。
- [FX_A_shadow.png](FX_A_shadow.png) — 影池，8 格；[提示词](FX_A_shadow.txt)、[检查记录](FX_A_shadow.json)。
- [FX_A_focus.png](FX_A_focus.png) — 聚光，8 格；[提示词](FX_A_focus.txt)、[检查记录](FX_A_focus.json)。
- [FX_A_slag.png](FX_A_slag.png) — 鐵渣灘，8 格；[提示词](FX_A_slag.txt)、[检查记录](FX_A_slag.json)。

## 地波

- [FX_W_quake.png](FX_W_quake.png) — 震地裂波，8 格；[提示词](FX_W_quake.txt)、[检查记录](FX_W_quake.json)。
- [FX_W_chime.png](FX_W_chime.png) — 鐘聲地波，8 格；[提示词](FX_W_chime.txt)、[检查记录](FX_W_chime.json)。
- [FX_W_surge.png](FX_W_surge.png) — 渠水湧浪，8 格；[提示词](FX_W_surge.txt)、[检查记录](FX_W_surge.json)。

## 地刺

- [FX_R_roots.png](FX_R_roots.png) — 根刺，6 格；[提示词](FX_R_roots.txt)、[检查记录](FX_R_roots.json)。
- [FX_R_spears.png](FX_R_spears.png) — 槍陣，6 格；[提示词](FX_R_spears.txt)、[检查记录](FX_R_spears.json)。

## 光束

- [FX_B_steam.png](FX_B_steam.png) — 蒸汽，4 格；[提示词](FX_B_steam.txt)、[检查记录](FX_B_steam.json)。
- [FX_B_erase.png](FX_B_erase.png) — 擦除線，4 格；[提示词](FX_B_erase.txt)、[检查记录](FX_B_erase.json)。
- [FX_B_thread.png](FX_B_thread.png) — 緋線，4 格；[提示词](FX_B_thread.txt)、[检查记录](FX_B_thread.json)。
- [FX_B_gate.png](FX_B_gate.png) — 冠門封線，4 格；[提示词](FX_B_gate.txt)、[检查记录](FX_B_gate.json)。

## 主角技能与战具

- [FX_H_needle.png](FX_H_needle.png) — 回聲針（技能），8 格；[提示词](FX_H_needle.txt)、[检查记录](FX_H_needle.json)。
- [FX_H_shockwave.png](FX_H_shockwave.png) — 鐘鳴震波（技能），8 格；[提示词](FX_H_shockwave.txt)、[检查记录](FX_H_shockwave.json)。
- [FX_H_snare.png](FX_H_snare.png) — 鹽印縛線（技能），8 格；[提示词](FX_H_snare.txt)、[检查记录](FX_H_snare.json)。
- [FX_H_shard.png](FX_H_shard.png) — 銅鈴投罐（戰具），8 格；[提示词](FX_H_shard.txt)、[检查记录](FX_H_shard.json)。
- [FX_H_mine.png](FX_H_mine.png) — 絆線釘（戰具），8 格；[提示词](FX_H_mine.txt)、[检查记录](FX_H_mine.json)。
- [FX_H_fog.png](FX_H_fog.png) — 鹽霧瓶（戰具），8 格；[提示词](FX_H_fog.txt)、[检查记录](FX_H_fog.json)。
- [FX_H_lure.png](FX_H_lure.png) — 回響誘鈴（戰具），4 格；[提示词](FX_H_lure.txt)、[检查记录](FX_H_lure.json)。

## 检查方式

在仓库根目录运行 `python -X utf8 art_requests/attack_effects_v1/inspect_sources.py`，重新检查 PNG、透明通道、帧内容和边界，并更新每张 JSON 与交付状态。
