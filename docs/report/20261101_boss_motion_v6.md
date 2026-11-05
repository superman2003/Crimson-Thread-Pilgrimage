# 六位 Boss 动作补帧：主线适配结果

PR #492 基于 main `bd11a96f972b518550abaaba3427dc9ac4aefdd7` 完成适配。保留主线 v5 的桥接、铜根主教站姿直接回待机、颜色校准和卡顿后的进度补偿；未覆盖主线的战斗、AI、字体、UI 或网页代码。

交付 48 张完整源图、288 个新姿势及当次实际提示词。**286 个新姿势接入图集：262 个供当前动作使用，24 个补齐四位 Boss 的备用普攻。** 铜根主教重击及阶段招式各一张向蹲姿过渡的旧画稿仅保留源图，避免把主线已消除的站起→蹲下跳变接回去。每张源图的使用数、排除原因、SHA-256 和颜色校准均写入各角色 `motion_generation.json` 的 `boss_motion_v6` 字段。

- 待机 4→8 帧、走路 8→16 帧，包含循环接点。
- 普通／重击／施法／阶段招式的前摇与出招各 4→7 帧。
- 通用收招新增六帧；普通桥接 2→4 帧，铜根主教两种站姿收招 2→3 帧。
- 桥接仍使用主线原有 0.18 秒，随后在剩余时间内播放通用收招，或按主线规则回待机。没有延长伤害、收招或惩罚窗口，也没有增加 AI 招式。

新帧按 main 当前端点重新计算尺寸、水平锚点、饱和度和 RGB 校准；原 v5 的校准值和像素保留。原始 `refs/` 与提示词保留生成时的旧 v5 端点，构建器显式映射到主线 `*_bridge`／`*_settle`，而不是重新生成或改写源图。半像素锚点保留原图集的取整奇偶性，避免扩大画布后旧帧移动一个像素。

## 验证

- `npm test` 通过。
- 六位 Boss 的 **376 个 main 原帧引用**：源注册、顺序、可见 RGBA 和游戏内定位全部保持。可以直接从 Git 提取 main 基线复现，不依赖提交外的本地归档。
- `npm run test:character-motion` 完整通过：v5／v6 登记、全部 71 角色图集及主角既有动作逐项重建检查。
- Godot 4.6.1：两轮 recovery-mode 导入均通过，零引擎错误；该模式不验收编辑器插件。
- 动作专项在无头和真实 NVIDIA GL 下均为 **6230 项、0 失败、71 角色、3114 个运行时帧引用**。主线 22 个特殊招式的桥接路由、剩余收招窗口及卡顿进度补偿继续受检。
- 原生 GL 八套全部通过：expanded_character_motion、character_art_prewarm、enemy_atlas_integrity、hero_animation、player_motion_continuity、enemy_lifecycle_regression、enemy_visibility、boss_trial。
- 3711 帧 60Hz 等时对照覆盖全部 **286 个新运行时姿势**，缺失为零。

原帧验证：[main_pixel_preservation.json](../../artifacts/boss_motion_v6/main_pixel_preservation.json)。新登记：[main_registration.json](../../artifacts/boss_motion_v6/main_registration.json)。最终运行日志和播放覆盖见 [验证目录](../../artifacts/boss_motion_v6/)。

最终主线对照视频：[六位 Boss，60Hz 等时播放](../../artifacts/boss_motion_v6/main_playback/all_bosses_comparison.mp4)。共 3711 帧，全部 286 个新运行时姿势出现，缺失为零；四位 Boss 的备用普攻使用两侧相同的标注夹具。此为生产角色的受控播放，不运行 AI、碰撞或伤害。

首次无头调用 `enemy_atlas_integrity` 因其明确要求真实显示环境而报错，已终止该调用并保留在 `main_runtime/`；最终八套回归均使用原生 NVIDIA GL，按原 CI 的完成标记与引擎错误规则判定，日志保存在 `main_native_gl/`。

## 复现

```powershell
npm test
npm run test:character-motion
node tools/run_python_tool.mjs tools/validate_boss_motion_v6_preservation.py --baseline-ref bd11a96f
python -X utf8 tools/run_godot_import.py --engine C:/absolute/Godot_v4.6.1-stable_win64_console.exe --recovery-mode --timeout 600 --log-dir C:/absolute/logs/import
python -X utf8 artifacts/boss_motion_v6/run_main_native_gl.py --engine C:/absolute/Godot_v4.6.1-stable_win64_console.exe
```

Windows 的 Python 启动器默认开启 UTF-8；`res://` 路径和源路径统一使用正斜杠。v5 检查会针对 v6 保存的主线基线重建登记，防止重复运行 v5 时覆盖新帧；撤销 v5 会在修改任何角色之前检查下游 v6。

[初次本地快照报告](20261101_boss_motion_v6_snapshot.md)以及根目录的旧对照视频、`verification.json`、`pixel_preservation.json` 是 `93e2a0c6` 的历史证据；其中 6610 项、481 个旧帧、3329 个帧引用不用于证明最终主线版本。它们保留了早期导入和录制失败记录。

本批验证动作资源和受控播放；自然带伤战斗、手柄体验、音效同步、长期稳定及整体 60FPS 性能仍需独立验收。

原生回归保留退出 warning：WARNING: ObjectDB instances leaked at exit (run with --verbose for details).。未据此宣称长期稳定性完成。
