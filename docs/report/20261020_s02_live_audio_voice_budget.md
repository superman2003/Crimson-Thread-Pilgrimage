# S02 补充台账：真实播放器声部预算

原有全局 24 声部按固定 900ms 记账：长音仍在播放却已不占名额；高优先级抢占只移除计数。本批以唯一票据连接实际播放器弱引用，真实结束、停止或退出释放名额；只有未开始的预订保留 900ms 超时。混合 2D／非空间声音、暂停状态和重复使用播放器均在同一预算内。

高优先级抢占实际停止低优先级播放，临时节点释放流并退出，滑墙／心跳／NPC 专用播放器保留以便复用。玩家动作、脚步、滑墙、敌人及死亡尾音、世界／UI 延迟音、跨场景提示、NPC、敌人接敌声、环境单发和契印提示接入票据。音乐与持续环境床继续由专用混音层管理。

Boss／小怪前摇与不可格挡提示列为 P0，普通契印动作音 P2；局部四声部也防止装饰音挤掉危险提示。同 key 最小间隔与并发上限保留；回滚旧票据不会清掉同一毫秒内较新请求的节流记录。声部表不持有节点、流或播放对象的强引用。

验证：`audio_retirement` 新增 46 项真实 WAV／2D／非空间播放检查：跨名义时长占额、24 声部上限、实际抢占、票据不能重用、过期预订、自然结束、同 key 并发／回滚、暂停后停止、专用播放器复用、局部危险提示优先和退休清空。既有总线拓扑 21 项、用户音量 37 项，以及 `seal_presentation`、`enemy_effect_lifetime`、`combat`、`enemy_ai_behavior`、`ui_world_integration` 通过。`PYTHONUTF8=1` 下 `npm test` 通过。证据在 `artifacts/s02_live_audio_voice_budget`。

额外尝试旧 `audio_visual` 未通过：它仍直接加载 main 已不含的 `original_map/moss_cavern/platform_mid.png` 等文件，并访问已移除的 `start_ground` 节点；测试随后停在空节点错误。本报告保留失败日志，不把它计作通过。首次新退休夹具仍持有自己的 WAV 引用，已修正并重跑；编辑过程的 Windows 换行也恢复为仓库规定的 LF 后重跑总线源码锁范围检查。

原生 GL／Dummy 音频驱动证明播放生命周期和配额，不代替最终混音听感验收。

## PR #164 Linux CI 计时修复

`Audio user volume` 与 `Enemy warning readability` 的失败均来自 `audio_retirement`。运行器误把它列入 `--fixed-fps 60` 加速模拟列表：`SceneTreeTimer` 已走完 0.3／1.0 秒时，真实 Dummy 音频混合和 `Time.get_ticks_msec()` 尚未经过相同时长，导致自然播放完成和 900ms 预订过期的断言提前执行。未过期票据随后成功启动循环音，继续持有 WAV，使后面的退休屏障和总线拓扑检查连锁失败。

从加速列表移除 `audio_retirement`，使其使用正常播放计时。保留全部真实播放器断言、退休超时和失败传播；新增运行器回归，通过实际子进程分别检查 headless 与软件 GL 路径均不会传入 `--fixed-fps`。该回归在修复前两条路径均失败，修复后通过。

本次使用 Godot 4.6.1、Linux llvmpipe／Dummy 重放原 CI 参数，复现全部 10 项失败；修复后 `audio_retirement` 的声部 46 项、总线拓扑 21 项、音量 37 项全部通过，四次退休屏障均为 `pending=0`。同次软件 GL 运行的 `input_settings_regression`、`ui_build_accessibility`、`enemy_visibility`、`obsidian_experience` 也通过（共 5 套、0 失败）；headless 单独运行音频套件同样通过。资源导入两遍、运行器 31 项测试、`npm test`、`npm run test:campaign` 和改动文件的 `git diff --check` 均通过。

## 两轮升级组合验证

上一轮 #154–159 与本轮 #160–164 在本地组合后，14 套原生 GL 回归全部通过，覆盖改键、界面、构筑恢复、旧档、对白、音乐恢复、空间接敌声、全局动作／音频预算与战具素材。精确生产提交、日志及范围在 `artifacts/next_five_batch_integration`；此处只提供组合证据，没有在 GitHub 合并 main。组合时保留了 POLICY 和 AUDIO 两个常量；随后把本 PR 的 AUDIO 声明移到声部常量旁，避免与 #155 的插入位置冲突。#161 的 HUD 夹具也已移到打开设置前，避免两批测试互相关闭界面。
