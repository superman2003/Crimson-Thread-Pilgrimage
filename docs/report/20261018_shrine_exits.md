# 隐藏钟龛出口：连续移动与完整路线重放

原审计把横向最多 240 像素的瞬移当成可达起跳点，无法支持安全返回结论。本次移除这一采样漏洞，并重新生成全部八座危险钟龛的证据。

## 方法

- 只从钟龛或已经物理到达的落点扩展；横向距离必须通过真实行走完成。
- 每条边结束时等待角色落地并停稳，避免搜索节点与路线重放的惯性不同。
- 禁用八项永久能力，并在区域构建时阻止能力拾取，避免路过拾取物自动开能力门；拒绝复活、跨区等非连续位移。
- 只有落在本房间矩形之外、且属于非隐藏房间才算离开。
- 找到路线后，从原钟龛起点连续重放整条输入序列；重放成功才写 `replay_verified: true`。
- 搜索预算耗尽只表示未验证，不等同于证明卡死。

## 重新验证结果

Godot 4.6.1，固定 60 Hz：八座全部通过连续路线重放。`artifacts/shrine_exits/report.json` 保存每一步输入、重放落点和起终点。

- `demo_ch01_moss_bell_court`／`save_hidden_upper_respite` → `belfry_mid`：1 段输入，重放成功。
- `demo_ch02_rain_foundry_canal`／`save_ch02_forge` → `preboss_causeway`：1 段输入，重放成功。
- `demo_ch02_rain_foundry_canal`／`save_ch02_tide` → `undercanal`：7 段输入，重放成功。
- `demo_ch03_saltwhite_archive`／`save_hidden_upper_respite` → `mezz_reading_ledges`：2 段输入，重放成功。
- `demo_ch04_broken_string_greenhouse`／`save_hidden_upper_respite` → `vine_ascent`：1 段输入，重放成功。
- `demo_ch05_obsidian_pilgrim_road`／`save_hidden_upper_respite` → `banner_bridge`：1 段输入，重放成功。
- `demo_ch05_obsidian_pilgrim_road`／`save_ch05_lower_loop` → `ravine_gate`：3 段输入，重放成功。
- `demo_ch06_silent_crown_core`／`save_ch06_lower_loop` → `throne_approach`：1 段输入，重放成功。

## 自动回归

`shrine_exit_probe` 使用正式 Player 覆盖高墙封闭、开放出口与跨缺口跳跃；`shrine_exit_routes` 在正式 World 重放上述八条证书并核对当前危险钟龛覆盖率。两套均进入默认 CI；完整搜索作为按需审计工具。

重新发现路线：`godot --headless --fixed-fps 60 --path godot --script res://../tools/probe_shrine_exits.gd`。可用 `-- --region=ch02 --shrine=save_ch02_tide` 单独审计一座，结果写入 `report_filtered.json`。

本项验证无能力移动出口，不代表敌人伤害、隐藏线索可见性或终局支路已经完成体验验收。
