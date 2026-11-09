# 正式小怪与 Boss 的逐动作翻倍补帧

范围：正式六章的 40 种小怪、6 位 Boss，生产基线 `ff8ab652b224523afbf8789a7b5ad98a676eb389`（已包含主分支的标签去除／定位修复）。

`specification.json` 冻结生产基线的 46 套正式 manifest 和逐格前后姿势，计划新增 5,439 个运行时姿势，使全部现有动画引用从 5,439 增至 10,878。攻击前摇／出手／收招各由 12 增至 24；待机、移动、受击、死亡、后撤、戒备及保留的兼容片段也分别翻倍。这个总数是逐动画帧引用，不等于招式数量。

使用内置 `image_gen`，每个有序端点对绘制一个新姿势。237 张选定源图各含 24 格，末张的多余候选格不启用；最终只按规范中的 5,439 个位置计数。没有通过复制帧、像素混合、变形补间或延长招式时钟增加帧数。

`incoming/*.png` 和旁边的 `.receipt.json` 保留选定原图、实际完整提示词、参考板路径、生成结果路径及 SHA-256。被拒绝的图片通常只留在本地 `rejected/`，不计入完成素材；若选定结果的透明背景处理依赖其中一张原图，则连同那张输入和收据保存其来源链。`baselines/` 是翻倍前的 manifest 快照，不是运行时依赖。

`tools/build_character_motion_v8.py` 只做完整轮廓提取、透明边缘处理、端点可见身高／水平锚点／支撑基线校准、整张源图统一的轻量 RGB 校准，以及不超过 2048×2048 的纹理分页。原有帧对象、图集和来源记录保留。新增图层 `motion_v8_manifest.json` 将新姿势插在每个旧姿势之后；动画 FPS 同步翻倍，保持循环周期和拟合后的战斗时限不变。

初始有序参考板使用 `ec31dbf79ca2729103fc9d90817d2470b9777c05`。`reference_specification.json` 保存实际绘制时的端点几何；`baseline_refresh.json` 记录随后主分支对 9 个角色的标签去除／定位修复。构建时按修复后的生产端点重新校准，选定源图及其实际输入板保持原样。透明参考板可用旧版本历史重建：

```powershell
python -X utf8 tools/build_character_motion_v8.py --alpha-refs
```

`--prepare` 仅供无交付源图的新任务初始化，已有源图时会拒绝覆盖冻结规格。

接入全部合格源图／检查可重复构建：

```powershell
python -X utf8 tools/build_character_motion_v8.py --build
python -X utf8 tools/build_character_motion_v8.py --check
npm run test:character-motion-v8
```

开发时可用 `--only <kind>` 按完整角色检查。原生 `character_motion_v8_validation.gd` 验证正式加载优先级、每个旧帧的图集和定位不变、逐动作精确翻倍、循环周期和攻击时限。`runtime_report.json` 由实际完成的构建产生；没有该角色的完整合格源图时，不能把计划数量作为交付数量。

这些技术检查不替代真实播放的姿态连续性判断。原生对照必须使用同一套升级后 AI／伤害规则、相同时钟，仅切换 v7／v8 身体素材；静态拼图和动画取样不证明自然通关或稳定帧率。

逐角色、逐动作的帧数规格见 [clip_inventory.md](clip_inventory.md)。生产构建只接受 24 个完整轮廓的透明源图；启用格必须具有不同的像素内容，且每个旧帧恰好对应一个新增位置。
