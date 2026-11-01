# Boss 逐招材质接入：原生 GPU 画面

2026-10-23，Godot 4.6 stable、OpenGL 3.3 Compatibility、NVIDIA GeForce RTX 5060。所有画面来自 `tools/capture_boss_skill_art.gd`，通过实际 `enemy_actor`／`enemy_attack_effect` 生产脚本渲染，未用图片拼贴冒充运行效果。

每张四行对应该 Boss 的四招，左列向右、暗背景，右列向左、亮背景。`warning_0/1/2` 为前摇 5%／50%／98%；`active_0/1/2/3` 为近战及危险物的四个生效采样，独立弹体／地波展示至释放后 0.6 秒；`cleared` 已清理特效，保留 Boss；`phase` 为半血相变蓄势。共 54 张。相变与攻击素材读取已有计时，画廊只为采样停住计时；这里不是完整玩家实战录像。

## 预警／生效画面

- 苔钟守母：[预警](rust_crown_guardian_warning_1.webp)、[生效](rust_crown_guardian_active_2.webp)、[相变](rust_crown_guardian_phase.webp)。
- 绯线执剪者：[预警](sunken_hammer_smith_warning_1.webp)、[生效](sunken_hammer_smith_active_2.webp)、[相变](sunken_hammer_smith_phase.webp)。
- 灰冠螳将：[预警](saltwhite_contract_judge_warning_1.webp)、[生效](saltwhite_contract_judge_active_2.webp)、[相变](saltwhite_contract_judge_phase.webp)。
- 铜根主教：[预警](broken_string_gardener_warning_1.webp)、[生效](broken_string_gardener_active_2.webp)、[相变](broken_string_gardener_phase.webp)。
- 镜池新娘：[预警](silent_pilgrim_commander_warning_1.webp)、[生效](silent_pilgrim_commander_active_2.webp)、[相变](silent_pilgrim_commander_phase.webp)。
- 百钥看门人：[预警](silent_crown_core_warning_1.webp)、[生效](silent_crown_core_active_2.webp)、[相变](silent_crown_core_phase.webp)。

## 验证结果

- `boss_skill_art`：24 招、12 套新增生效图，**813 项检查，0 失败**。两种朝向均从生产攻击入口验证，包含未伤人的前摇、逐危险物 ID 绑定、真实 UI 暂停、随位移跟随、释放切换、取消、相变、墙体 7 像素截断、其余 12 招的实际材质解析与测试场音频清理。
- 原生 GL：`enemy_effect_lifetime` 通过；其中弹体 300 项、地面陷阱 375 项、地波／根刺 609 项、光束 441 项像素及行为检查均为 0 失败，另有 46 项效果生命周期检查。
- 原生 GL：`combat_visual_budget` 44 项、`secondary_visual_budget` 50 项、`enemy_visibility` 641 项，均 0 失败。
- `enemy_lifecycle_regression`、`boss_trial`、`combat`、`world_startup_budget`、`character_art_prewarm` 通过。`boss_trial` 在既有快速退出流程仍报告 ObjectDB 警告；本次新增套件已执行音频退休清理，严格检查无引擎错误。
- `npm test` 通过（Windows 使用 `PYTHONUTF8=1`）；52 张 v2 清单与交付记录校验通过，运行时六图集重建对照通过。资源完成两次严格导入，均无错误。

本地原生 GPU 日志与源图核验摘要见 [validation.json](validation.json)。CI 在 Linux 软件 GL 下重复执行逐招、像素、生命周期、碰撞和预算套件。

## 复现

设置 `BOSS_SKILL_CAPTURE_DIR` 指向输出目录，在具有真实图形后端的环境运行：`godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://../tools/capture_boss_skill_art.gd`。CI 可使用 `python tools/run_godot_regressions.py --software-gl --suite boss_skill_art --suite enemy_effect_lifetime --suite combat_visual_budget --suite enemy_visibility`；Windows 原生图形后端可直接运行各 `res://scripts/*_validation.gd`，需同时检查进程退出码、完成标记和引擎错误。
