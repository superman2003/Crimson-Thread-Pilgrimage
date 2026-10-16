# #94 动作、镜头、待机与最新工房主线的依赖同步

## 精确来源和范围

- 第一父提交：正式 #94 `aa02c4af1876a01c4853a53c9c54fa65d26d881b`，包括外部合入的 #93 固定身体、七披风区域待机。
- 第二父提交：main `07ae21d4c35ae6a33ca45809cf02d96c015ccf66`，包括外部合入的 #91 十九工房及十九次磁盘重启验收。
- 共同基线：`1806e0cf98a12f1d2b7a2cf175803cfe42de0746`。
- 仅同步依赖并本地构造双父 merge commit；没有新增功能，没有改生产算法、待机 helper 或素材，没有执行 GitHub 合并、自动合并、部署或 Release。

## 冲突解决与不变量

实际六处内容冲突为三份升级台账、默认 runner、成功 marker JSON 和 runner 单元测试。Main、生产 GDScript 及 workflow 没有内容冲突。

- 三台账保留双方历史及未完成边界，新增当前组合状态。
- 默认集、固定时钟集、成功 marker 取双方精确并集：总计 106 套，无重复或缺失，含四套叙事；保留 10+9 工房、10+9 次重启的严格完成标记。
- 所有继承的单套 180 秒上限、渲染模式和严格 ERROR/SCRIPT ERROR 检查保持。镜头保留真实 Player 参数，待机保留真实 GL 完整像素契约；负面断言继续执行。
- 57 个非冲突来源差异文件逐字节一致；11 份关键生产脚本、747 个函数记录 SHA-256，均与正式 #94 来源一致。main 本次增量没有修改生产 GDScript，工房数据与验证器原样继承 main。
- Main 场景、main_level.gd 和主集成 workflow 与双亲均一致；motion/melee、room-camera、layered-idle 与 modern-ability-workshops workflow 全部保留。
- fixed_support.png：`2f596483024a92aa621929ab40766088ae7e1ec657d653e5301284d8c775dc30`。
- cloth_eight_phase_rebalanced.png：`222d12909c41bdf26c19b5a4362aca9376140cfae0aca1a8a3be378cc0baf706`。

完整来源/函数哈希见 [verification.json](../../artifacts/motion_idle_main_sync/verification.json)。函数块哈希连同文件哈希用于确认原样保留，不代替运行时验证。

## 本同步树的实际验证

- `npm test`：PASS，包含 JS 三组 smoke、活动六区几何/唯一性、6 项地图审计负面测试、28 项 runner、11 项 import helper、11 项 GPU runner helper 测试。
- `npm run test:campaign`：PASS，包括路线/通道/叙事及 11628 项世界升级静态检查。
- `python3 tools/test_regression_runner.py`：28 项 PASS。
- `python3 tools/test_workshop_layout_contract.py`：30 项 PASS。
- 默认 106 项集合及 marker、固定时钟并集、来源文件和两图 SHA：PASS。
- 新组合严格导入：2026-10-16 11:45:07—11:48:45 UTC，Godot 4.6.1 双导入 PASS，零引擎错误。导入重序列化的 default_bus_layout.tres 在运行前恢复到原始 SHA `de023fdd73685585c0e57905d790af0a086c79d8d848af481f8cff2d819dbbaf`。
- 新组合真实 GL：2026-10-16 11:49:43—11:58:33 UTC，既定十套全部 PASS；实际 llvmpipe/OpenGL compatibility，零 ERROR/SCRIPT ERROR、零 ObjectDB/leak 警告。唯一告警是驱动不支持切换 V-Sync。首次启动因 PATH 未含既有 Xvfb 而在任何运行套件前失败；仅补 PATH 后原命令重试，失败日志保留。
- 新提交完整 106 套远端 CI：本地证据步骤未判定远端结果，由协调者另核精确 head/tree。旧 102/103 套结果仅是各自来源的历史证据，不记作本同步提交通过。

## 精确树映射与十套新组合结果

重新 fetch 核实：本地 `c523c3bc41863d61a59b7249a5e3ae18c486439d` 与已发布远端 `7dbd0433c359c708a1ff27c18091b034c1ad0761` 的完整 tree 均为 `e6def8fc063e31631dda64f1ee5ea7b2187b1ef6`，两个 parent 相同。下列是这个精确合并树的新运行结果，非旧来源绿灯复用。

| 套件 | 结果与范围 |
| --- | --- |
| player_layered_idle | 200 项，真实 GL，像素完整 |
| player_motion_continuity | 958 项 |
| player_melee_feedback | 107 项；硬件模拟，实体手柄体感未验 |
| room_camera_stability | 78 项，真实 Player；普通跳跃画面 Y 漂移 0 |
| world_upgrade | 548 项；原 20 房；170.562 秒 |
| world_workshop_group_one | 450 项；10 房/10 次磁盘重启；155.698 秒 |
| world_workshop_group_two | 411 项；9 房/9 次磁盘重启；94.756 秒 |
| world_ability_acquisition | 74 项；8 个实际拾取；局部接近夹具 |
| world_gameplay_plan | 1226 项；纯 planner 和 detached mock-host 夹具 |
| world_route_manifest_integration | 134 项 |

显式使用 Godot 4.6.1、独立规范化 XDG DATA/CONFIG/CACHE/RUNTIME 目录和 0700 runtime 目录。所有单套仍限 180 秒，继承的渲染模式、固定时钟和严格错误门禁未变；未把本地十套说成完整 106 套。运行后再次核对 57 个来源文件与 11 份生产脚本哈希、两张 PNG 和总线原字节，均保持；未新增任何引擎运行来制作本证据更新。

完整结果、精确命令、环境、逐套完成标记、告警和原始日志 SHA 见 [runtime_verification.json](../../artifacts/motion_idle_main_sync/runtime_verification.json)，[真实运行 console](../../artifacts/motion_idle_main_sync/runtime_console.txt)、[双导入 console](../../artifacts/motion_idle_main_sync/import_console.txt)、[保留的首次 Xvfb PATH 预检失败](../../artifacts/motion_idle_main_sync/preflight_missing_xvfb.txt)。逐套完整原始日志保留在 JSON 记录的本地 QA 路径；本仓库随附 runner console。

本次后续提交只更新本报告与专属证据目录；不更改三份主台账、生产源码、helper、素材或门禁。

## 仍开放的验收

- 待机坏接点 2→4、6→7、7→1；完整呼吸与跑、攻、落地之间视觉连续性。
- 固定身体加七个披风区域不等于七张全身帧，也不等于完整漂移、循环或跨动作美术验收通过。
- 历史 76 落点性能验收、自然带伤六区体验及原工房夹具的产品体验边界继续开放。
- 本轮仅处理冲突与依赖。未通过改素材、helper、超时或图形模式获得性能绿灯。

## 2026-10-16：完整回归与像素门禁独立作业

远端 head `7dbd0433` / 同树 test merge `08f9eba` 的 run `38895193107`，实际已输出 `suites=106 failures=0`，之后 atlas 5/5 与邻区 artwork 6/6 通过。作业从 11:39:18 到 12:24:40，累计约 45 分 22 秒，在 live GPU 后置检查中收到 `The operation was canceled.`，最终 arrival UI 尚未执行。因此该 run 结论是 cancelled，不是全绿。耗时与原 45 分钟 job 上限相符，但没有取得额外官方 timeout 注释，不能进一步确定取消来源。日志有 50 条 ObjectDB warning，未归因，不能写成无警告。

本次将原一个作业拆为独立 `runtime` 与 `visual`：前者仍跑不筛选的 106 套软件 GL，后者保留原全部 8 条像素验证命令、成功标记及各自参数。两个作业均保持原 45 分钟上限和严格错误行为，分别检出相同 github.sha、导入和上传独立日志。没有提高任一单套 180 秒门禁、live GPU 300 秒或导入 600 秒预算，没有删除检查、吞错或接受缺失标记。新增 5 项工作流完整性单测、既有 28 项 runner 测试和 YAML 解析均通过。生产 GDScript、PNG 和已有测试源码未变，复用上述同源本地 10 套结果；新作业仍须在新 head 全部完成。
