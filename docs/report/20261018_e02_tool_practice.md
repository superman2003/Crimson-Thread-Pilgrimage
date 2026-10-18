# 战具练习与遭遇提示（E02）

修订方案 E02 要求主动装备有遭遇用途、补给经济与保存。技能侧已有 `seal_practice_plan` 与练针架；战具此前只有携带次数与补给，缺少安全练习架与合适遭遇引导。本批补齐四件主战具的练习计划与遭遇提示，不改碎钱收支（收入仍 2570，消费占比 35.0%）。

## 问题

铜铃投罐／绊线钉／盐雾瓶／回响诱铃取得后，玩家只能在实战中试错；工房旁没有与契印练针架并列的战具练习目标，房间引导也很少点明“何处适合用哪件战具”。

## 设计（最小、贴既有系统）

- 镜像 `seal_practice_plan`：新增 `tool_practice_plan`（四件主战具各一架，挂在已有工房，`safe`、伤害 0）。
- 盐雾瓶练习架带零伤远程预表（`ranged_dummy`），方便理解“挡索敌、不挡已飞弹体”。
- 新增 `tool_encounter_plan`：把合适遭遇写成短注，并写入对应房间 `guide`（苔落走廊／立管井口／雨栅长堤／根须南廊）。
- 练习架复用 `seal_training_target.gd`。`_ready` 会写入 `seal_training_target`，生成后用 `remove_meta` 去掉该键并改标 `tool_training_target`，这样 `has_meta` 也不会把战具架算进技能练习。

## 改动

- `godot/data/world_routes.json`：`tool_practice_plan` ×4、`tool_encounter_plan` ×4。
- `demo_ch01`／`demo_ch02`／`demo_ch04`：房间指南追加「战具提示」。
- `main_level.gd`：`_spawn_tool_practice_targets` 与区域几何任务挂接。
- `seal_acquisition_validation`／`seal_acceptance_validation`：计划完整性、房间存在、指南含注、第一章真实架位与地板支撑。

## 验证

- `seal_acquisition_validation`：100 项，0 失败。
- `seal_acceptance_validation`：42 项，0 失败（含第一章 shard 练习架与技能练习架并存，且战具架不再带 `seal_training_target` 键）。
- `tools/audit_economy.py`：income=2570 sinks=900 share=0.35。

## 仍待验收

- 实机手感与补给节奏（T04／实机检查者）。
- 材料更多用途（E04）、技能成长分支（C04）另批。
