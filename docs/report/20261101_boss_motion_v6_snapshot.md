# 六位 Boss 的 288 个新动作姿势

> 历史快照：以下结果针对初次提交 93e2a0c6 的旧本地 v5 基线。正式 PR 已保留最新 main 的桥接、站姿回待机及色阶校准，最终结果见 [主线适配报告](20261101_boss_motion_v6.md)。

用户反馈 Boss 衔接仍像跳帧，v5 的两帧收招过渡不足以覆盖现有动作内部的大姿态间隔。本批对正式流程的六位 Boss 各补 48 个姿势，共 288 个，全部来自内置 image_gen 的新画稿，并接入正式 `motion_manifest.json` 和 `motion_runtime.png`。

各 Boss 的动画资源按同一范围补足，保留各自造型和招式：

- 待机 4→8 帧，包含首尾接点；走路 8→16 帧，包含跨步和循环接点。
- 普通、重击、施法、二阶段攻击的前摇各 4→7 帧，出招各 4→7 帧。
- 通用收招按原始长度由 5–7→11–13 帧；三种特殊攻击的专属收招由 7–9→15–17 帧，包含专属过渡接点和共享通用收招。

当前四位 Boss 的实际 AI 只选择 heavy／cast／phase；它们的通用普攻动画属于备用状态。本批 288 个新姿势中，264 个由当前招式或循环使用，另 24 个补齐备用普攻。预览对备用普攻单独标注，并使用两侧相同的 0.48／0.36／0.54 秒夹具；未给 AI 新增招式。

没有用复制帧、像素混合、补间变形、慢放或延长战斗窗口冒充新画。原有 481 个 Boss 帧引用的顺序、可见 RGBA 和游戏内定位全部保留。新增姿势按对应端点的 alpha 面积和水平锚点注册，脚底遵循原图集规则。长武器有时跨越逻辑格子边界，打包器按完整连通轮廓提取，保留完整武器和边缘抗锯齿，不按格子硬裁。

源文件和逐张实际提示词保存于 [boss_motion_v6/incoming](../../art_requests/boss_motion_v6/incoming/)，48 张源图、288 个新姿势逐项登记在 [交付清单](../../art_requests/boss_motion_v6/incoming/delivery_manifest.json)。最初 24 格长图的末段动作语义不正确，未纳入交付，后续改用每张六个端点接点。

验证结果：

- `npm run test:character-motion` 通过：包含原小怪素材登记、v5 登记、v6 登记、全部 71 角色图集的逐像素重建检查及主角原有动作检查。新增批次与既有门禁共同保留。
- Godot 4.6.1，`expanded_character_motion` 无头与 NVIDIA RTX 5060 真实 Compatibility 渲染均为 **6610 项、0 失败**，遍历 71 角色、3329 个运行时帧引用。包含六位 Boss 三种特殊招式的左右朝向、逐帧播放、重启、原恢复窗口和待机返回；另检查新帧数量及旧注册顺序。
- `validate_boss_motion_v6_preservation.py` 以改造前归档逐像素核对 **481 个原帧引用**，其可见 RGBA 和游戏内定位全部一致。
- `character_art_prewarm`、`enemy_lifecycle_regression`、`enemy_visibility`、`boss_trial` 通过。预热与 Boss 试炼退出时仍有 ObjectDB warning，未据此宣称长期稳定性完成。
- `npm test` 通过；原二十 Boss 素材检查在同一工作批次已通过，其目录此后没有变化。
- Godot 4.6.1 以严格 `--recovery-mode` 完成两轮资源导入，零引擎错误；该模式不验证编辑器插件。v5 批次普通编辑器导入的退出泄漏诊断继续保留。
- 以真实 GPU 在 60Hz 固定时钟取样，共录制 3711 帧、六段前后对照。当前实际招式读取正式 command 时长，备用状态使用单独标注的等时夹具，视频编码为 60fps，无补帧／变速。片段是固定取景的正式角色播放检查，未运行 AI、移动碰撞和伤害结算，不能计作自然通关或 60FPS 性能证明。

本机旧 Godot 4.6 的首轮录制在第 65 帧后停滞，已终止该录制，并保留历史诊断。按项目既定 4.6.1 重导入后完整录制、验证通过；未将一次环境差异宣称为已证明的引擎根因。早期未重导入新图集的试拍使用了旧导入纹理，也未计为最终画面。

[六位 Boss 的完整前后播放对比](../../artifacts/boss_motion_v6/all_bosses_comparison.mp4)（左：补帧前；右：补帧后）。各角色独立片段、逐帧取样信息、源登记、像素保持结果和日志见 [验证目录](../../artifacts/boss_motion_v6/)。中间 JPG 取样位于该目录的 `frames/`，未纳入 Git。

复现：

```powershell
npm run test:character-motion
python -X utf8 tools/validate_boss_motion_v6_preservation.py --baseline-dir tmp/boss_motion_v6_baseline
godot --path godot --rendering-method gl_compatibility --fixed-fps 60 --script res://scripts/expanded_character_motion_validation.gd
godot --path godot --rendering-method gl_compatibility --fixed-fps 60 --script res://../tools/capture_boss_motion_v6.gd -- --capture-output=C:/absolute/output --baseline=C:/absolute/pre-v6-baseline
```

以上运行时检查使用 Godot 4.6.1。Windows 的 npm Python 启动器默认开启 UTF-8，避免含中文的数据和源记录按 GBK 读取失败。

本批完成六位正式 Boss 的补帧与播放接入。战斗中的视觉顺滑仍可依据对照片段继续打磨；AI 转向、位移、音效同步、真实带伤战斗与长期稳定不由本批单独验收。
