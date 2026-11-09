# 补帧前后原生对照

Godot 4.6.1，Windows 原生 Compatibility 渲染器；相同种子、相同升级后 AI、固定 60 Hz 模拟、固定靶、无声诊断。左侧只切回保留的 `combat_motion_v7_manifest.json` / `boss_behavior_manifest.json`，右侧使用 `motion_v8_manifest.json`。并未替换战斗脚本。

- `bosses_v7_v8_comparison.mp4`：六位正式 Boss，两侧各 2,160 帧。
- `sample_v7_v8_comparison.mp4`：苔幼虫、铜蛾及前两位 Boss，两侧各 1,440 帧。
- `boss_comparison_samples.jpg` / `sample_comparison_samples.jpg`：录像取样，完整播放以视频为准。
- `*_timeline_comparison.json`：逐帧时序核对，两组的状态／意图／动画名称差异均为 0，最大位置差为 0 像素；新姿势进度与旧姿势进度两倍关系的最大浮点误差约 0.00000167 帧。
- `before_events.json.gz` / `after_events.json.gz` 及 `sample_*_events.json.gz`：完整事件序列，包含动作帧索引和帧内进度。gzip 使用固定时间戳。
- `bosses_*.log` / `sample_*.log`：原生捕获完成记录。

重现（Windows，先完成资源导入）：

```powershell
python -X utf8 tools/capture_combat_pose_review.py --engine <Godot-4.6.1.exe> --all-bosses --baseline-v7 --output output/character_motion_v8/native-boss-comparison
python -X utf8 tools/capture_combat_pose_review.py --engine <Godot-4.6.1.exe> --baseline-v7 --output output/character_motion_v8/native-sample-comparison
```

捕获器在独立隐藏桌面运行，使用临时存档目录，完成后自动比较事件。它验证模拟时序和身体动画替换，不代表自然通关、所有动作的主观连续性验收，或稳定 60 FPS 的性能基准。

最终素材和录像使用生产基线 `ff8ab652b224523afbf8789a7b5ad98a676eb389`。`*_sample_frames.json` 标明取样位置，优先取新增奇数帧；视频保留完整序列。

`validation/` 保存全量构建、可重复构建、导入、npm 和原生回归日志。全角色翻倍验证：13,516 项、零失败，46 个角色，5,439 → 10,878 帧。GPU 预热同步纹理加载数为 0；扩展角色播放验证 15,252 项、零失败；旧图集探针 3,325 项、零失败。

退出诊断：Boss 试炼留下 ObjectDB 警告；首次 GPU 图集探针也出现过退出警告，随后禁用 v8 和启用 v8 的 verbose 对照均未复现。保留首次日志和两次补跑日志，未将“断言通过”表述为“所有运行均零退出警告”。
