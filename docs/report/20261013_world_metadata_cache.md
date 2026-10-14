# 持久世界静态元数据复用

日期：2026-10-13。基线为 PR #32 已验收 head `bfce7c709543ed9aba18175b737728bba2f19281`；本项实现于其后独立分支，PR #32 不受修改。

## 后续更正：跨区缓存生命周期

后续检查发现，初版 `world_region_loader.gd` 的 `SESSION_FIELDS` 漏列了六个 `world_shared_metadata_*` 缓存与计数字典。区域字段重置因此会在跨区时清空它们；旧回归只断言值等于初始 `1`，重置后重读也可能得到 `1`，从而漏报问题。本批将六个字段登记为持久 session 状态，并新增跨异步到达、同步回访、取消和回滚的累计 probe/read 连续性断言。修复和验证范围见[World 准备阶段预算报告](20261013_world_prepare_budget.md)。这项更正不追改 PR #33 的历史验证记录；它修正的是其中跨区缓存连续性证据的局限。

## 行为

持久 World 宿主只缓存 `_prepare_region` 会反复读取的只读 JSON：campaign、`data/chapters` 目录中的章节定义、音视 manifest 和物品铭文。当前原有加载集合共有8个文件：三个根 JSON 与章节目录的五个 JSON，按文件字节长度合计254,117字节。进入新区域时，这些文件按规范化路径查缓存；缓存命中仍打开文件检查长度与修改时间，但跳过正文读取和 JSON 解析。正文读取、读取字节数、解析尝试、元数据探测和失败分别计数，探测总数未在本次runner日志中输出，因此不报告具体值。

成功解析的字典会深拷贝后存入缓存，返回给区域逻辑时再深拷贝。合法空 JSON 对象与失败区分：空对象可缓存；缺文件、损坏 JSON 和非字典结果不缓存，后续调用可重试。源长度或修改时间变化会使快照失效；对内容被替换但长度和修改时间都未变化的情况不保证检测。缓存随宿主退出树清理。

只有持久 World 模式使用缓存；非 World 场景继续走原 loader。区域配置、存档、构筑、路线和进度仍在每次旅行时加载及应用。因而此次结果只证明减少重复正文 I/O 与 JSON 解析；没有测量或宣称首区同步准备时间、帧时间、FPS、元数据探测和深拷贝成本改善。

## 验证

- Godot 4.6.1 定向 `world_neighbor_gameplay`：最终源码 6952 checks、0 failures，最终log SHA-256 `57918caea588b60fdae25beb0ba11a2ca95841a077d594d153dbb7163fd1acc0`。验证8个已知路径各正文读取一次、生产源failure为0、parse counter等于读取计数、每项记录正字节数；也断言campaign含6章、章节文件5项、音视事件与铭文非空。跨区旅行和取消后读取/解析/字节快照不变。缓存命中另验证元数据probe增加而正文read不变。本次日志只有VSync warning，无脚本/引擎/ObjectDB错误。
- Fixture 覆盖缺失与损坏 JSON 不缓存、修复后重试成功、合法空对象被缓存、长度/时间可观察变化后刷新、不同规范路径隔离、返回值深拷贝隔离，以及非 World loader 保持未缓存行为。
- Campaign/章节/路由/叙事/升级静态审计通过；Node `npm run check` 与 `git diff --check` 通过。
- 独立 QA 对其余七套邻接回归的冻结生产源码复核通过：`world_async_loading` 424、`world_host` 539、`world_neighbor_gameplay_live` 44、`world_enemy_residency` 55、`world_interaction_residency` 143、`narrative_runtime` 27、`save_product` 23。完整日志无 `ERROR` / `SCRIPT ERROR`；异步加载、交互驻留与叙事运行三套另有未归因 ObjectDB 退出警告，不能归因于本缓存。邻区实时玩法产生的 `gpu_live.json` 属测试波动输出，不属于本提交。

本项属于 W00b2b 的准备数据复用子项，不代表复杂单项分帧、整个准备阶段预算、六区自然连续通关或 W00b2b 完成。
