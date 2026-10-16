# W00b2b：首区配置共享后台准备的现代整合

## 2026-10-16：接回 #95 的新 main 依赖

基于已修复真实首启窗口的 `568a25f4`，合入 #95 `2bf90970` 与 main `2d60b550` 的动作/镜头/待机。五处文档/runner冲突取并集，默认108套，独立runtime/visual与桌面工作流保持。四个首启修复脚本逐字保持568a；Main/Player与新main逐字一致。29 runner、5 workflow、23 release单测通过；同源JS/数据沿用#95新组合npm/campaign结果。新组合严格双导入及startup393/startup budget/分层idle200三套真实GL全通过，startup budget一条ObjectDB warning未归因，其余无该警告、全部无ERROR；新head完整与双平台CI仍需终态。568a旧base的双平台实际通过单独保留，不当作此组合通过。原120帧、180秒、8操作/2ms准入与全部故障/取消守卫不变。


## 2026-10-16：修复真实导出包 120 帧首启失败

`0ea29655` 首次触发依赖分支的 Windows/Linux 桌面门禁后，两端都在首启存档检查失败，未进入恢复验证。根因已在真实首区复现：完整 validator 有 968 个步骤，旧实现每帧最多 8 步并强制等待，单独校验至少需要 121 帧，还未执行后续构建；不能以延长原 120 帧窗口解决。

修复让唯一 reader 先完成原 JSON 读取，再接受独占路线/坐标快照上的完整纯数据校验任务。968 步和覆盖、六地区等价性、路径/入口/代际/文件戳/票据守卫全部保留，worker 不读取 live cache 或 SceneTree；主线程快照仍为 512 边分片、每帧最多 8 操作及名义 2ms 准入。manifest 分片和目录合并只去除重复空等待，64 边目录粒度、最终取消观察点和同步退出 join/unwind 保留。单项不可抢占，仍不宣称硬 2ms。

四个冻结源码经 Godot 4.6.1 六套严格 GL 全通过：startup config 393、preflight 4334、catalog 71、config background 38，以及原 startup/prepare budget。startup/prepare 各有一条未归因 ObjectDB 退出 warning，其他四套无该警告，全部无 ERROR。真实官方 Linux 导出包使用原 build_release.py 和原 120 帧 smoke，首启、恢复、备份写回全部通过，玩家两次启动日志无 ERROR/ObjectDB，四源码前后 SHA 相同。此次本地导出来源为工作树，含自动导入 sidecar；因此干净 checkout Linux 与 Windows 必须由新 head 远端 CI 再验，不能把本地 Linux 结论当作 Windows 通过。见 [冻结证据](../../artifacts/modern_startup_integration/release_readiness_verification.json)。

## 2026-10-16：同步上游 Windows 退出令牌清理

依赖 #95 新头 `ccc0d23d`：同步 owned startup 私有帧唤醒，并把本批新增 `_prepare_startup_config` 三个等待点接到同一 helper。两处 loader 冲突保留现代首帧取消恢复与完整 catalog/startup 租约校验，未降级回只判断 host 存活。普通旅行/后台刷新及 120 帧/180 秒/严格错误门禁不变；不包含 #62 共享 metadata。

新组合在显式 4.6.1 的启动预算/退出生命周期及首区配置 223 项两套严格 GL 全通过，总 103.310 秒，登记源码不变、无引擎 ERROR 或 ObjectDB 警告；24 runner 与 21 release 工具单测通过。实际来源 tree `0fca274e`，精确 hash/log 见 `artifacts/modern_startup_integration/startup_shutdown_sync_verification.json`。此前 c942 对旧依赖8d0的CI不是此组合，新 head 远端/Windows仍需终态验收。

2026-10-16 依赖同步：#95已推进到`8d0a73ae`并纳入main `07ae21d4`工坊。本#96保留首区worker/validator/专项原字节，合入全部工坊路线与门禁，四处文档/计数冲突取并集，默认104套。npm/campaign与24项runner通过；冲突修复先推，新组合本地GL及远端新head CI继续验收，旧848c/旧base结果不代替新组合。原180秒、绘制模式和断言保持。[同步证据](../../artifacts/modern_startup_integration/workshop_base_sync_verification.json)。

本批以正式#95 `defb5dde` 为依赖，仅续接原#61 startup-region-worker `1751fe15→543f5ffb` 未进入现代树的真实差量，不夹带#62元数据worker。原现代首区构建/prepare、路线覆盖分片与manifest worker都保留，不重写或重复计为本批成果。

## 玩家改善及正确性

World首区/读档所需区域JSON的读取和解析使用唯一后台配置reader；规范化和路由覆盖由现有validator按帧批次推进。配置、路线、目录共享同一服务，完整来源租约仍有效才交给已有首区构建。新存档采用覆盖之后的最终默认出生点，旧存档入口优先，CLI章节/Boss等非World路径保持同步原语义。首区构建仍有深拷贝，不宣称所有启动准备都已无阻塞。

外来已完成但未领取的票据继续等待；取消不能偷取或丢弃该票据，reader关闭/真正启动失败及时收敛。路径、入口和路线代际在准备、目录完成后、最终handoff再次核对。独立审查另修正公开request_startup_region返回token在第一帧前/manifest等待阶段取消的既存契约缺口：活host进入可重试startup_error，释放/脱树仍安全；现生产Main没有直接保留这个token，不把它夸成已有玩家按钮的已复现软锁。

## 实际验证

最终生产源码严格双轮recovery导入通过；npm/campaign在早取消有界修正前已通过且相关JS/数据/工具未变，21项实际运行器单测通过。默认100→101套；在现有目录专项job里追加startup，7→8套，避免另建重叠job。全部原180秒、错误扫描与完成标记保留。

冻结生产运行时下16套真实GL组合通过，相关7文件指纹整批不变。只在最后进一步加强测试的foreign-ticket屏障，确保真正进入manifest等待阶段才取消；受改专项单独复跑223项/0失败、59.533秒，无引擎ERROR/ObjectDB。原20条_check源码（旧循环记录89项）全部保留。初版201、次版222与最终223分别归属自己的源码，不挪用旧通过。详细日志和SHA见`artifacts/modern_startup_integration/verification.json`。

| 套件 | 秒 | 实际完成标记 | ObjectDB退出warning |
|---|---:|---|---:|
| world_startup_config_background | 52.153 | WORLD STARTUP CONFIG BACKGROUND PASS checks=222 | 0 |
| world_startup_budget | 37.889 | WORLD_STARTUP_BUDGET_VALIDATION_PASS | 1 |
| world_catalog_background | 59.491 | WORLD CATALOG BACKGROUND PASS checks=71 | 0 |
| world_prepare_budget | 54.222 | WORLD PREPARE BUDGET PASS: 174 checks; cache continuity, bounded preparation, parity, cancellation, rollback, and teardown | 1 |
| world_preflight_budget | 78.363 | WORLD PREFLIGHT BUDGET PASS checks=4292 | 0 |
| world_config_background | 14.841 | WORLD CONFIG BACKGROUND PASS checks=38 | 0 |
| world_neighbor_config | 44.965 | WORLD NEIGHBOR CONFIG PASS checks=93 | 1 |
| world_async_loading | 131.077 | WORLD ASYNC LOADING PASS: 492 checks; six-region geometry/UI parity, commit budgets, reward/save isolation, rollback and teardown | 1 |
| world_host | 67.125 | WORLD HOST PASS: 539 checks; persistent host/player, single-region eviction, cancellation, cooldowns, failure recovery and seven six-region cycles | 0 |
| save_product | 0.921 | SAVE PRODUCT PASS: 37 checks, v1 migration, atomic backup recovery, builds, death cache and slots | 0 |
| boss_trial | 3.235 | BOSS_TRIAL_VALIDATION_PASS config=demo_ch01_boss_trial spawn=[430.0, 690.0] boss=[1017.6240234375, 720.0] boss_spawned=true | 1 |
| world_route_manifest_integration | 38.257 | WORLD_ROUTE_MANIFEST_INTEGRATION checks=134 failures=0 | 0 |
| world_passage_network | 66.228 | WORLD_PASSAGE_NETWORK checks=140 failures=0 physical_roundtrips=5 | 1 |
| world_gameplay_plan | 6.684 | WORLD_GAMEPLAY_PLAN checks=1219 failures=0 | 0 |
| world_route_manifest_walk_lower | 97.662 | WORLD_ROUTE_MANIFEST_WALK_LOWER checks=134 failures=0 physical_crossings=6 | 0 |
| world_route_manifest_walk_upper | 59.208 | WORLD_ROUTE_MANIFEST_WALK_UPPER checks=90 failures=0 physical_crossings=4 | 0 |

16套中的startup使用最终生产代码、旧测试屏障；最终测试hash以另一次223项为准。planner本轮1219项是实测值，既有2ms预算相关零actor循环逐次计_check，计数会变；原脚本/断言未改，不按断言数宣称工作量或进度。

六套各有一条ObjectDB退出warning，未归因；不声称仅属既有原因，也不代表长时内存稳定。Godot导入重序列化default_bus的uid/默认字段/顺序，未改音频语义；组合后已恢复HEAD原字节，最终专项也核对其hash。仅明确冻结源码集合前后一致，不冒称全仓所有字节从未变化。没有新图片/像素或人工自然流程验收。

## 保留边界

W00b2b仍部分完成：同步prepared-config深拷贝、最终metadata探针/复杂单项、硬2ms帧预算仍未解决；历史76落点本地180秒性能OPEN保留。没有以夹具证明伤害开启自然六区、共享物理洞口/邻区完整共同驻留或长期稳定。完整101套远端CI只按本次发布head再核验。此PR叠在#95，审查仅计算本批差量，不把#95尚未进main当作已合入。

## 2026-10-16：补齐依赖分支的桌面发布候选检查

#96 的 base 为 `codex/w00-catalog-modern-integration`，现有桌面工作流仅匹配目标 `main`，因此前述专项和完整回归的绿灯不能证明这个组合在 Windows 打包恢复通过。本次仅将该现有工作流的 `pull_request` base 匹配扩至 `codex/w00-*-modern-integration`，`push` 仍仅 `main`，权限、路径过滤、120 帧启动、恢复写回、ERROR 判定及所有时间限制不变。增加两条配置回归，`python tools/test_release_builder.py` 共 23 条通过。此增量不改任何生产 GDScript、素材或既有运行参数。

继承 c6b0e74c 的同源本地结果：startup budget 与 startup config 223 检查两套严格 Godot 4.6.1 GL 均通过，总耗时 103.310 秒；源 hash 未变。局部 startup config 测试观测 259 帧/8.247 秒并非 120 帧打包启动证明，因此新 head 必须独立等待 Windows/Linux 实际打包 smoke，不以 #95 的通过替代，也不放宽 120 帧门禁。
