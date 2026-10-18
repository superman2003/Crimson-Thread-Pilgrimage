# W04 补丁：map_room_overrides 不再抹掉可见线索／安全离开

实机八袋回走：接近房／隐藏房在章节 JSON 里已有「可见线索：…」「安全离开：…」，但 `world_routes.map_room_overrides` 整段覆盖 `guide`（检修工房文案），World 里玩家看不到 W04 线索。

## 改动

- 六个被覆盖的房间把章节里的线索／离场句并进 override `guide`：`belfry_top`、`tide_listening_cell`、`mezz_reading_ledges`、`secret_nook`、`beeswax_nook`、`pilgrim_camp`。
- `world_routes._preserve_hidden_route_guide`：合并时若 override 缺标记则从章节原稿补回，防再生器再抹掉。
- `hidden_route_plan_validation`：模拟 override 合并后仍须含标记（98 项、0 失败）。

## 请实机检查者

按 `hidden_route_plan` 八袋再走一遍，确认接近房指南含「可见线索」、隐藏房含「安全离开」（含有检修入口提示的房间）。
