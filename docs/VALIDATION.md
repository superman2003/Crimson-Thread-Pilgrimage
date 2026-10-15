# 验证与验收说明

本页说明当前源码的验证入口、证据要求和未完成的产品验收。默认 Godot 回归登记 **99 套**，其中包含4个叙事脚本；登记数量不等于已经执行或通过。某个提交的本地结果、远端 CI 和发行包验收应分别记录，不能用历史绿灯、截图或中途的 PASS 标记替代最终结果。

## 推荐执行顺序

在仓库根目录执行，使用 Godot 4.6.1。先准备 Git LFS 资源、Node.js 和 Python 3；Linux 真实软件 GL 还需要 `Xvfb` 及可用的 Mesa/llvmpipe。缺少图形环境时应报告环境失败，不把无窗口渲染结果当作真实 GL 结果。

```bash
npm test
npm run test:campaign

GODOT_BIN=/absolute/path/to/Godot_v4.6.1-stable_linux.x86_64
python3 tools/run_godot_import.py \
  --engine "$GODOT_BIN" --recovery-mode \
  --log-dir artifacts/local_validation/import

python3 tools/run_godot_regressions.py \
  --engine "$GODOT_BIN" --software-gl \
  --log-dir artifacts/local_validation/regressions
```

导入工具执行两轮并分别保留日志，任一轮报错均失败。`--recovery-mode` 将资源导入与编辑器插件隔离，**不验收插件行为**，也不替代后续正常运行的场景回归。

回归 runner 未指定 `--suite` 时执行当前默认99套；每套使用独立临时用户数据目录，避免写入玩家存档。默认超时是**每套180秒**。Linux 的 `--software-gl` 会启动真实 X11/OpenGL 软件渲染环境，不是 Godot 的 headless 假渲染器。它验证该环境中的行为，不证明目标显卡、驱动或发行包均已验收。

可选择相关套件复验，但应明确这是定向验证：

```bash
python3 tools/run_godot_regressions.py \
  --engine "$GODOT_BIN" --software-gl \
  --suite map_player_pins --suite cartography \
  --suite world_map --suite survey_map_knowledge \
  --log-dir artifacts/local_validation/maps

python3 tools/run_godot_regressions.py \
  --engine "$GODOT_BIN" --software-gl \
  --suite world_save_candidate --suite save_product \
  --suite build_transaction_runtime --suite world_departure_snapshot \
  --log-dir artifacts/local_validation/save
```

同一工作树中的导入、Godot 回归和 `npm test` 应串行运行。目录构建故障注入及 runner 单元夹具会临时修改真实路线源文件；清理逻辑会恢复原字节和时间戳，但并行测试仍可能观察到暂态内容。不要让另一实例在此期间加载同一源文件。

## 严格失败门禁

[`tools/run_godot_regressions.py`](../tools/run_godot_regressions.py) 会在以下情况判失败：缺少脚本、缺少成功标记合同、非零退出、超时，或日志出现 `SCRIPT ERROR:` / `ERROR:`。即使 Godot 返回0、脚本打印全部断言通过或已有 PASS 标记，错误日志仍会让整套失败。

单独运行 `--check-only --script` 适合快速检查修改的 GDScript，但也必须检查日志；不能仅凭退出码0判定解析成功。解析通过后仍需运行相关真实场景。

首轮失败日志、故障原因和修复后日志应分别保留。最终证据需关联实际提交或源码 SHA、完整命令、套件数、断言数、退出码及引擎错误数。ObjectDB 等退出警告应按原文记录和跟踪，既不冒充脚本错误，也不据此宣称“无泄漏”。远端 CI 结果必须核对对应提交和最终 workflow 状态；本页不预先宣称当前分支的完整 CI 已通过。

## 静态检查覆盖什么

- `npm test` 包含 JavaScript/数据测试、活动地图质量审计和验证工具自身的负例。runner 负例覆盖真实子进程失败、零退出脚本错误、超时、信号终止及故障源文件恢复。
- `npm run test:campaign` 检查 campaign、章节、路线、叙事和升级数据之间的关系。
- 活动地图审计包含 `world_routes.json` 对平台、地形的覆盖与追加；按二维房间轮廓检查重叠与恢复点，并考虑实际玩家碰撞体及支撑空间。
- `npm run test:map-quality:all`、`npm run test:generated-maps` 是更广的严格审计入口。旧生成地图属于另一布局管线，活动图通过不代表生成图通过；发现的错误不能通过省略范围或降级门禁隐藏。
- 几何审计证明数据关系和所测恢复空间符合规则，不证明每次跳跃、每条路线或自然通关可完成。重复模板和局部轮廓相似也仍需要关卡体验审查。

## 当前玩法回归重点

### 地图、知识和自定义图钉

地图遵循“购底图、探索记录、钟龛补绘”的知识规则。未购、已购未绘和已补绘是三个不同状态；公开房间轮廓不等于已经补绘。嵌套秘密房间按最内层归属判断，不能借已补绘的外层大厅显示细节或放置图钉。

`cartography`、`world_map`、`survey_map_knowledge` 和 `map_player_pins` 分别检查购图补绘、区域/世界固定坐标、知识层以及自定义标记。图钉专项覆盖：

- 目标、留意、回访三类；最多12个；重复点、边界、错误类型和非有限坐标。
- 区域与世界投影、缩放/平移后的实际右键输入，左键拖动保留；视口外和拖动中的右键不放置。
- 可聚焦的类型、当前位置、列表与删除控件；地图内可读的成功/失败提示；标记和列表共用编号。
- 跨区与重启恢复、旧损坏记录安全忽略、只读显示不修写图钉数据；未知旧标记不占可用容量。
- 写入失败仅撤回本次图钉键的修改，保留已有档案及刚获得的其他进度；暂停保存时在修改前拒绝。
- 地图关闭、跨区旧控件、退树或宿主释放后的陈旧回调不写入新区域或存档。

专项使用的定位、补绘和进度夹具应在日志或截图说明中标明，不能作为自然探索获得这些知识的证据。

### 构筑、付费补给和存档

四类槽位是战具、战斗饰件、行旅饰件、线技。`build_slots`、`build_slots_ui`、`build_transaction_runtime` 等验证兼容类型、解锁条件、休眠、容量、实际付费补给和失败回滚。付费操作须以成功写入为提交边界；报价不扣费，切换和休眠不会赠送恢复或次数。

`world_state`、`save_product`、`world_save_candidate` 和 `world_resume_regression` 验证旧版迁移、备份恢复、完整候选、真实失败保留旧状态、暂停写入的内存检查点以及重启读回。候选保存减少重复完整深复制，不代表保存已经异步化或更快：候选防御复制、构筑序列化、JSON 校验/编码、临时文件重读及磁盘写入仍有同步成本。

`world_departure_snapshot`、准备/预检、异步装载、宿主和邻区套件验证出发结算、分帧私有快照、取消、代数/来源失效、退树和回滚；目标奖励、发现记录及存档不能从半建区域提前提交。唯一读取 worker 的相关专项验证冷/热缓存、所有权交接、取消和修复重试，不证明所有启动 I/O 已移出主线程，也不证明每个复杂单项满足硬2ms时限。

战斗、敌人驻留、动作清理与叙事专项各有自己的场景和断言。墙后不可见/不可伤害、解除遮挡后恢复、奖励只结算一次等证据不能外推成所有敌人、Boss、设备和长期会话都已验收。

## 截图与人工验收边界

真实截图应来自正常 GL 渲染的 `frame_post_draw`，记录源码、区域、界面、定位/授予/暂停夹具和图片哈希；不得把合成图当实机图。静态 UI 图只证明该帧的呈现，不能证明保存原子性、性能改善、动作命中或自然获得装备。

仍需单独完成：

- **T03 长期稳定性与性能**：在目标硬件反复跨区、重战斗、采样帧时间/内存、检查音频退场和真实手柄输入。软件 GL 与短回归不替代持续实测。
- **T04 完整游玩**：新档、伤害开启、多种探索顺序和构筑的六区通关、结局与回访；由不熟悉项目的玩家记录困惑、卡关和难度变化。
- **T05 发行包**：对最终导出包独立解压启动、设置、保存/读回、资源与许可、结局及目标系统逐项验收。源码 CI 不自动认证某个下载包。

具体进展和历史证据见 [升级进度](UPGRADE_PROGRESS.md)、[任务台账](UPGRADE_TASK_LEDGER.md) 与各批报告；本页提供复验方法，不替未执行的验收盖章。
