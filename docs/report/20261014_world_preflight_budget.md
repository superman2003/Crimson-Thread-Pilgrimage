# World 目标区域跨帧异步预检

日期：2026-10-14。本次基于 PR #34 head `143533d06f24b5577b8d631fb536e0ffd7684e26`；PR #33 的 enemy residency 死亡事件确定观测修正 `ac7e3c1a2335a15dd5fb05f207a5444f96e2d16b` 作为源码补丁纳入本次 validation fixture，不表示 PR #33 commit 是该分支的 ancestry。这是 W00b2b 的一项子里程碑，W00b2b 仍为部分完成。

## 行为与准入边界

异步切区路径在来源区域交接前，分帧验证目标区域配置。验证器逐项检查区域头信息、记录和有限坐标、敌人/NPC/交互对象等身份、敌人配置、地形与洞穴几何、平台身份/尺寸、世界边界及目标落点；路线覆盖在平台检查前应用。普通 portal 预检取消保留来源配置与节点身份、玩家位置/碰撞/进度、构筑缓存、打开的地图、输入锁与 process mode，以及存档字节和 mtime；夹具在取消前给钱包增加17但未存档，证明取消路径没有提前保存。在成功目的区域发布边界，先合并 shortcut flags 并刷新 portal，再执行 `_publish_region` 与存档。预检失败或取消时不交接区域、不保存来源区；通过预检后的目的区域构建若取消，则沿用既有回滚逻辑重建并发布来源状态，但不会授予目的区域 shortcut。tube 终点取消保留来源 frozen 状态与 `TRANSIT` 碰撞，但按既有回退逻辑移动玩家32px，不能据此声称所有入口取消都保持玩家坐标完全不变。

每帧最多准入8个验证步骤。批次已执行至少一个步骤后，若已用时间达到2ms，则停止准入后续步骤并在帧边界让出；该阈值是准入预算，不会中断正在执行的步骤。目标区域 JSON 文件读取与解析，或缓存命中时 `cached_raw` 的深拷贝，在逐项计划启动前作为一个不可抢占阶段执行，由 `preflight_json_usec` 单独记录。验证器 header 步骤调用 `ROUTES.config_path(id)`，它仍会同步读取并解析 `world_routes.json`；这一辅助读取不能让出，耗时包含在 `header` 操作计时中。`ROUTES.apply_to` 仍在一个 `apply_routes` 步骤中完整深拷贝目标配置并执行 overlay 遍历/追加，不在函数内部让出，耗时计入该步骤的 operation timing。读取、JSON 解析、缓存深拷贝和完整 route overlay 都没有固定工作量上界，单项可能超过2ms。

指标用于描述校验游标、批次准入、按操作类别累计的耗时及总墙钟时间；`preflight_operation_usec` 是类别累计值，不是每个独立步骤的耗时。它们不表示帧率、硬性单帧上限、启动时间改善或所有准备工作均已分帧。首次同步准备/preflight及复杂单项的固定工作量上界仍未解决。此次改动不覆盖 Boss 战斗推进、长期自然通关、共享物理洞口或邻区同时驻留；W00b2b 和 W00c 不据此标记完成。

## 验证记录

Godot 4.6.1 editor 首轮导入完成，首次 UID 扫描时 MetSys 插件未解析到 `uid://crxgu2q73va5y`，随即实例化空引用并产生级联脚本错误。导入缓存生成后再次启动 editor scan：资源/脚本加载错误为0；editor 退出时仍有4条 RID 泄漏 `ERROR` 诊断（5个 Dummy Texture、131个 ShapedText、18个 Font、1个 LinkedVariation），并有 CanvasItem 与 ObjectDB 泄漏警告。该次仅是 headless editor scan，不是本批回归结果；RID 诊断未归因，后续 runtime QA 仍按严格 `ERROR` 门禁执行。

fresh QA 的18个 distinct suites 均分别通过，不是一次批量运行。核心 Godot suites：

| Suite | 结果 |
|---|---:|
| `world_async_loading` | 473 checks, 0 failures |
| `world_prepare_budget` | 172 checks, 0 failures |
| `world_passage` | 52 checks, 0 failures |
| `world_host` | 539 checks, 0 failures |
| `world_route_access` | 553 checks, 0 failures |
| `world_neighbor_gameplay` | 6916 checks, 0 failures |
| `world_neighbor_gameplay_live` | 44 checks, 0 failures |
| `world_interaction_residency` | 144 checks, 0 failures |
| `save_product` | 23 checks, 0 failures |
| `all_chapters_demo` | 六章通过 |
| `world_integration` | 65 checks, 0 failures |
| `world_enemy_residency` | 56 checks, 0 failures；共运行3次，每次相同结果 |
| `boss_trial` | 通过 |
| `tests/verify_narrative_runtime` | 27 checks, 0 failures |
| `tests/verify_world_narrative` | 28 checks, 0 failures |
| `tests/verify_narrative_progression` | 78 checks, 0 failures |
| `tests/verify_narrative_ui` | 0 failures（工具未输出 check 总数） |
| `world_preflight_budget` | 4009 checks, 0 failures |

一次早期调用遗漏 `tests/` 前缀而未启动 Godot，不计入以上结果；随后正确路径已通过。新专项4009 checks含逐步进度断言，并非4009个独立场景。进度夹具只是单次合成测试，不等于整段旅行帧数或性能基准。

这些 runtime QA 日志无 `ERROR` / `SCRIPT ERROR`。`world_async_loading`、`world_prepare_budget`、`boss_trial` 退出各有 ObjectDB warning，来源未归因；新专项无 `ERROR` / `SCRIPT ERROR` / `WARNING`。

新专项逐步进度夹具的单次合成观测如下：

| 采样点 | Cursor | Batches | Max ops/batch | JSON µs | Work µs | Wall µs | Max batch µs | 终态 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| early | 6 | 1 | 6 | 1508 | 1993 | 4415 | 2002 | 进行中 |
| mid | 31 | 4 | 8 | 1578 | 2080 | 18011 | 2002 | 进行中 |
| final | 3552 | 446 | 8 | 1956 | 29248 | 3068677 | 7438 | done=1, observer_final=true |

这些值不是帧率/性能基准；累计 work 及 wall 不代表一次实际旅行所需帧数。`preflight_operation_usec` 按操作类别累计，不记录每个独立步骤各自耗时。一次早期 UID 错误与 editor 退出的4条 RID 泄漏 ERROR 诊断属于导入/editor 过程，不是这些 runtime 回归日志；仍按严格错误门禁记录，不豁免。

静态项目检查：`npm run check` 通过；`npm run test:campaign` 通过六章/23 NPC/45 敌人概念、5 个章节文件/37 房间、657 路由检查、17 NPC/83 叙事状态及 11,013 升级检查。`npm run test:runner` 为7/7通过。Node v24.19.0 检查 `package.json` 为有效 JSON；Godot runner `--help` 与 `npm run test:world-preflight-budget -- --help` 均正确显示参数帮助，新专项已由独立 fresh QA 实际运行并通过4009 checks。

专项命令：

```bash
npm run test:world-preflight-budget -- --engine /path/to/Godot_v4.6.1-stable
```

专项回归 `world_preflight_budget` 也已加入 `tools/run_godot_regressions.py` 默认套件列表。
