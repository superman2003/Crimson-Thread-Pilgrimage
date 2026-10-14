# 已有截图索引｜分镜审阅用途

路径以本文件为起点。以下均为仓库已有文件，本包未新增、修图或重新捕获。来源描述来自基线 README、gallery 和验收文档；这是证据索引，不是当前版本截图交付。

## 可用于内部选图的真实渲染资料

| 编号／已有文件 | 来源与捕获条件 | 建议用途／必须附带的限制 |
| --- | --- | --- |
| S01 [HUD](../../../artifacts/ui_redesign/world_hud.jpg) | [2026-10-11 UI 图册](../../gallery/20261011_ui_redesign.md)：Godot 4.6.1，World，隔离存档、预置进度 | HUD 与界面视觉分镜；标“历史原型实机·预置进度”。已目视确认场景与 HUD；主角、材质版本可能落后于当前基线，不能直接称最新效果 |
| S02 [契印](../../../artifacts/ui_redesign/seal.jpg)、[技能](../../../artifacts/ui_redesign/skills.jpg)、[战具](../../../artifacts/ui_redesign/tools.jpg) | 同 UI 图册；真实运行时菜单 | 配装页镜头参考；保留“预置进度功能展示”。契印图已目视确认；不证明三契印自然取得、资源公平性或所有构筑平衡 |
| S03 [旅记](../../../artifacts/ui_redesign/journal.jpg)、[对话](../../../artifacts/ui_redesign/dialogue.jpg) | 同 UI 图册；对话用于阅读布局展示 | 旅记／对话分镜；不能将预置文字和进度当作自然剧情流程证据，更不能替换成本批未接入文案 |
| S04 [地图](../../../artifacts/ui_redesign/map.jpg)、[行囊](../../../artifacts/ui_redesign/inventory.jpg) | 同 UI 图册；隔离展示状态 | 菜单操作镜头参考；不是六区探索完成证明，也不是当前版本全部设置／输入验收 |
| S05 [练针区](../../../artifacts/ui_redesign/practice.jpg)、[技能动作](../../../artifacts/ui_redesign/skill_action.jpg) | 同 UI 图册；World 实际运行 | 练习／技能镜头参考，标注展示状态；一张动作图不能证明动画连贯、命中手感或伤害开启的战斗体验 |
| S06 [旧版 World 技能动作](../../../artifacts/seal_world/skill_action.png)、[旧版构筑](../../../artifacts/seal_world/loadout.png) | [World 九图图册](../../gallery/20261011_seal_world.md)：1280×720，Compatibility，隔离存档、预置货币与配装；技能执行真实付费动作 | 追溯技能耗能与真实菜单接入；是 UI 重制前历史素材，不能混称最新界面 |
| S07 [五间房对比](../../../artifacts/ch01_rooms/comparison.jpg)、[东庭露台](../../../artifacts/ch01_rooms/east_balcony.jpg) | [房间图册](../../gallery/20261011_ch01_rooms.md)：World，1280×720，固定同一镜头，隔离存档，敌人保持起始姿态 | 房间构图审阅；不是玩法录像或带伤路线证据。[实现说明](../../CH01_ROOM_RECONSTRUCTION.md)明确画廊保留 `655bf74` 阶段，后续材质已变化 |
| S08 [第一章洞穴](../../../artifacts/cave_exploration/ch01_cave.jpg)、[第一章升降笼](../../../artifacts/cave_exploration/ch01_lift.jpg)、[六章总览](../../../artifacts/cave_exploration/six_chapter_caves.jpg) | [README](../../../README.md)与[当前素材图册](../../gallery/20261011_current_assets.md)：洞穴升级初版 Godot 实机；总览为多图组合 | 洞道／升降笼分镜历史参考；旧普遍局部视野已改为仅特殊暗穴启用。来源不足以证明自然抵达、伤害开启或当前完整视野，不作最新商店主图 |
| S09 [六区旧材质对比](../../../artifacts/world_material/six_regions.jpg) | [材质说明](../../WORLD_MATERIALS.md)：Godot 4.6.1，World，1280×720，隔离存档，同几何／镜头／玩家位置，敌人暂停 | 技术变化历史记录；不是探索录像、长期稳定性、完整美术或性能验收 |
| S10 [岩壁接缝六区对比](../../../artifacts/hero_rock_upgrade/checkpoint4/six_region_comparison.jpg) | [主角与岩壁检查点 4](../../HERO_AND_LARGE_ROCK_UPGRADE.md)：真实 GL；外层实体岩壁边界镜头，受相机限位约束；Dummy 音频 | 接缝修复证据，仅用于技术审阅。不是可玩房间构图、探索路径、原声听感或逐房美术完成证明；禁止作自然玩法镜头 |

这些文件有明确真实渲染来源，但“实机”只说明运行时渲染方式。隔离存档、历史版本、冻结敌人、固定镜头或动作夹具等条件必须和素材一起保留。对外使用前需核对当前构建并重拍受影响画面；本包未发现足以直接宣称“当前六区自然带伤全流程”的截图组。

## 排除项：不可作为玩法证据

| 资料 | 正确类型／处理 |
| --- | --- |
| [全地图总览](../../../artifacts/current_gallery/map_overview.jpg)及各章 `*_full_map.jpg` | JSON 世界坐标绘制的布局图；可讨论关卡布局，不可称实机全景或连续可玩录像 |
| [小怪图册](../../../artifacts/current_gallery/monsters_all.jpg)、[Boss 图册](../../../artifacts/current_gallery/bosses_all.jpg) | 从 manifest 的 idle 首帧提取的素材拼图，展示比例经调整；不证明游戏中体型、AI、战斗或数量平衡 |
| `artifacts/seal_upgrade/seal_ui_0.png` 至 `seal_ui_5.png` | [契印验收](../../SEAL_VALIDATION.md)明确为独立 UI 测试夹具灰底布局图；不是 World 场景 |
| 主角源表、concept、生成预览、本批新美术／音频／文案候选 | 设计或待接入资料；不能剪入实机段落冒充运行效果。若另做开发日志展示，必须显著标注候选状态 |
| `artifacts/godot_showcase` 历史总览或 LFS 占位文件 | [素材图册](../../gallery/20261011_current_assets.md)明确不作当期展示来源；本包不采用 |

## 使用前检查

本包对本页 22 个具体图片链接做了文件存在与图像解码核对，目视抽查 S01 HUD 和 S02 契印页；没有声称逐张完成美术验收。对外选择图片时，应逐张检查文字溢出、旧角色／旧材质、调试信息和当前基线差异，并按 [第三方素材声明](../../../THIRD_PARTY_NOTICES.md)核对相关素材的署名与使用条件。技术图、图册和旧截图不能通过裁掉标签变成自然游玩证据。
