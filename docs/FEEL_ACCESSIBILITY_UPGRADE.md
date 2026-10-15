# 全局打击反馈无障碍续接

日期：2026-10-15；基线：main `8b9dff4ae905e559d7378dadd5cdffa5caeacea6`。
本批推进 U06 / V04 的关闭残留子项。文件与 CH05 灯影相位工房、地图图钉及并行存档工作隔离。

## 行为与设计

现有玩家会按设置阻止后续闪光，并按镜头震动滑块缩放新 trauma；
但 FeelKit 中已经创建的全屏闪光/黑帧和累计 trauma 不会随关闭设置立即消失。

- `pilgrimage_interface.gd` 应用既有设置时，同时通知 FeelKit。存储字段、默认值和存档格式沿用。
- `feel_kit.gd` 在全局入口拦截关闭后的闪光/黑帧与新 trauma；关闭时立即清空 trauma、复原镜头平移/旋转，并先从树中移除现有效果再延迟释放。
- 镜头替换时复原旧镜头并清空累计震屏；同一镜头的重复注册不清空正常震屏。衰减结束也清除只有旋转而没有偏移的残留。
- 玩家已经按滑块缩放 trauma，全局服务仅判断震动是否关闭，避免重复缩放。重新开启仅接受新效果，不恢复旧效果。
- hitstop、伤害判定、纹章玩法效果和手柄震动不在本批修改范围。既有“受击闪光”选项覆盖 FeelKit 闪帧，未宣称关闭游戏全部动画/粒子。

## 自动验证

新增 `godot/scripts/feel_accessibility_validation.gd`，由现有
`ui_build_accessibility_validation.gd` 调用；不另改默认套件注册或并行任务入口。
Godot 4.6.1 / Mesa llvmpipe 真实 OpenGL 下新增 **17 项、0 失败**：
累计震屏、活动闪帧与黑帧的立即清理、关闭后拒绝新请求、重新开启、正常计时释放、
同一镜头重注册、镜头替换/退休、纯旋转清理，以及实际 UI → autoload → ConfigFile 重载链路。
无显示模式同样通过 17 项，但不创建闪帧，不能代替真实 GL 验证。

本地共 8 套不同的相关真实 GL 回归通过：
`ui_build_accessibility`、`input_settings_regression`（32）、`camera_focus`、
`seal_presentation`（123）、`player_state_cleanup`（9）、`ui_redesign`、
`player_upgrade_regression`（46）、`seal_combat`（70）。
另外 `npm test`、`npm run test:campaign`、两轮恢复模式资源导入及差异空白检查通过。

反向验证：仅移除立即取消逻辑、保留后续请求开关，新增专项检测到 9 处失败；随后恢复实现。
首次测试命令遗漏 `--software-gl`，在 headless 下触发了原测试的 GL 前提检查；
已修正调用并让专项显式记录 `real_gl`，最终真实 GL 和 headless 分别通过，未将首次失败计为通过。
本地日志保留在工作区的 `feel-logs/`；远端完整 CI 必须按 PR 最终提交独立判定。

## 验收边界

`camera_focus` 与 `ui_redesign` 出现既有 ObjectDB 退出警告，新增专项未出现；未据此声明长期内存稳定。
本批为服务节点和真实 GL 下的自动化生命周期验收，没有人工手柄听感/舒适度验证，
没有自然六区通关、整包发布或 U06/V04 全部完成结论。章节路线、地图、奖励和存档业务不改。
