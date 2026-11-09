## 2026-11-09：工房加入永久成长奖励

按 11-09 用户确认的设计调整：20 个能力工房原来只给一条证物记录和 50–75 碎钱，现在每间再加一片永久容量碎片。

- 下劈、钟壳格挡、灯影相位、王冠共鸣这四种能力各有 3 间工房，共 12 间给“心结碎片”。四片编成一个心结，最大生命 +1，共 +3。
- 冲刺、攀壁、回声钩索、双线跃这四种能力各有 2 间工房，共 8 间给“纺锤碎片”。四段合成一个能量纺锤，绯线上限 +20，共 +40。
- 碎片放在领奖台上原来两件奖励的正中间，碎钱奖励保留，经济审计不变。旧存档里已领过奖的工房回访时，碎片仍在原地可以拾取。
- 规则：`build_catalog.json` 的永久成长项支持 `per`，`build_system.sync_progress` 只按凑齐的整套计入。拾取时提示进度（“心结碎片 2 / 4”），集满时提示“心结编成 · 最大生命 +1”。
- 生成器 `tools/build_world_upgrade.py` 重新生成 `world_routes.json`，两次生成结果逐字节一致。校验：
  - `validate_world_upgrade`、`workshop_layout_contract` 改为每间三件奖励、恰好一片碎片；
  - `permanent_capacity` 改为碎片按整套计入。
- 测试：`world_upgrade`（609 项）、`validate_world_upgrade`（11647 项）、`test_workshop_layout_contract`、`validate_world_routes`、`permanent_capacity`（含世界拾取与重启）、`ch06_workshop_experience`、`artisan_growth` 通过。
