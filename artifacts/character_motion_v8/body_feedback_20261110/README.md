# 保持原尺寸的受击反馈

Godot 4.6.1，Windows 原生 Compatibility 渲染器，固定 60 Hz 的隔离诊断。

`hit-feedback.mp4` 用正式 `take_hit()` 展示苔幼虫、蜡蜂、第一位 Boss 的命中前、全身白闪、击退和回色；`hit-feedback-samples.jpg` 是原生录像取样。`events.json` 记录身体缩放、当前姿势、白闪强度和位移。三个角色的缩放全程恒定，怪物受击时不重启或替换当前姿态。

本轮实际 GPU 验证 611 项、零失败，覆盖全部 46 个角色：命中瞬间的图像与缩放保持、闪白与淡回原色、致命命中不缩小、Boss 阶段暂停时回色、击退方向及墙体阻挡。日志见 `validation/`。

白闪约 120ms；击退使用受碰撞约束的指数衰减位移。录像中普通怪后退约 28px、Boss 约 12px。不同 AI 的霸体、连续受击反应与边界会影响实际距离；这个录像不表示自然通关、所有战斗状态或性能测试。

重现（先导入资源）：

```powershell
python -X utf8 tools/capture_combat_pose_review.py --hit-feedback --engine <Godot-4.6.1.exe> --output output/character_motion_v8/hit-feedback-review
```
