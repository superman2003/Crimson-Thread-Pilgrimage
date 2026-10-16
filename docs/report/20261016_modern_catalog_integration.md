# W00b2b：World物品目录共享后台准备的现代整合

## 2026-10-16：Windows 启动中退出的令牌释放修复

新同步后 Windows 发布烟测真实失败；verbose 提交 `fe842d39` 精确指出 `world_transition_token.gd`、一个 RefCounted 和两个 GDScriptFunctionState 残留。Linux 4.6.1 微夹具重现了宿主已释放但等待下一帧的局部令牌仍活着；仅同步唤醒后，退出错误和残留消失。

生产修复只让 owned startup 使用 loader 私有帧信号，正常仍由真实 process_frame 转发；shutdown 先取消令牌、关闭并 join 唯一 reader，再断开转发并同步展开挂起调用。普通旅行/后台刷新仍等待原 SceneTree 信号，不伪造全局帧，不改变 8 项/名义 2ms 的 admission 规则。

严格 `world_startup_budget` 和目录 71 项通过，新增首帧、prepare/build/最后 finish 退出的零额外帧释放、成功/失败断开、同一真实帧一次续体、在树重复 shutdown 检查；发布工具 21 单测通过。两个轻量真实 loader 所有权夹具仅替换资产密集构建，实际 World 各阶段由前述 GL 专项覆盖。首次 Xvfb PATH 预检失败和新增 WeakRef 推断解析失败留证，修正后才接受结果。

Windows 修复 head 尚待 CI，不能据 Linux 通过宣布已修全。该次真实启动观测恰为 120 帧（6.602 秒，manifest 14 批/6906 边），接近既有发布上限；原 120 帧、180 秒、ERROR 拒绝、恢复存档备份挑战均不放宽，亦不以重试掩盖失败。下游 #96 须同步私有帧唤醒覆盖其新增 startup 配置等待并另验。证据见 `artifacts/modern_catalog_integration/startup_shutdown_verification.json`。

2026-10-16 主线同步：维护者已将#91工坊合入main `07ae21d4`。本次保留#95目录worker源码原字节及新主线全部工坊路线/验证；四处台账/计数冲突取并集，默认103套。npm/campaign与24项runner单测通过。冲突修复先提交，新组合本地GL仍排队、远端CI按新head触发并跟进；旧defb的100套绿灯不套新组合。详见[同步证据](../../artifacts/modern_catalog_integration/workshop_main_sync_verification.json)。既有180秒、绘制模式与全部断言保持。

本批严格续接原#60相对#59的目录准备差量，现代基底为已合#88的main `1806e0cf`（tree与原`7c638832`完全相同），不带#61以后或新动作/镜头/素材。World冷启动不再在主线程逐区读取和解析物品目录JSON；复用loader唯一配置读取服务，按原作者区域顺序累积，每次合并最多64键，全部源文件租约仍有效才整体发布。原区域内覆盖、跨区域首项优先和同步oracle保持不变。

## 整合修复

- 外来已完成但未领取的reader票据继续等待，取消不能抢走其归属；真正空闲启动失败/reader关闭则及时失败。
- detach/shutdown恢复来源目录快照；回滚构建/最终handoff再次核代际，二次失效时恢复旧目录、保持玩法门控、保护原存档并保留重试。
- 现代路线worker取消/完整票据、地图刷新、前台预检、passage token、事务与玩法planner均保留，main/Player/美术未修改。
- 故障测试通过原runner finally恢复真实world_routes字节及atime/mtime纳秒值，正常、脚本错误、异常退出、超时、启动异常均有Python覆盖。默认99→100套，不降低180秒门禁。

## 验证

严格双轮recovery导入、npm/campaign、21项运行器单测通过。冻结运行时代码下14套真实GL相关组合全部通过；仅prepare与async各有一条ObjectDB退出警告，未归因，不宣称修复。源码按整批前后核验一致，完整结果见`artifacts/modern_catalog_integration/verification.json`。网络套保持原不自动绘制的状态/物理模式，上下完整路线步行保持正常绘制，两类证据不混称。

| 套件 | 秒 | 完成证据 |
|---|---:|---|
| world_catalog_background | 54.862 | WORLD CATALOG BACKGROUND PASS checks=70 |
| world_prepare_budget | 71.455 | WORLD PREPARE BUDGET PASS: 174 checks; cache continuity, bounded preparation, parity, cancellation, rollback, and teardown |
| world_startup_budget | 35.993 | WORLD_STARTUP_BUDGET_VALIDATION_PASS |
| world_preflight_budget | 94.013 | WORLD PREFLIGHT BUDGET PASS checks=4292 |
| world_config_background | 11.786 | WORLD CONFIG BACKGROUND PASS checks=38 |
| world_neighbor_config | 41.869 | WORLD NEIGHBOR CONFIG PASS checks=93 |
| world_async_loading | 129.646 | WORLD ASYNC LOADING PASS: 492 checks; six-region geometry/UI parity, commit budgets, reward/save isolation, rollback and teardown |
| world_host | 59.763 | WORLD HOST PASS: 539 checks; persistent host/player, single-region eviction, cancellation, cooldowns, failure recovery and seven six-region cycles |
| save_product | 1.018 | SAVE PRODUCT PASS: 37 checks, v1 migration, atomic backup recovery, builds, death cache and slots |
| world_route_manifest_integration | 35.995 | WORLD_ROUTE_MANIFEST_INTEGRATION checks=134 failures=0 |
| world_passage_network | 48.895 | WORLD_PASSAGE_NETWORK checks=140 failures=0 physical_roundtrips=5 |
| world_route_manifest_walk_lower | 86.939 | WORLD_ROUTE_MANIFEST_WALK_LOWER checks=134 failures=0 physical_crossings=6 |
| world_route_manifest_walk_upper | 70.784 | WORLD_ROUTE_MANIFEST_WALK_UPPER checks=90 failures=0 physical_crossings=4 |
| world_gameplay_plan | 5.792 | WORLD_GAMEPLAY_PLAN checks=1230 failures=0 |

独立审查发现旧stamp故障夹具在首次request后立即改文件，有可能worker尚未读旧版本。仅测试修为“新增read record已记录旧stamp，且旧item已进入staging”再单次变更，并保留原失效拒绝断言。修后只复跑受改catalog专项：71项、0失败、56.158秒，真实GL，无ERROR/脚本错误/ObjectDB，source与注入文件字节/atime/mtime均恢复。其他同运行时14套证据有效，不无意义重跑。

## 保留失败与边界

最初两轮新增早期回滚断言失败（66.025/58.579秒）保留。诊断证实磁盘存档和持久WorldState完全不变，但catalog_commit阶段区域host.story_flags尚未经过后续恢复步骤。修正仅拆分新增断言：早期检查持久状态/磁盘/no-arrival，最终handoff仍要求区域flags精确恢复；原50项不减少，生产loader未因该夹具变化修改。

W00b2b仍部分完成。目录克隆、keys枚举、单键操作和最终元数据探针仍有不可抢占工作；64键不是严格2ms保证。76落点原本地180秒性能OPEN不被这轮证据抹去。故障注入、局部物理行走不代表伤害开启自然六区通关，也不代表共享洞口/完整邻区共同驻留或长期稳定。recovery导入不覆盖编辑器插件。远端完整100套只按新发布head核验，不沿用旧#60的93套。
