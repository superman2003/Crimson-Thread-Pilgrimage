# World 准备阶段预算化

日期：2026-10-13。基线为 PR #33 head `84b173627ad2f7cf58d010bf226524b06f92207a`。本项是 W00b2b 的一个准备阶段子里程碑；W00b2b 继续标记为部分完成。

## 行为

World 区域准备拆成有序 job。同步初始化和异步 World 切区共用同一份 job 计划；异步路径最多每帧准入8项，并在已执行至少一项后以2ms预算判断是否准入下一项。每个 job 开始后不会被抢占，因此一个 JSON 解析、深拷贝或 Godot 引擎调用自身可能超过2ms；2ms 是准入预算，不是单帧硬上限。切区指标记录 job 总数及游标、批次数、每批与单项工作时间和准备墙钟时间。

动态区域配置、章节叙事、共享静态元数据、背包与装备、构筑状态、音频设置、World 目录和常驻服务初始化按计划分项执行。World 物品目录先写入暂存字典，目录子计划的所有区域条目装配完成后，一次性替换 live 目录；后续仍有其它区域准备 jobs。目录条目尚在构建时取消会丢弃未提交 staging。区域进度与存档仍只在 `_publish_region` 的既有提交阶段发布，该阶段没有 yield。同步与异步路径使用相同 job 计划，测试比较两种路径的区域摘要。

PR #33 新增的 metadata cache、read、probe、byte、parse 与 failure 字典已作为持久 World session 字段保留，区域状态重置时不会清空；宿主退出时仍清理缓存。

## 边界

首次启动及同步 preflight 未变为跨帧工作。章节目录的文件名枚举仍在同步计划阶段完成。单个不可抢占操作可以超出2ms，因此本项只限制每批准入数量和开始下一项的时机，不保证每帧绝不超时，也未证明FPS、帧时间或启动时间改善。该工作不覆盖Boss战斗持续推进、长期自然通关验收、共享物理洞口或邻区同时驻留；不能据此将 W00b2b 或 W00c 标为完成。

## 验证方法

专用回归为 `godot/scripts/world_prepare_budget_validation.gd`。独立 Godot 4.6.1 runtime QA 命令：

```bash
node tools/run_python_tool.mjs tools/run_godot_regressions.py \
  --engine /tmp/godot-4.6.1/Godot_v4.6.1-stable_linux.x86_64 \
  --suite world_prepare_budget --suite all_chapters_demo --suite boss_trial \
  --timeout 240 --log-dir /tmp/crimson-runtime-qa-final
```

三套均为 0 failures。`world_prepare_budget` 为172 checks，通过且日志无 WARNING/ERROR；覆盖缓存累计计数、冷目录暂存与取消、早期／中段／末段准备取消、来源回滚、同步/异步摘要一致及宿主退出清理。验证脚本 SHA-256 为 `ee1d87b3752cb55843a13075c5952ff052cb47ba44853e00ae945505280f2cc0`。`all_chapters_demo` 六章通过；`boss_trial` 通过，但本轮也记录到未归因 ObjectDB 退出警告。

同轮还有8套邻接回归通过：`world_async_loading` 473、`world_host` 539、`world_neighbor_gameplay` 7063、`world_neighbor_gameplay_live` 44、`world_enemy_residency` 55、`world_interaction_residency` 144、`narrative_runtime` 27、`save_product` 23 checks；另有六章 `all_chapters_demo` 及 `boss_trial` 通过，合计11套相关回归均为0 failures。`world_neighbor_gameplay_live`、`world_interaction_residency` 与 `boss_trial` 退出时出现未归因 ObjectDB 泄漏警告。

静态验证中，`npm run test:campaign`、`npm run test:runner`（7/7）、`npm run check` 均通过；campaign/章节、路由与升级检查分别报告6章、657项路由检查和11,013项升级检查。两个修改后的主脚本通过 Godot 4.6.1 `--script` 检查，`git diff --check` 通过。

一次合成验证场景的 completed arrival 记录 work 35,457µs、wall 50,434µs、6批、最大单批8项、最大单项15,383µs。这是该次 fixture 观测，不是性能基准；它表明单项执行可超过2ms准入预算。没有 FPS、真实游玩帧时间或启动时间结论。Godot editor import 成功，无资源导入或脚本错误，进程退出时有 RID 诊断。同步/异步摘要核对节点类型计数、敌人位置、具名静态物体的位置、静态碰撞形状/多边形几何和 UI 结构；这仍不是所有运行时几何的逐点或像素比较。预算验证日志保存在 `/tmp/crimson-runtime-qa-final/`。
