# 现代主线的私有 World checkpoint 候选

## 2026-10-16：#97 同步目录恢复调度修复依赖（最新状态）

以已发布 #97 `bdb8a778`（tree `3a74b453`）为第一父，合入 #96 `8ce445a7`（tree `867cd9f4`，包含 #95 `ae9e249b`）。本地旧 `fa376c8` 与已发布头完全同树，先 same-tree soft 对齐，再仅合并此次依赖。三份台账取双方并集；相对 `bdb8a778` 的整个 godot 仅 `world_catalog_background_validation.gd` 新增 42 行，原 71 项保留并扩至 81 项。全部生产源码、数据、素材、109 套集合、runner、22 个 workflow、严格 marker/error、180 秒与绘制模式逐字节不变。

原 `bdb8a778` 同生产代码的 4.6.1 严格双导入与候选 103／保存 37／真实构筑事务 30 项证据按原来源复用，候选退出原有 1 条 ObjectDB warning 继续保留。本次没有启动 Godot 或 GL，也没有重跑三保存组合或全 109 套。新增目录 81 项真实 GL 通过来源是 #96 的 `8ce445a7` 组合：显式 4.6.1、exit 0、零 ERROR、零 ObjectDB warning；仅验证其源码与本次索引完全相同，不冒称 #97 新组合已执行。此次静态复核 29 项 runner 和 5 项 workflow 单测通过。

#97 新 head 的完整／像素／桌面 CI 待发布后按准确 head 另核，旧头绿灯不转记。#95 原 120 帧 Linux 发行包通过及 Windows 新 head 待终态按上游报告单独记账；此前 Windows 资源泄漏与后续恢复写回窗口问题不能混为一项。来源与等价证据见 [本次来源与等价证明](../../artifacts/modern_private_checkpoint/catalog_scheduler_sync_verification.json)。#64 出发事务、U04、W00b2b 整包、待机坏接点／完整呼吸／跨动作视觉连续性、自然六区流程及长期资源稳定继续 OPEN。

## 2026-10-16：#97 串接最新 #95→#96 依赖链

从本地 main 同步检查点 `948579eb` 再合入已发布 #96 `7ef90d17`（包含 #95 `2bf90970` 与 main `2d60b550`），本批改为沿最新 PR 链尖端推进。五处文档/runner 冲突取并集，最终默认 **109 套**（#96 的 108 套加私有候选）；22 个 workflow 文件、全部严格标记、180 秒套件上限、绘制模式及 runtime/visual CI 分工保留。目录/首区后台准备、发布工具、Player/动作/镜头/待机和所有数据/资产与 #96 逐字节一致；Main 仅保留原私有保存 flag 与 `_save_world` 差量，WorldState/候选验证与原 #97 一致。

最终组合 npm/campaign、29 项 runner、11 项 import runner、11 项 GPU runner、5 项 workflow 和 23 项 release-builder 静态测试通过。显式 **Godot 4.6.1.14d19694e** 严格双导入复验通过（11.679 秒）；三套受影响真实 GL 通过（合计 36.140 秒）：私有候选 **103**、保存 **37**、真实构筑事务 **30** 项。候选退出有 **1 条 ObjectDB warning**，原因未归属；没有 ERROR/SCRIPT ERROR，不据此宣布长期资源稳定。

首次双导入也无引擎错误，但 Godot 自动重序列化 bus 默认字段/UID，被源码冻结检查拦下。已仅恢复该文件的索引原字节，再完成上述双导入与三套 GL；接受轮全部源码及 bus 哈希前后一致，初轮日志保留。中间 107 套组合未跑 GL；本地未全跑 109 套、八组像素或桌面发行版，远端新 head CI 待发布后另核。完整来源、成功标记、哈希与限制见 `artifacts/modern_private_checkpoint/chain_sync_verification.json`。#64 出发事务、U04、待机坏接点/完整呼吸/跨动作视觉连续性及自然六区通关继续 OPEN。

## 2026-10-16：#97 同步动作、镜头与分层待机主干

在维护者合入 #94 后，将 main `2d60b550` 同步至私有 checkpoint 分支 `e7a37100`。五处文档/runner 冲突取并集，默认集合为 **107 套**：原 103 套全部保留，补入动作连续性、近战反馈、分层待机与房间镜头四套；严格完成标记、180 秒上限及绘制模式不变。21 个 workflow 文件保留双方并集，主集成 runtime/visual 分工与八条像素命令保持 main 原样，新增 5 项 workflow 自测通过。

保存/Main/候选验证与原 #97 完全一致；Player、镜头、反馈、分层待机、loader、全部世界数据及素材与新 main 一致。Main 相对新 main 仅保留原私有保存 flag 与 `_save_world` 改动，两张待机 PNG 原始字节未改。npm/campaign、28 项 runner、11 项 import runner、11 项 GPU runner 与 5 项 workflow 静态测试通过。此 107 套中间组合未执行 GL，随后仅验证串接 #96 的最终 109 套组合，见上节；原 #97 的 103 套/像素/桌面绿灯只属于原头，不转记为此次通过。

本次只解同步冲突；#64 出发事务、U04、待机坏接点 **2→4、6→7、7→1**、完整呼吸及跨动作视觉连续性继续 **OPEN**。来源及新组合验证独立记录在 `artifacts/modern_private_checkpoint/motion_main_sync_verification.json`。

## 2026-10-16：发布前同步最新工坊主干

本私有 checkpoint 批在正式提交前同步 main `07ae21d4`（维护者合入 #91）。原保存/Main/loader/Player 源码与前版 `81f0bdd8` 完全一致，工坊路线数据与新 main 一致；三份进度记录取并集，默认 103 套，npm/campaign 与 23 项 runner 单测通过。同步树新增 5 套受影响 GL 全通过：候选 103、保存 37、真实构筑事务 30、两组工房 450/411（19 房/19 次读盘重启）；显式 4.6.1 严格双导入通过，无引擎错误或 ObjectDB 警告。两组工房分别 116.011/86.381 秒，原 180 秒不变；新 head CI 待终态，原 28 套仍单独标原基线。范围不扩大至 #64 出发事务或 U04。

原实现与下述 28 套验证日期：2026-10-16。原基线为 main `1806e0cf98a12f1d2b7a2cf175803cfe42de0746`。本批独立续接原 #65 的 `21d93993` → `3841ae1d`，只接入其保存候选契约；不带 #62–64 的 loader 工作，也不包含后续 U04 图钉。

## 玩家改善与真实范围

保存时先在私有容器合成完整的区域和全局 checkpoint，验证并取得深层所有权后才尝试写盘。磁盘写入成功之后，由 Main 一次发布新 checkpoint。该保存原语失败时，旧 checkpoint 的对象与内容不被半次捕获或借用的 live 字典污染；live 游戏进度仍由原有业务规则处理，后续可以重试。

这不是新增存档槽或地图图钉，也不是所有业务操作的通用事务。现代叙事、付费补给、死亡遗留物和跨区调用仍须分别遵守其已有回撤规则。

## 精确来源与所有权

- `world_state.gd` 的现代基线与 #65 的 parent 逐字节相同；本批结果也与 #65 head 相同，结果 blob 为 `d514b6189841e58cd34f8c050fbc695d69909258`。
- `prepare_checkpoint` 只修改私有顶层、regions 表和当前区域表；完整校验后才执行最终深拷贝。因此成功候选既不借用 donor 的 nested 数据，也不借用旧 checkpoint 中未改的历史区域、构筑或死亡遗留物。
- `write_candidate` 校验并写入传入候选，不发布它。兼容的 `write(path)` 只委托给该原语，既有 v1/v2 迁移、v3 坐标、损坏保护、临时文件/备份/rename 协议保持不变。
- Main 的 `_save_world` 按 #65 的准确函数接入。额外只引入 #64 的 `world_save_capture_ok` 声明与必要赋值：调用开始先清 false，完整候选准备成功后才置 true。未接入 #64 的 departure snapshot、generation 或 loader 逻辑。
- 既有 blocked-memory 分支仍发布完整内存候选、禁止写盘并返回 false；这不是磁盘保存成功。

## 原断言与现代组合

旧专项的 47 条 `_check` 源码全部保留，本批加入 17 条源码断言，成功路径实际执行 103 项。新增覆盖真实 `.tmp` open 失败、超限临时 JSON 的读回校验失败、完整 build/wallet/资源/动作 cooldown/保存方案的 JSON 往返，以及旧 state、donor、候选之间的深层双向修改隔离。失败原因前缀确保付费 fixture 确实到达保存边界，没有只因前置条件不满足而假通过。

这些是明确安排位置、状态和故障的验证夹具。状态型 fixture 暂停宿主普通处理以排除物理推进干扰，不是自然输入通关证据。

### 验证状态

- 实际首轮系统别名为 **Godot 4.6.3.7d41c59c4**：严格双轮 recovery 导入通过（216.226 秒）；候选专项 103 项通过（30.526 秒）；固定 19 套现代组合全通过（总 646.910 秒）。包含完整 build/wallet、恢复/死亡遗留物、两组共 10 次通道真实穿越、取消/终点发布、资源循环和 UI/构筑。它们是 4.6.3 兼容证据，不冒称 4.6.1。
- CI 目标 **Godot 4.6.1.14d19694e** 另用显式二进制完成严格双导入（14.191 秒）；同冻结源码的新候选再次 103 项通过（33.882 秒）；原叙事 runner 完整 8 套全过（总 71.334 秒），含叙事后果/归途、四个 narrative tests、真实构筑事务和契印获取。
- 合计 28 个不同 GL suites，候选在两个版本各执行一次。没有为版本切换重复整套 19 组合，亦不把跨版本数据混成一次性能比较。所有接受调用均 exit 0、匹配严格完成 marker，且无 SCRIPT ERROR/ERROR；登记源码/runner hash 前后一致。
- 原 runner 没有记录逐套精确进程耗时，验证索引如实设 null；文件创建到末次写入跨度仅作独立可复核信息，不能冒充精确套件耗时。阶段总时间由外部 monotonic 时钟记录。
- 3 套有退出 ObjectDB 警告：4.6.3 的 `world_async_loading`，4.6.1 的 `tests/verify_narrative_ui` 和 `build_transaction_runtime`；未归因，未称长期稳定通过。软件 GL 的正常 V-Sync 不支持警告另记。
- npm/campaign 与 20 项 runner 单测通过；默认 99→100 个唯一 suite，新 exact-head 专项为 6 套。原 180 秒、原绘制模式和严格 marker/error 门禁不变。
- 最初 candidate 仅环境预检失败：Xvfb 已安装但不在 PATH，严格 runner 拒绝回退；补既有工具路径后才进入引擎，没有改源码/断言/超时。该失败证据保留。
- 初次导入自动重序列化 default_bus 的默认字段/uid/顺序，未改音频语义；在接受 candidate/组合前已还原 HEAD 字节，目标 4.6.1 导入没有再改写。只声明登记源码集合冻结，不虚构整个工作树从未有导入副作用。

正式新 commit 的远端 CI 仍须另核。上述实现完成时的旧头 #91/#93/#94/#95 检查曾通过；此后主干/功能分支变化，#94/#95/#96 均有新同步 head，不能沿用旧绿灯。此前 #95 Windows 退出资源 ERROR 已独立处理；后续 `2bf90970` 的恢复写回窗口问题及 `ae9e249b` 调度修复见[上游报告](20261016_catalog_resume_frame_budget.md)，其 Windows 新 head 仍待终态；#93 的素材顺畅度依然 OPEN，不由功能 CI 关闭。没有合并任何 PR。

## 必须保留的边界

1. 当前 loader 仍忽略 `_save_world` 的 bool/flag 后取出发快照；#64 出发事务尚未整合，不能据本批宣布磁盘失败时跨区出发安全。
2. #83 叙事回撤会用同值深拷贝替换 state。这里保存原语的 identity 保证不能扩大到整个叙事业务调用的 identity 保证。
3. 死亡遗留物部分调用在保存前仍使用原 `capture_global`，本批没有将这些调用全部改为新业务事务。
4. 临时文件失败夹具不证明所有 rename 失败都保留旧备份字节。旧协议在最终 rename 前复制 backup；未对真实 backup-copy/rename 故障作扩大保证。
5. 候选构建、完整校验、最终整树复制、JSON 序列化和磁盘操作仍是同步路径。本批不承诺分帧保存、零复制、硬 2ms 或 FPS 改善。
6. W00b2b 整包、共享物理洞口、相邻完整区域共同驻留、自然六区带伤流程和长期内存/引用稳定仍未完成。没有新的视觉改动或像素验收主张。

## 可复核来源

最终源码和日志 SHA-256、实际 suite 状态与告警计数记录在 `artifacts/modern_private_checkpoint/verification.json`。原始带工作区路径的运行日志不作为公开产物上传。
