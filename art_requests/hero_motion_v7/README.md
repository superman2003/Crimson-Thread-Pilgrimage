# 主角五类动作新绘（V02，2026-11-05）

以正式 v4 跑步画稿为身份、比例和画风参考，使用内置 image_gen 生成四张选定源图，接入五类动作共 **28 个新绘姿势**：起跳 4、落地 4、冲刺 6、受击 6、死亡 8。它们替换原 v3 的 20 个姿势，运行时独特帧由 130 增至 138；`jump_start` 与 `land` 复用本批起跳／落地，未重复计数。

`sources/` 保留每次实际提示词和原始 PNG。冲刺首次交付剑身偏短，后以 image_gen 编辑为 `dash_v2.png`；初稿也保留，但不计作额外六个新姿势。没有复制旧帧、混合端点或插值生成姿势。`generation_manifest.json` 记录选图、哈希、参考、切格、共用缩放及未选初稿；`previous_animations.json` 是主线 `db87145b` 的七个原动画记录，用于对比和回退。

运行 `npm run build:hero-motion-v7` 重建。工具只进行切格、去除主体之外的淡色透明边、每张源图一次固定倍率缩放和透明画布注册，不做逐帧体型归一化。地面姿势沿正式 `foot_baseline=280`，起跳后两格按躯干锚点对齐。原图保持原始字节；打包后的 PNG 因正常缩放而不是原尺寸像素副本。

通过正式主角清单接入，后台预热和导出资源引用沿用同一个清单。原有 v3 帧文件保留，其余动作和游戏逻辑不变。`npm run test:character-motion` 与 `tools/validate_hero_v3.py` 校验可重建结果；原生 `hero_animation`、`player_motion_continuity` 与 `character_art_prewarm` 覆盖实际 Player。

本批不关闭 V02 整包：待机呼吸、其他技能／钩索／格挡画稿、NPC、其余状态交界的自然观感仍待验收。实际证据见 [报告](../../docs/report/20261105_hero_motion_v7.md)。
