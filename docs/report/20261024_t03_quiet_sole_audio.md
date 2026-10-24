# T03：静靴验证器音频退出

基线为PR213追加计数修正 `7b36d26d08fc223ad335b5fb776a338f2e3bd4d0`。只改夹具及诊断工具，生产静靴、伤害、Player和音频不变；全部46最终项保持OPEN。

原夹具释放真实World后等4帧，组件结束后等3帧。按原源码及旧无效陷阱倍率重新运行：`native_baseline_01` 22项中5个预期功能失败、exit1、零engine ERROR，末尾1条ObjectDB warning；verbose列出14实例（播放Ogg4、Ogg包播放4、流Ogg3、Ogg包3）。本轮14与历史213的12分别记载，不回写旧证据。

现在在World及组件仍在树内时捕获所属流／播放弱引用，停止音频、释放节点、结束独立夹具的AudioDirector静态流缓存所有权，再用既有有界drain实际观察pending0。待验表不清空，固定帧数不再冒充混音线程已收尾。新增两阶段退役检查；native另要求实际捕获World播放。仅删除本进程明确创建的私人测试存档及其备份。

最终CPU为24/0。`native_fixed_positive_01` 为25/0、exit0、4.796秒，零ERROR/warning，observed6/retired9，组件实际退役79ms；`native_fixed_negative_01` 用同一最终夹具只恢复倍率1.0，25项中原5项功能失败、exit1、4.859秒，零ERROR/warning，observed5/retired8、退役83ms。旧无效功能仍明确被拒绝。

`native_capture_rollback_01` 只撤显式捕获，仍保留结束缓存所有权与drain：25项中原5失败加1个实际World播放观察检查失败，4.703秒；本轮没有warning，因为既有生产退出及剩余drain仍提供部分收尾。**该部分控制只证明检查能发现漏观察，不证明原警告由某一个捕获调用单独导致。** 旧整套退出策略实际复现、新整套收尾干净退出支持此夹具修正；不宣称全部历史问题、生产音频、长跑或发布退出已完成。

每进程严格180秒，Godot4.6.1／Dummy音频／固定60Hz输入，native为真实GL compatibility，不是FPS验收。九项源码／原seed输入SHA前后一致，并与发布原文核对；所有变体finally精确恢复源码。原退出源码、活动源码、逐轮stdout、参数与控制结果存于 `artifacts/t03_quiet_sole_audio`，gzip mtime0、压缩与原文长度/SHA均核验。

重放：`python tools/run_quiet_sole_audio.py --engine <Godot4.6.1> --native --output artifacts/t03_quiet_sole_audio/replay_unique`。`--baseline --legacy-hazard`为原退出/旧功能诊断；`--legacy-hazard`只撤功能；`--skip-capture`只撤显式捕获。每次新目录，控制参数仅作用于验证器。
