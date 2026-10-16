# W00b2b：首区配置共享后台准备的现代整合

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
