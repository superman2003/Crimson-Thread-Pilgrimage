# V01：五位 NPC 不再被平台横穿身体

2026-11-03。按数据计算每个 NPC 待机图的绘制范围与实心平台的重叠，六区共 5 位 NPC 的身体被 22–26px 厚的平台横穿（站立位置头顶 66–110px 处横着一块台子，玩家在那里也站不下）：

| 地区 | NPC | 平台 |
|---|---|---|
| 铸雨渠 | 锈泵修女 `npc_sluice_nun` | `pw01` |
| 铸雨渠 | 半沉工头 `npc_drowned_foreman` | `sv_lip` |
| 苔钟庭 | 升台绘图师 `npc_gear_cartographer` | `rain_observation_ledge` |
| 苔钟庭 | 后门司铃人 `npc_backdoor_sacristan` | `sw01` |
| 苔钟庭 | 回廊斥候 `npc_runback_scout` | `pbs_votive_shelf` |

## 改动

五位都挪到同一块地面的开阔处：

- 铸雨渠：修女 2570→2770（`hub_floor_w`，离工房入口 2870 仍 100px），工头 3950→4020（`sv_floor`，离工房入口 4240 有 220px）；软件 GL 截图核对两处画面。
- 苔钟庭：绘图师 6020→5950（`ro_floor`，避开头顶观察台），司铃人 2210→2315（`sl_floor` 上两块平台之间的空档，离捷径拉杆 145px），斥候 5540→5320（`pbs_floor`，避开供台，离钟龛 100px）。苔钟庭坐标最早由 `tools/generate_ch01_*.py` 一次性生成，现已无测试或流程重新生成，直接改数据。

`ch02_demo` 新增铸雨渠四位、`all_chapters_demo` 新增六区全部 NPC 的检查：站立身形（脚下 8–110px、宽 80px）不与任何平台相交；旧坐标准确失败（苔钟庭 3 处、铸雨渠 2 处）。`rain_foundry_experience`、`silent_crown_experience`（工头仍是安全交谈点）、`cartography`、`world_host`、`first_court_experience`、`chinese_story`、`demo`、`ch01_room_reconstruction`、`chapter_route_regression`、`npm test`、`test:campaign` 通过；用 #514 的 `rest_point_safety` 与 #508 的 `interaction_reach` 对新坐标复查，未出现新问题。
