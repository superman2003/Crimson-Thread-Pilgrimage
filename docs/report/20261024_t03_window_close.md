# T03：实际窗口关闭时结束音频所有权

本批基于 `e35a6a4eb9dbe6857a540a33b77c4324e6851176`。新建正常 World、等待生产初始区域发布后，向该新进程唯一可见窗口发送真正的 Windows `WM_CLOSE`。夹具不自行清理音频，不修改人物位置、能力、库存或战斗状态。

## 问题与改动

旧自动退出在音频后台完成最后一轮播放释放前销毁 SceneTree。Main 已有缓存释放和退树处理，但在子节点离树后捕获不到仍由音频后台持有的播放。本批最终夹具撤去 Main 唯一一行安装调用后，实际复现 12 个 Ogg 实例残留：3 个流、3 个播放、3 个数据序列及3个序列播放。进程 exit=0，验证器仍因 ObjectDB warning 拒绝，不能把正常退出码当作无残留。

`application_close.gd` 为每个 SceneTree 安装一个最终关闭所有者。收到主窗口关闭请求后仅进入一次收尾：暂停新玩法更新、在树内捕获并退役所有声音、释放真实场景与自动加载节点，让已有退树钩子取消和回收后台任务；随后结束应用缓存所有权，在仍运行的 SceneTree 中有界等待弱引用退役，再退出。关闭所有者使用 ALWAYS 处理模式，暂停中也可收尾。普通章节转场、人物与敌人参数保持原样；不清空退役 pending 来制造通过。

回归运行器现在同时设置 APPDATA 与 XDG_DATA_HOME，Windows 的隔离目录也实际生效。探针逐个核对 Godot 返回的用户目录位于自己的临时 APPDATA 中，只向自己启动的 PID 所属 HWND 发关闭消息，超时仅终止自己的进程。

## 最终实机证据

均为 Godot 4.6.1、独立 PID、GL compatibility、Dummy audio、固定 60 Hz；这不是实际帧率或人工时长测量。最终8项直接输入的发布索引原始字节逐项与三组正向捕获一致；每个进程运行期间全部9124项 Godot/tools 输入书签相同。

- `legacy_final_01`：PID 27852，8.672 秒。只撤去新增 Main 安装行，同一最终探针确认3个实际 Ogg 播放；exit0、零 ERROR、1 warning，12个上述实例残留，验证器 exit1。结束后 Main 原字节恢复，四次运行均另行校验恢复 SHA。
- `ready_final_01`：PID 34508，9.141 秒。实际3个播放，观察3、退役5个播放器，pending0（2ms）；exit0，零 ERROR/warning。
- `paused_final_01`：PID 38892，9.187 秒。真实暂停后连续两次 WM_CLOSE，两次信号均被观察，实际只出现一次完成标记；观察3、退役5，pending0（1ms）。暂停时 BGM 已由引擎暂停，准备快照的 playing 列表只剩落地声，不能称暂停后仍有3个 playing。exit0，零 ERROR/warning。
- `startup_final_01`：PID 37004，8.172 秒。未发布区域时，快照证实 config reader busy/pending、人物素材任务 pending、startup token 存活；连续两次实际关闭。生产退出快照仍处于 manifest 阶段，无伪造加载完成；正常退树取消任务，退出零 ERROR/warning。该次尚无音频，退役计数0，单独作为加载中关闭证据。

`baseline_01`、`positive_01` 是探针扩充之前的历史观察，保留日志与书签，但不称它们使用最终全部8项输入。旧书签漏列当时未跟踪的新增关闭脚本；最终运行已补齐，直接源码也完整归档。首次5套 CPU 运行发生在运行器补 APPDATA 之前，保留为历史，不作为最终隔离运行。

## 回归与边界

最终 `cpu_final_02` 用修复后的运行器，在9124项输入不变的前提下完成5套：application_close（12项，包含安装幂等、暂停重复关闭、真实Ogg弱引用释放）、audio_retirement、world_streaming（2536项）、world_startup_budget、texture_request_exit（4项）；总43.937秒，零 ERROR/warning。完整 npm test、npm run test:campaign 均 exit0。运行器合同31项中Windows实际运行1项、跳过30项，未把跳过项算作执行验证。本分支登记147套（含4套 narrative），不是尚未整合分支的联合总数。

本批验证 Windows 主窗口关闭。其它主动 `SceneTree.quit()` 夹具仍由各自所有者负责退役；本批没有宣称覆盖强制结束进程、崩溃或整轮长时间游玩。T03/T05及全部46项最终验收继续 OPEN；未合并 main。

证据入口：`artifacts/t03_window_close/published/manifest.json`，每项记录原路径、原始长度/SHA256、gzip 长度/SHA256；payload gzip mtime=0。最终直接输入哈希见归档的 `published-inputs.json`。

## 已发表依赖整合后的独立复验

外部维护随后将已发表的受伤、突进/钩索、能力素材、N02许愿事务、防潮线结、第六区雨槽及夹具收尾合入本PR，形成 `44ffc12593cfaf10303451b0cee2ef77ce658a29`。该确切树另登记154套，包含本退出套件；未包含随后PR222的最后三项接触材质，不能将本轮称为该材质或最终发行验收。原始fc183及9124输入证据仍为上述历史范围。

本轮为新增4张atlas与防潮图标复制5份已校验导入缓存，PNG源字节严格相同、导入设置LF规范后相同；SVG原工作副本只有换行差异，已在运行前恢复为当前Git对象原字节，再与来源核对。缓存SHA、原/目标元数据SHA和该唯一换行恢复均归档。第一次选定的单一来源没有可匹配图标，未启动引擎；随后扩大到已有验证工作树来源，未改素材或生产逻辑。

9166项Godot/tools输入在每轮运行前后相同，8项直接输入的原始字节与该发表树逐项一致。5套CPU终态（application_close12、quiet24、wish34、legacy36、capacity35）25.328秒，全零ERROR/warning；两道完整npm门及运行器合同通过（Windows实际1项/跳过30项）。三组新的独立原生窗口退出也均exit0、零ERROR/warning：ready PID35708/8.953秒，暂停双关闭PID38600/9.437秒，启动任务pending时双关闭PID24804/9.515秒。源、原始日志、结果及缓存来历见 `artifacts/t03_window_close/integrated_44/manifest.json`，不以新范围覆盖早期结果。

## 默认项目入口漏测与延迟安装修正

上述World夹具是在树初始化后实例化场景，未覆盖引擎加载默认主场景时根节点仍在添加子节点的边界。首次实现的 `root.add_child(owner)` 会在真实项目入口失败并遗留未挂载节点；此前World夹具通过不能证明实际默认入口通过。外部已发表 `207f247554cb3152e469348b1c8caff31b1e1c21` 将加入改为 deferred，并用根metadata占位，拒绝同一idle之前重复排队；默认回归增加加入前/加入后的重复安装检查。已以普通merge保留该外部修订及44整合父链。

新增 `tools/probe_project_close.py` 完全不传 `--script`，由引擎自己加载 `project.godot` 指定的World。探针观察既有生产探索提示后，只向自有PID窗口发真实WM_CLOSE；从私有APPDATA中的引擎日志确认隔离生效，并从生产退役输出验证实际播放释放，未注入测试准备状态。两次进程都保持9167项输入书签一致，控制结束后关闭脚本原字节精确恢复。

- 即时安装反向：仅换回44发表的关闭脚本，PID4048/9.625秒，进程exit0但验证exit1。实际3条ERROR为root busy、未在树内节点取路径、1资源仍在使用，另1个ObjectDB warning；泄漏类是Node/GDScript/GDScriptNativeClass，本次没有把它误报为先前夹具的12个Ogg实例。未出现关闭完成标记。
- 延迟安装正向：PID39644/10.360秒，真实默认入口exit0，零ERROR/warning，观察3个播放、退役6个播放器，pending0（1ms），恰好一次完成标记。7项直接输入原始字节与最终发布索引逐项相同。更新的默认退出12项与完整两道npm门另验通过，9167项书签不变。

原始证据见 `artifacts/t03_window_close/project_entry/manifest.json`。44的5套标准CPU运行中，继承的runner把quiet/wish/legacy三名连成一个字符串，未对这三套启用固定时钟；这些CPU结果保留其实际默认时钟范围，不能称固定60Hz。专用窗口与默认项目入口的原生命令均明确传了fixed60，不受此列表缺陷影响；该三名拆分由后续第六区批次发表。本批未因此回填或改写历史运行记录，46项最终验收仍OPEN。
