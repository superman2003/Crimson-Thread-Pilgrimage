# V01：铸雨渠两位 NPC 不再被平台横穿身体

2026-11-03。按数据计算每个 NPC 待机图的绘制范围与实心平台的重叠，六区共 5 位 NPC 的身体被 22–26px 厚的平台横穿（站立位置头顶 66–110px 处横着一块台子，玩家在那里也站不下）：

| 地区 | NPC | 平台 |
|---|---|---|
| 铸雨渠 | 锈泵修女 `npc_sluice_nun` | `pw01` |
| 铸雨渠 | 半沉工头 `npc_drowned_foreman` | `sv_lip` |
| 苔钟庭 | 升台绘图师 `npc_gear_cartographer` | `rain_observation_ledge` |
| 苔钟庭 | 后门司铃人 `npc_backdoor_sacristan` | `sw01` |
| 苔钟庭 | 回廊斥候 `npc_runback_scout` | `pbs_votive_shelf` |

## 改动

铸雨渠两位挪到同一地面的开阔处：修女 2570→2770（`hub_floor_w` 上，离工房入口 2870 仍有 100px），工头 3950→4020（`sv_floor` 上，离工房入口 4240 有 220px）。软件 GL 截图核对两处画面。

`ch02_demo` 新增：铸雨渠四位 NPC 站立身形（脚下 8–110px、宽 80px）不与任何平台相交；旧坐标下准确失败于 `pw01`、`sv_lip`，新坐标通过。`rain_foundry_experience`、`silent_crown_experience`（工头仍是不受敌人攻击的安全交谈点）、`npm test`、`test:campaign` 通过。

## 边界

苔钟庭三位的坐标由地图生成器（`tools/generate_ch01_*.py`）产出，手改数据会与生成器漂移，留待调整生成器时处理；其中绘图师截图显示台子只贴着头部后方，影响较轻。
