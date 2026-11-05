# 六位正式 Boss 的动作补帧

2026-11-01，内置 `image_gen` 生成，48 张选定 PNG、288 个新姿势，286 个接入正式角色图集，2 个保留为源图。每位 Boss 48 个新姿势：四套攻击的前摇／出招各补三帧（24），通用及专属收招接点 12，待机／步态循环接点 12。

- 苔钟守母：`rust_crown_guardian`
- 绯线执剪者：`sunken_hammer_smith`
- 灰冠螳将：`saltwhite_contract_judge`
- 铜根主教：`broken_string_gardener`
- 静音巡礼统帅：`silent_pilgrim_commander`
- 无声王冠：`silent_crown_core`

`incoming/` 保存每张选定图、当次实际完整提示词、生成路径记录与 `delivery_manifest.json`。源图不做脚本重绘、像素插帧、渐变或复制扩帧。脚本只做完整轮廓分离、比例／水平锚点注册、整张颜色校准和图集打包。预览中的暗色 RGB 位于 alpha=0 的透明像素里，不会在游戏中显示为背景光晕。

`refs/` 是补帧前的正式姿势参考；`specification.json` 为 48 个六姿势任务，逐格标明插入哪个动画、哪一对关键帧之间及进度。长图初稿未准确遵循最后一组动作语义，未选入交付；所有选定图都改为六组明确端点配对。

参考图冻结在 v5 接入之后。`build_boss_motion_v6_refs.py` 会拒绝用改造后的图集覆盖该参考；已有 source／prompt 应沿用，不能用重跑参考工具代替正式重新评审。

```powershell
node tools/run_python_tool.mjs tools/build_boss_motion_v6.py --check
npm run test:character-motion
```

重建当前六个图集：`node tools/run_python_tool.mjs tools/build_boss_motion_v6.py`。v5 检查会验证 v6 的原始基线，避免覆盖新帧。攻击时长、伤害判定与状态机没有改变。

[完整验证与播放对比](../../docs/report/20261101_boss_motion_v6.md)

当前 AI 使用的新增姿势为 262 个，另 24 个是四位 Boss 的备用普攻动画补帧；铜根主教重击及阶段招式各一张向蹲姿过渡的补帧仅保留源图，避免破坏主线直接回待机的处理。该备用预览单独标注，未增加 AI 招式。

主线适配基线：`bd11a96f`。原始 `refs/` 和提示词保留生成时的 v5 参考；构建器将旧 `*_recover` 插入位置显式映射到主线 `*_bridge`／`*_settle`，按主线当前图集重新计算尺寸、锚点和颜色。桥接帧仍在原 0.18 秒内播放，通用收招使用剩余时间；铜根主教的两种站姿收招仍直接回待机。
