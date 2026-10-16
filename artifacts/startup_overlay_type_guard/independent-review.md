# 首区 validation worker 异常 overlay 守卫：独立只读审查

审查时间：2026-10-16 UTC。当前状态：最终提交 `88071173827e637ce711a4082ec74b7d669391b0` 三文件源码审查完成；四套真实 GL 回归终态、完整日志及 SHA 均已独立复核，三文件与最初审查冻结内容完全相同。

## 结论

**相对 `8ce445a76393718f37ee87d65db02d7903fb7b7e`，本次三文件修复未发现新增 P1/P2 阻断问题。**

此前报告第 2 节的 `world_overrides: 42` 不收敛风险现已有精确旧版运行证据：调用一个 overlay operation 后发生 `is_empty(int)` 脚本错误，仍为 `done=false, stage=world`。新版在该消费点显式失败，完成态沿 overlay → validator → reader 返回，保留 ticket 所有权协议。冻结源码的新 startup suite 已记录真实 GL `PASS checks=835`，无 `ERROR` / `SCRIPT ERROR` / ObjectDB warning。本审查没有自行运行 Godot/GL，也没有修改 owner 源码。

这关闭的是已报告的后台 validator 直接消费畸形 JSON 容器/记录时没有显式终态的问题；不是对所有路线/地区字段的完整 schema 验证，也不是自然游玩、长期稳定或任意内部 Variant 的保证。

## 精确冻结点

工作树：`/workspace/scratch/4d581c1832c9/crimson-metadata-integration`。初次审查时 HEAD 与 base 均为上述 `8ce445a…`；最终 owner 已提交 `88071173827e637ce711a4082ec74b7d669391b0`，其父提交精确等于 base，且提交仅包含以下三文件，SHA-256 均未变化：

- `godot/scripts/world_route_overlay_job.gd`：`8f2a69f5ef77d37de59f99304ddb8dc0768e8a32c1038734b62b8d01fa841a85`
- `godot/scripts/world_config_validator.gd`：`aca91a570b0caf494552dc0d0a610a3b69bf5d3c0749e5036c6812e9945efd36`
- `godot/scripts/world_startup_config_background_validation.gd`：`e7cf0c2f36251cdf00b1d11b31db705b3cc3aab45e10b5e2ddf54a715655c4db`

独立快照、完整差量与静态核验 JSON 保存在 `/workspace/shared/review-overlay-error-guards/`。未操作远端、未 approve、未 merge。

## 1. 明确失败与收敛路径

- Overlay `begin`（40–74）将参数扩大为 Variant，错误根类型可以进入受控失败，而不在强制 Dictionary 参数边界抛运行时错误。每次开始清空 error、结果、copy、各游标及 pending/merge 状态；空 Dictionary overlay 保持立即完成且不写 manifest version 的旧行为。
- `world`（103–107）先验证 `world_overrides` 和目标 world 的 Dictionary 类型，再做 `is_empty` / 深复制。报告中的数值 42 因此在第一个操作进入 `_fail`。
- Override（124–147）在数组和记录被索引/调用 `.get` 以前检查形状，且即使目标为空，也检查源 override 条目。Append（156–173）、interactives/removals/portals（177–206）、catalog（215–224）同样在实际消费者前验证。Catalog entry 在逐键 merge 时检查为 Dictionary（267–268），没有引入整体同步遍历。
- `_fail`（285–296）令 error 非空、result 空、done=true，并断开当前 copy/merge；它不依赖脚本错误退出、operation 限额或下一帧取消。后续 `step()` 因 done 不再运行 `_finish`，不会把失败覆盖成成功。
- Validator（256–271）允许 overlay 根 Variant 到达受控检查；在 overlay_done 后先查 error，再决定是否采用 result。失败调用 validator `_fail`，因此不进入 platform/world/entry 成功阶段。
- 新增 raw `id`、inventory.catalog、enemy kind 检查（121、128、197）在 `String(...)` / 后续 catalog 使用以前拒绝错误形状；不改变其他原有字段检查的相对顺序。
- Reader 未修改：其 `_validate`（95–101）在 validator.done 后返回错误和空 prepared；`take` 只领取匹配完成 ticket 并 join/null；`discard` 释放本票据，忙线程完成后由下一 admission 回收；whole-host `shutdown` join。新增错误均能进入这个原终止协议，没有新增 worker/cache/host 共享写入。

上述终止性针对有限、无环、从 JSON 得到且由 loader 独占交接的数据。私有 route_context 的 generation/path/world_size/bundle 是 loader 构造的可信类型；任意外部调用者直接注入错误 context 或构造循环 Array/Dictionary，不是此次真实文件输入模型。

## 2. 正常语义与大输入

未发现正常 JSON 区域被本次守卫错误拒绝的路径：

- override 仍按原字段顺序、源顺序逐个遍历所有目标；重复目标 ID 全匹配，没有改成 first-match，也未加入去重。`str(id)` 比较未改。
- 每个匹配目标仍各自复制 override，然后逐键覆盖；原有独立 nested-copy 所有权不变。
- Append、保留的 interactives、随后追加 portals 的顺序不变。数值 removal ID 仍只经过旧 `TYPE_STRING` 分支而被忽略；没有错误地将 5 强转为字符串并删除 ID `"5"`。
- World/catalog 保持 overwrite merge，未知普通 world 字段仍可携带任意有限 JSON 值；只对实际要求 Dictionary 的 catalog 记录拒绝数值/null等形状。默认空字段与缺失 inventory/catalog 的创建行为保留。
- 生产代码没有新增最大 validator steps、总时间、总记录数等任意 cutoff。4096 键 nested world overlay 的夹具是合法大输入，原 worker 循环仍运行到真实终态。
- 新增 256-operation 上限和 5 秒等待只存在于回归夹具，分别防止微测试和异步测试本身无限等待；不是产品拒绝输入的条件。

旧 `world_preflight_budget_validation.gd` 完整字节未变，仍保留独立旧同步结果 oracle、重复 room ID、独立 nested copy、数值 remove ID、portal 顺序与空 overlay no-op 断言。新 background oracle 主要证明同一 validator 在 worker/主线程执行一致；不把它单独解释成对旧版语义的独立 oracle。

## 3. 新夹具实际证明什么

- `_overlay_type_cases` 生成 186 种 root/container/record 错误形状；它们由测试直接传给 overlay job。形状均可由普通 JSON 表达，但这是微级直接调用测试，不是每个形状都写到真实 manifest 再从文件启动。
- `_malformed_validation_workers` 对 34 个代表错误分别取得真实 reader validation ticket、启动真实后台任务，断言 error/空 prepared、主线程标记为 false、完成票据在 take 前仍占用、take 后清线程与票据、raw/context 不变。34 项包括 31 个 overlay 代表错误和 raw catalog/id/enemy-kind 3 项。
- discard 后完成、重新 admission/retry、普通 shutdown 与接受错误任务后立即同步 shutdown 都有新断言。立即 shutdown 的测试没有先等待完成；调度仍可能让极快任务先完成，因此不宣称每次运行都能证明 join 开始时线程仍 busy。
- `FaultReader` 的 `overlay_type` 在 loader 调用 request_validation 时修改其私有 context，覆盖实际 startup 错误传播、无发布/无构建、保存字节和 WorldState 不变、catalog 回退、retry UI 与任务/ticket清理。它是明确的内部故障注入，不是磁盘损坏 manifest 的完整端到端测试。
- 原风险的真实输入可达性由源码链独立核实：manifest 接受根 Dictionary → `cached_overlay_bundle` 原样取 chapter value → loader 深复制该 bundle → worker。本次没有修改真实 manifest。旧版微项目只复现原 consumer 的非收敛一步，不冒称已经实际卡死完整游戏退出。

## 4. 原断言与门禁保持

机械核验原 fixture 的 61 条 `_check(...)` 调用行全部逐字保留（若包括 `_check` 函数声明则为 62 行）；原 fault 列表只增加 `overlay_type`，没有移除原故障项。原动态 393 项加新覆盖得到本次 835 项 PASS。

以下文件与 base 完整字节相同：loader、reader、Variant copy job、preflight budget suite、`tools/run_godot_regressions.py`、`tools/build_release.py`。

因此原约束保持：

- 主线程下一操作准入 `MAX_OPERATIONS_PER_FRAME=8`、`FRAME_BUDGET_USEC=2000`
- 深复制每 step 最多 512 边；overlay 原内部 32 操作/1200μs 批界不变
- 回归 runner 默认 180 秒，非零退出/ERROR/SCRIPT ERROR/缺 marker/timeout 继续失败
- release 真实二进制 `--headless --verbose --quit-after 120` 不变
- 本次三文件 `git diff --check` 通过

这些是操作准入/工作粒度限制，不等于所有 indivisible 操作或整帧具有硬 2ms 上界。

## 5. 已独立读取的运行证据

- 旧版隔离日志：`/workspace/shared/startup-invalid-overlay/logs/baseline-single-step-isolated.log`
  - SHA-256 `ae8e75e117c3f6fa40d66f5b5fb2eb7b22cadcb4f5e33dd46c5f1ca848a6512c`
  - Godot 4.6.1；出现精确 `is_empty` on int 错误；`BASELINE_SINGLE_STEP done=false stage=world operations=1`
  - 隔离 overlay 脚本与 base 的完整 SHA 相同，已核实。
- 新版真实 GL startup 日志：`/workspace/shared/startup-invalid-overlay/logs/focused-isolated/world_startup_config_background.log`
  - SHA-256 `de68c5d39a04d514204e45e60592a259183e7b96e954e21977c4758ceae8e5f6`
  - Godot 4.6.1 / X11 / OpenGL compatibility / llvmpipe
  - `WORLD STARTUP CONFIG BACKGROUND PASS checks=835`
  - 完整日志 `ERROR=0`、`SCRIPT ERROR=0`、ObjectDB=0；存在驱动不支持 V-Sync 切换的 WARNING，未隐藏。

最终四套真实 GL 均通过，全部日志已独立重算 SHA 和扫描错误：

- startup config background：835 项，SHA 如上。
- preflight budget：4335 项，SHA `cf52928f913e7ae6d084e6724b3aa315b65c68413b05c0a74812f43406cfe523`。
- config background：38 项，SHA `73c39bb855258fccbb17921b171c4c34f0999ed0efb9f240fdd5acce3553b3b4`。
- startup budget：完整 `WORLD_STARTUP_BUDGET_VALIDATION_PASS`，SHA `4293a6b9e0f87391b90fd79aede80e074203c301b7b875d7e451dc816639cafb`。

后三日志位于同一 `focused-isolated/` 目录。四日志均 `ERROR=0`、`SCRIPT ERROR=0`、ObjectDB=0，哈希与 owner 的最终 verification.json 一致。startup budget 此次记录 `frames=122`；这不是稳定少于120帧的证据，release 的 `--quit-after 120` 参数没有因此放宽，性能 OPEN 仍保留。

**最终复核结论仍为：该冻结提交相对 base 无新增 P1/P2 阻断发现；原畸形 overlay worker 不收敛项已由显式错误终态和定点回归覆盖。** 未自行运行测试、未复跑完整 CI 或 release，不将这四套局部证据替代完整 CI、发布或自然游玩验收。
