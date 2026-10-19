# U02：构筑页下一档校习醒目展示与工匠入口

实机反馈 #130／#131：`next_growth` 只埋在校习配方长文案里；`craft_*` 强化／制作页要求钟龛，靠近雨铸匠／织线学徒／蜂蜡商人仍锁页。本批叠在 #132（W04）尖上。

## 设计

- **下一档校习**：`get_snapshot().skills[].next_growth` 始终带下一档文案；技能详情与 `upgrade_*` 详情顶部加「【下一档校习】」横幅，不再只靠配方 description。
- **工匠入口**：`_near_workstation(crafting)` 白名单含 `npc_rain_smith_liu`／`npc_threadsmith_apprentice`／`npc_beeswax_vendor`／`npc_salt_librarian_ye`（盐页书签 `craft_spur`）；新增 `is_near_build_station()`＝钟龛或工匠。UI `_is_at_build_workstation` 优先问此方法，靠近工匠即可开全页强化／制作；失败文案与行装锁页提示同步点名四类工匠。
- **文案抛光**：六个 `upgrade_*` description 把「。 校习二／每次」改成换行，避免双空格糊成一行。

## 改动

- `main_level.gd`：工匠白名单＋盐白司书；`is_near_build_station`；制作失败原因。
- `build_system.gd`：快照技能行带 `next_growth`。
- `pilgrimage_interface.gd`：工匠算工作台；详情【下一档校习】；锁页提示。
- `build_catalog.json`：校习 description 换行。
- `build_system_validation`／`ui_build_accessibility_validation`：覆盖 next_growth 与详情横幅。

## 验证

- `build_system_validation`：98 项通过。
- `ui_build_accessibility_validation`：failures=0。
- `seal_acquisition_validation`：137 项、0 失败。
- `audit_economy`：income=2570 sinks=900 share=0.35。

## 仍待

- N03–N05 与其它 ledger 项（本批按优先级暂停后恢复）。
- 实机检查者确认四工匠面对面开页与盐白司书 `craft_spur`。

## 2026-10-19 审查修复

仅保留 UI／成长快照改动，基于重建后的材料配方与守钟成长分支；不带入已关闭的 #128／#129／#132。经济为 2840 收入、1020 一次性消费。
