# 主角普攻刀光：跟随实际剑刃

本批基于 `6dcf727769c2920c362d9c2db6dd8ca5a42d1724`，对应 V04 的普通剑击表现子项。

Pixel VFX Forge 生成六份配方和透明素材：左右横斩、地面上下斩、空中上下斩。运行时从生成素材提取纹理扇区，以角色当前和前一个动作帧的剑根/剑尖建立纹理拖尾；前缘端点与当前剑尖重合，剑柄平移、朝向镜像和 pogo 缩放均使用实际角色变换。动作停在同一帧时，尾迹在 55ms 内淡出；仅有效挥砍的第 2/3 号帧能够生成尾迹，不单独播放一轮月牙动画。

接入现有全局动作特效预算、绝对 Z 层和玩家所有权清理；保持原来的伤害、命中、能量和攻击时序。覆盖普通站立/跑动/空中横斩、上下斩；重击/契印技能继续使用其既有路径。本批不处理这些路径的素材或角色动作补帧，也不代表 V04 整体完成。

验证使用本机 Godot `4.6.stable.official.89cea1439`：刀光专项 **224/0**，近战反馈 **112** 项通过，战斗套件通过，真实输入命中特效 **171/0**。NVIDIA OpenGL Compatibility 实际绘制下，次要特效预算 **52/0**、总体战斗特效预算 **44/0**；角色叠加预览为真实 Godot 绘制、固定 60Hz 手动步进的隔离夹具，不是自然战斗录像。GIF 为 25fps，MP4 保留 60fps，末端追加 0.6 秒静止便于循环查看。

保留的失败和限制：独立工作树资源导入首轮和补缓存后的重试均触发原 **180 秒**超时，未提高上限或将其计作导入通过。`hero_animation` 在候选和上述原始基线各运行一次，均 **101 项、43 项失败**；逐条错误文本完全一致，均为旧校验对 supplement 路径的断言。本批未改该校验，也未将其计为通过。新工作树另有 MetroidvaniaSystem 资源 UID 回退警告；远端完整 CI 待发布后确认。

证据：`artifacts/player_basic_vfx/verification_pr.json`、`hero_baseline_comparison.json`、逐套 `.txt` 日志及 `blade_follow_preview.gif` / `.mp4`。配方和原始输出保存在 `godot/assets/vfx/player_basic_attack/`，重建工具接受独立下载的 Forge 渲染器路径；外部渲染器源码未并入本仓库。

首轮 PR CI 在 JavaScript/结构检查阶段发现本批遗漏：新增 `player_basic_attack_vfx` 默认套件，却未加入 `CompletionContractTests` 的显式计数登记，导致 `191 != 190`。已补登记并新增必含断言，保留原有精确数量、去重和完成标记要求。Windows 使用 `PYTHONUTF8=1` 后，完整 `npm test` 和 `npm run test:campaign` 通过；跨平台完成契约 2 项通过（31 项 POSIX 可执行夹具在 Windows 跳过），分片覆盖 3 项、工作流契约 6 项通过，刀光 224 项和近战 112 项再验证通过。此修复的新提交需独立观察远端 CI；不将首次失败解释为此前的动画基线错误。详见 `artifacts/player_basic_vfx/ci_fix_verification.json`。
