# 隐藏支路线索与安全出口（W04）

修订方案 W04 要求隐藏探索有可观察线索、安全出口与可选奖励。第六区钟舌库已有 NPC 路线答与 `ch06_hidden_route_validation`；其余章节多只有「藏着存档」一句，缺接近线索、离场说明或可选奖励。

## 设计

- 新增 `world_routes.hidden_route_plan`（8 条：六区各至少一袋，第六章含苔庭回声＋钟舌库）。
- 接近房指南统一加「可见线索：…」；隐藏房加「安全离开：…」。
- 补缺可选奖励（仅地区材料／冠下碎片，**不发碎钱**）：顶阁暗格苔壳、假死石穴苔壳、听潮湿壳、苔庭回声碎片；其余沿用既有 `col_branch_*`。
- 数据门禁 `hidden_route_plan_validation.gd`（无头、不进 World）。

## 验证

- `hidden_route_plan_validation`：90 项，0 失败。线索／离场强制「可见线索」「安全离开」；奖励 `platform_id` 须落在章节平台上。套件已挂进 `run_godot_regressions` 与 focused workflow。
- `audit_economy`：income=2570 sinks=900 share=0.35。

## 仍待

- 实机走通各袋手感（T04／实机检查者）。
- 钟舌库西向折返仍仅 NPC 提示（既有文档边界）。
