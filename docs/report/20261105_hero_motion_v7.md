# V02：主角五类动作统一（2026-11-05）

基于当前主线 `db87145b6d439d20e320a953bc9dc1f86a25db5e`，在独立 `codex/hero-motion-v7` 工作区推进。正式跑步与方向攻击已使用 v4 画稿，起跳、落地、冲刺、受击和死亡仍使用较早的 v3；这五类动作切换时的人物轮廓和衣料表现不同。本批以 v4 跑步为同一风格参考，补绘并接入五类动作。

## 交付

四张选定源图、28 个新绘姿势：起跳 4、落地 4、冲刺 6、受击 6、死亡 8。原有五类动作共 20 个姿势被替换，独特运行时帧由 130 增至 138；短起跳 `jump_start` 与落地 `land` 复用各自四格，不重复计数。原始 20 个 PNG 继续保留，其他 110 个独特帧及其动画记录不改。

源 PNG、实际提示词、参考哈希、实际尺寸与切格、固定缩放、逐帧注册和旧动画记录均可追溯。初版冲刺剑身偏短，image_gen 编辑后的 `dash_v2` 为选定画稿，未选初稿保存但不计新增姿势。没有复制帧、端点混合、变形扩帧或运动插帧。主体裁取、正常缩放和透明画布注册由工具执行，原图字节保留。

新帧通过现有 `generated_hero_v3/manifest.json` 接入，后台读取与导出仍沿该唯一清单，无额外延迟加载分支。七个动画入口的总播放时长保持原值，循环标记仍关闭：`jump`／`landing`／`dash`／`hurt`／`death` 各 0.4 秒；`jump_start` 为 2/18 秒；`land` 为 3/22 秒。冲刺实际 0.16 秒与落地姿态 0.14 秒继续由原控制器归一化取帧；死亡仍在原 0.9 秒中播放、保持末帧并淡出。控制器、碰撞、移动参数、战斗窗口、伤害与存档逻辑未改。

每张源图只有一个共用倍率，以正式跑步的 21px 露出脸部高度校准；不逐帧改变角色大小。首轮沿 v4 跑步素材的足底 287 行注册，真实 GPU 对比发现比正式地面锚点低约 4.6px，最终改为主角清单的 `foot_baseline=280`。空中起跳后两格按躯干 222 行注册，避免把源图中画出来的轨迹再叠到实际跳跃上。较早跑步素材自身的足底行没有在本批改写。

## 验证

Godot 4.6.1 `14d19694e`，Windows；NVIDIA RTX 5060 Compatibility 渲染。

- 最终足底注册后，12 套相关无头回归通过：`character_art_prewarm`、`hero_animation`、`player_motion_continuity`、`player_hurt_art`、`player_dash_art`、`player_movement_art`、`combat_input_events`、`player_state_cleanup`、`player_upgrade_regression`、`player_action_buffer`、`ability_movement`、`melee_recovery`。
- 原生 GPU 复验：`hero_animation` 195 项、`player_motion_continuity` 1192 项、`character_art_prewarm` 通过且 `sync_loads=0`。动画检查保留原断言，新增七入口的帧数、原时长、非循环、完整导入图像、版本路径与 28 个独特引用；冲刺末帧检查改为序列末格，仍要求短冲刺到达收招姿态。
- 最终 Godot 两轮 recovery-mode 导入通过。该模式只导入资源，不代表编辑器插件验收。
- `validate_hero_v3.py` 通过，138 个正式独特帧，无输出裁边；原 v3 素材已有的 20 条源边余量提醒仍保留。
- `npm run test:character-motion` 完整通过，原角色／小怪／v5／跑步／方向攻击检查均保留，再校验本批新绘姿势。临时恢复主线旧清单作反向验证时，动画专项 36 项失败；恢复新版后 195 项通过，原清单未被宽松兼容掉。
- `npm test`、CI workflow 与分片完整性检查、导出审计及 19 项导出审计单测通过；两套桌面导出预设可达 363 个运行时脚本／场景，零错误，取样脚本仍被排除。
- Windows 完整素材校验发现旧打包器把资源地址写成反斜杠；三处序列化改用 `as_posix()`。npm Python 启动器默认传入 UTF-8，保留显式用户覆盖。它们不重写已有角色图集。初次 GBK、路径与未水合 LFS 源图失败日志留在本批 artifacts 中；无效的 `player_art_prewarm` 独立套件选择也未计为通过，实际入口是 `character_art_prewarm`。
- 旧四帧小怪修复的逐字节测试在本机另有两项失败：Pillow 12 的 zlib-ng 压缩流不同，四张图的过滤扫描行全部相同。打包器改用标准 zlib 的原 PNG 压缩参数编码同一批扫描行，既有四张 PNG 未重写，原严格字节／无历史校验全部保留并通过（17 项）；没有将门禁改成只看像素。

完整素材检查已通过；准确发布头 CI 结果继续写入本批 `verification.json` 和 PR。没有声称本地跑完全部 195 个默认／叙事套件。

## 实际画面

生产 Player、原时钟、双向、深浅背景的真实 GPU 对比，左两列为朝右原／新，右两列为朝左原／新：

![动作早段对比](../../artifacts/hero_motion_v7/before_after_early.png)

![收束与死亡末帧对比](../../artifacts/hero_motion_v7/before_after_settle.png)

[216 帧原时钟对比视频](../../artifacts/hero_motion_v7/before_after.mp4)。视频是固定 60Hz 取样、三次原周期回放，没有插帧或变速；它是暂停物理后的动作取样，不是自然战斗、实际帧率测量或六区通关。真实死亡与复活结算另由动作连续性回归覆盖。

## 保留范围

V02 整包继续 OPEN。待机呼吸与旧动作交界、其他技能／钩索／格挡的人物画稿、NPC 与其余角色动作仍需分批；自然游玩中画风一致性和连续观感尚需体验验收。V04 混战、T03 长期稳定、T04 完整流程与 T05 最终发行验收不因本批勾选。
