# 巡礼美术与战斗改版

本次以手绘侧视 2D、互连地图和可读战斗为目标。以《丝之歌》的设计质量为参考，角色、道具、场景图像与对白均围绕本项目的巡礼世界创作。

## 已接入内容

- 六章各自的背景、12 种平台模块、6 种装饰和6种地层纹理。连续地形共61段，将141个原平台锚点连接成道路、斜坡、桥、遗迹与洞道；保留垂直探索和能力门。
- 40种小怪与6位Boss全新动画图集。每类小怪2个招式、每位Boss4个招式，共104个战斗动作配置。怪物包含地面、飞行和固定位置类型。
- Boss额外拥有重击、施法、阶段动作。前摇与生效动作分别播放，按招式时长调整动画速度。阶段招式在血量阈值后解锁。
- 25位NPC的新图集、头像和不同的对白；4个可交付的心愿，完成旗标防止重复发奖。
- 48个物品图标；分类背包、铭文详情、旅记标记、中文HUD、对话选项和音量滑杆。
- 新画的休息长椅、拉杆和钟门。剧情信物采用F收取，普通材料仍可碰触拾取。

## 六位Boss

|Boss|战斗特征|
|---|---|
|苔钟守母|重压、地面波、孢子散射、延迟根刺|
|绯线执剪者|近身剪击、绯线射束、地面封路、跃袭|
|灰冠螳将|正面格挡、突进、上段打击、连续斩击|
|铜根主教|杖击、缓速散射、根蔓排列、错时区域攻击|
|镜池新娘|镜影换位、锁定后的延迟区域、跃击|
|百钥守门人|回返钥弹、射束、不同速度的地面波|

曲射管弹落地后会留下带预警的危险区域；直线弹可以用面向弹丸的斩击反弹。根蔓缓速可通过冲刺解除。钻伏招式降低轮廓透明度后扑出。

## 素材与再构建

原始PNG保存在`godot/assets/sprites/flat_maps`、`original_creatures`、`original_npcs`、`original_items`、`original_interactables`。图集索引器只记录区域和透明边距，不重画PNG像素。

本轮生成提示词保存在`original_creature_designs.json`、`original_boss_attack_designs.json`、`original_world_art_designs.json`、`flat_maps/terrain_prompts.json`和`original_interactables/provenance.json`。此前18张地图图像从已保存的原图恢复，旧提示词未恢复，不作为本轮提示词记录。

索引和配置可按以下顺序更新（需要Pillow、NumPy、SciPy）：

```sh
python tools/build_flat_map_art.py
python tools/build_chapter_terrain.py
python tools/build_creature_combat.py
python tools/build_original_creature_art.py
python tools/build_original_world_art.py
python tools/rewrite_pilgrimage_dialogue.py
```

中文字体为Google Fonts提供的Noto Sans SC，许可见`godot/assets/fonts/OFL.txt`。为适配认证上传通道的单次请求限制，字体固定为界面使用的450字重，保留全部31,036个字形；本轮原创建图和字体直接存储在Git中。

## 验证

使用Godot4.6.1。`pilgrimage_overhaul_validation.gd`实际创建六章，检查连续地形和斜坡双向行走、对话/头像、背包、NPC交付防重复、46类敌人的104个招式前摇/生效/恢复和Boss阶段变化。

`all_chapters_demo_validation.gd`保留章节拓扑、独特素材、生成位置、存档、捷径、Boss击败、奖励和跨章转移检查；更新了旧素材路径、招式数量和需要真实靠近才能交互的测试。

```sh
godot --headless --path godot --script res://scripts/pilgrimage_overhaul_validation.gd
godot --headless --path godot --script res://scripts/all_chapters_demo_validation.gd
python tools/validate_campaign_chapters.py
python tools/validate_chapter_files.py
npm run check
```

图形模式运行第一个脚本并在`--`后加`--capture`，会保存六章、Boss、对话、背包、地图和设置的实机截图。

网页端的game-data、static-smoke和runtime-smoke测试通过。完整`npm test`最后的旧map-quality命令无法运行：基线仓库缺少`tools/audit_platform_geometry.py`及`tools/audit_map_uniqueness.py`。本次地形通过上述Godot运行检查；不将缺失的旧审计报告为通过。

本改版分支为`codex/flat-2d-map-art`。提交不包含导入缓存或未修改的第三方素材。
