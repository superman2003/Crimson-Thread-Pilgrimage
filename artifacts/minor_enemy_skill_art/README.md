# 小怪技能材质：运行验证与原生截图

2026-10-23，Godot 4.6 stable，NVIDIA GeForce RTX 5060，OpenGL 3.3 Compatibility。使用生产 `enemy_actor.gd`、`enemy_attack_effect.gd` 和实际种族战斗档案创建角色，覆盖六章 40 种普通敌人的 80 招基础攻击与 10 招精英攻击。

## 验证结果

- `minor_enemy_skill_art`：**5252 项检查，0 失败**，包含全部 90 招、42 组新增生效材质，以及 40 招近战的双朝向行为验证。
- 近战验证实际执行前摇、生效和身体位移：前摇不伤人，近身命中，远处目标不受伤，同一击不重复伤害，不发射弹体／光束／地波；蜡枪仅保留原有明确配置的危险拖尾池。
- 其余 13 套原生 GL 回归全部通过：可见性、战术角色、AI、独立效果生命周期、敌人生命周期、战斗视觉预算、Boss 材质、主角格挡／缝补、战斗、世界敌人驻留、启动预算及角色资源预热。次级装饰预算由 `combat_visual_budget` 内部执行，不单独启动它的 RefCounted 辅助脚本。
- `npm test`、40 张源图／414 格检查、提示词清单检查及图集重建对照通过。资源恢复后完成两遍严格导入，均无引擎错误。

日志、每个套件的退出码和完成标记在 [validation_logs/](validation_logs/)，汇总、源文件哈希与导入情况见 [validation.json](validation.json)。本机第一次无图形后端导入在字体导入阶段发生引擎访问异常；使用原生 GL 完成资源导入后，两遍严格导入与全部运行回归通过。保留该首次失败日志，未将其登记为通过。

## 画面范围

共 **166 张原生截图**，包含每种敌人的预警、生效与清理后状态；10 种重点样本额外覆盖前摇初／中／末及三个生效采样，另有蜡枪拖尾、管弹落地和旗手治疗支援。左栏向右、暗背景；右栏向左、亮背景。图库设置了与正常 AI 朝向相同的精灵翻转，武器动作和特效方向一致。

这些是停止自动战斗时钟后逐招采样的生产渲染画廊，用于检查材质、范围、朝向与清理；不是完整玩家实战录像。

- 黑曜枪兵：[预警](obsidian_spearman_warning_1.webp)、[生效](obsidian_spearman_active_1.webp)。
- 齿轮卫兵：[预警](gear_sentinel_warning_1.webp)、[生效](gear_sentinel_active_1.webp)。
- 灰旗小鬼：[连刺／退刺](ash_banner_imp_active_1.webp)、[支援引导](ash_banner_imp_extra_warning.webp)、[治疗完成](ash_banner_imp_extra_active.webp)。
- 苔虫：[咬击／扑身](moss_larva_active_1.webp)。
- 纸页剑客：[虚晃／连刺](page_duelist_active_1.webp)。
- 蜡枪兵：[冲刺](wax_lancer_active_1.webp)、[拖尾预警](wax_lancer_extra_warning.webp)、[拖尾生效](wax_lancer_extra_active.webp)。
- 管弹投手：[预警](pipe_thrower_warning_1.webp)、[生效](pipe_thrower_active_1.webp)、[落地转换预警](pipe_thrower_extra_warning.webp)。
- 铜蛾：[俯冲](bronze_moth_active_1.webp)。

## 复现

源图、实际提示词与测量记录见 [素材目录](../../art_requests/minor_enemy_skills_v4/README.md)。Linux 软件 GL 可运行：

```sh
python tools/run_godot_regressions.py --software-gl --suite minor_enemy_skill_art --suite enemy_effect_lifetime --suite combat_visual_budget --suite enemy_visibility --suite enemy_tactical_roles --suite enemy_ai_behavior --suite boss_skill_art
```

原生截图：设置 `MINOR_ENEMY_SKILL_CAPTURE_DIR` 为输出目录，运行 `godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://../tools/capture_minor_enemy_skill_art.gd`。可选 `MINOR_ENEMY_SKILL_CAPTURE_KIND` 限定一个种族。CI 同时检查源图哈希、切格记录和图集重建，并重复运行逐招及相关回归。
