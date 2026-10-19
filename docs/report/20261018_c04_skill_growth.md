# 技能校习成长说明（C04）

修订方案 C04 要求技能成长有获得练习、并能分支改变打法。数值强化（触及／伤害／持续时间随 `skill_levels` 0–2）本来就在 `selected_skill()` 里，但校习配方文案六技能共用一句空话，练针架也不提示校习方向，玩家看不出「升一级到底换了什么打法」。

## 改动

- `build_catalog.json`：六个技能各写 `growth.level_1`／`level_2`，与运行时公式对齐；`upgrade_*` 配方描述改为引用这两段。
- `world_routes.json`：`seal_practice_plan` 标签追加「校习后…」方向提示。
- `build_system.gd`：`selected_skill()` 暴露 `growth` 与 `next_growth`，供构筑／工匠界面展示下一档打法。
- `seal_acquisition_validation`：成长文案完整性、练针标签、cleave 升档伤／距、bell 契印下 ward 延时不加伤。

## 验证

- `seal_acquisition_validation`：137 项，0 失败。
- `build_system_validation`：78 项通过。
- `tools/audit_economy.py`：income=2840 sinks=1020 share=0.359（本批不加碎钱）。

## 仍待

- 实机构筑页／工匠对话是否醒目展示 `next_growth`（U02／实机检查者）。
- 互斥分支（二选一改打法）若要做，另开批次；本批只把既有线性校习写成可读的打法分叉说明。

## 2026-10-19 审查修复

清除已关闭的 #128／#129 依赖，仅保留本 PR 的成长说明和练针标签改动。守钟架势每级增加 0.05 秒，实际为 0.55／0.60／0.65 秒；`seal_combat` 用正式 Player 分别施放三档并检查真实 guard_timer，避免配置值增长却被运行时截断。
