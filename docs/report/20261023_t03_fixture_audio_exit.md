# T03：章节、洞窟与平台夹具退出边界

本批针对三个验证夹具的进程退出，不替代人工体验、整合长跑或发布包验收；46 项最终清单保持 OPEN。

## 实际复现

`artifacts/t03_exit_lifetime/native_nonverbose` 的原始夹具在 NVIDIA GL、Dummy 音频、固定 60 Hz 下完成章节 270 项、洞窟 78 次和平台 13652 项；洞窟进程退出时有 1 条 ObjectDB warning。严格 runner 将该轮判失败，源文件冻结前后一致。

首轮 verbose、headless 非 verbose 均未复现，不能算修复。继续原始夹具 warm-cache verbose，章节和洞窟各实际复现 1 条 warning；对象为 `AudioStreamPlaybackOggVorbis`、`OggPacketSequencePlayback`、`OggPacketSequence` 和 `AudioStreamOggVorbis`。洞窟的实际列表是两套上述对象；章节还包含多条已播放声部与相关 StringName。原始日志全部保留，不过滤 warning。

headless 结果单独记录：`main_level._should_autoplay_audio()` 在 headless 默认关闭章节自动音乐，因此它的零 warning 不足以证明 native 音频退出正确。只读弱引用快照也曾在退出前看到 retirement pending 为空；这不能证明 AudioServer 没有残留对象。

## 修复候选与验证边界

三个夹具在场景仍在树内时调用已有 `audio_retirement.retire_tree`，先记录弱引用、停止播放器并解除 stream，再释放场景；结束时调用已有有界 `drain`，让真实播放引用完成退役。章节转场之前也捕获即将退出的旧场景。洞窟在 native 下额外要求观察过真实 playback，防止空集合让检查无效通过。生产游戏代码与敌人行为不变。

候选 headless 三套均通过：章节 271 项、洞窟 78 次、平台动态 17431 项，零 ERROR/warning，源冻结一致；其 observed=0，按上述限制仅作为非音频行为和解析验证。

Native 最终三套通过：章节 271 项（observed=126，退役 45ms）、洞窟 78 次（observed=12，退役 70ms）、平台 13653 项（observed=21，退役 0ms），全部退出 0、零 ERROR/warning，冻结前后一致。

同一个最终 runner、只撤掉洞窟树内 capture，保留 drain 与非空观察断言：observed=0、retired=12、drain 0ms，断言失败且引擎再次报 ObjectDB warning，进程退出 1。该反向冻结一致，最终源码已按字节恢复。它说明旧退出钩子能枚举播放器（retired=12），但已经观察不到其 playback；树内捕获使 drain 对实际服务器播放引用生效。

这是夹具退场顺序修复，不能推广为所有生产退出、长期内存或完整发布已验收。原始 verbose 的对象身份、非 verbose 失败、没有复现的轮次及诊断均一并保留。每进程限时 180 秒；runner 将全部 warning 当失败，不隐藏日志。APPDATA/XDG 环境只是尽力隔离，不声称 Windows KnownFolder 隔离已被确认：章节/洞窟均是 world_mode=false 的 Main，平台明确使用 world_platform_streaming_validation.json，不读写玩家旅途。
