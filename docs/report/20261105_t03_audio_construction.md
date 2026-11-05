# T03：切区音频按预算逐项准备

基于 main `35987a418c9135c1b154c6a1030417cbe9faa7ec`。原切区准备在一个 `_prepare_audio` 作业中初始化总线、导演与用户音量，再加载探索音乐和环境床。本批把它拆为 `_begin_audio`、`_start_audio_explore`、`_start_audio_ambience` 三个原生准备作业，沿用每批最多 8 项及既有时间预算。

每个作业仍在主线程运行，单个初始化或解码不能中途抢占；相邻作业在预算允许时也可同批执行。没有把主线程加载改称后台解码。原 `_prepare_audio`／`_build_audio` 同步入口顺序调用同样三组；`AudioDirector.set_chapter` 仍同步准备身份、探索音乐与环境声。原音轨、总线、循环、音量、淡入与环境声计时规则保留。

## 同机测量

Windows、Godot 4.6.1、NVIDIA RTX 5060、原生 OpenGL。未改的六区 `world_async_loading` 504 项夹具，改前与改后各一个新进程，顺序执行。[原始前后数据](../../artifacts/audio_construction_v13/metrics-comparison.json)。

原音频单项为 **11.758–15.924ms**，拆分后各区最大音频作业为 **5.307–7.284ms**。后者来自初始化；探索音乐单项 1.252–1.944ms，环境声 1.619–2.981ms。数值是 CPU 作业观测，不等于整帧时间、总加载提速或实际帧率。当前组合仍有约 23–28ms 的发布阶段及其它构建／提交任务，T03 保持 OPEN。

## 行为与生命周期

新 `audio_construction` 专项以正式主控制器的准备计划执行六章真实音频，每次最多增加一条解码流。检查两条流实际存在、循环并已启动，完成后的播放器、总线、音量和计时器与同步入口一致。每个夹具释放后用弱引用排空 AudioServer 持有资源。

另用继承正式主控制器的观察夹具启动实际 World，只额外强制开启音频并在三个原方法完成后发观察信号，不替换加载、取消或回滚算法。分别在初始化、探索音乐、环境声后请求取消，观察目的地拥有 0／1／2 条流；断言位置、库存、进度和存档地区恢复，源区重建完整音乐／环境声，目的地导演、流与 playback 的弱引用全部释放。取消仍在原加载器批次边界响应，不承诺信号发出后立即抢占当前批次。

专项原生 GL **108 项**通过。把正式计划临时改回单个同步入口后，90 项中 **12 项准确失败**，无 SCRIPT ERROR；恢复原源码 SHA 后 108 项重新通过。[反向记录](../../artifacts/audio_construction_v13/negative-verification.json)。

五套正式原生门禁覆盖新专项、六区加载、准备预算、原音频退出与声音地标。完整结果见[原生验证](../../artifacts/audio_construction_v13/verification-native.json)。`Dummy` 音频驱动仍创建实际 Ogg/WAV 资源与 AudioServer playback；这些检查不代替音频设备上的人工试听。

新专项无头也为 108 项、零失败；`npm test`、campaign 与 runner 契约通过。Windows runner 35 项中执行 3 项、按平台跳过 32 项；完整 Linux 默认回归交由发布头 CI。

新专项一次原生退出仍出现 ObjectDB warning，实际音频弱引用断言均已排空；额外 verbose 原生记录未复现，但没有据此认定警告已修复。本批不作整包零泄漏结论，当前组合退出边界继续 OPEN。

初版工具误把未注册的旧 `audio_visual` 辅助脚本加入默认列表。它首先读取四张 main 中已不存在的旧地图贴图，随后旧平台节点查询为空，协程抛 SCRIPT ERROR 后未到退出，沿用原 240 秒超时清退拥有的进程树。该脚本本身与 main 一致，缺失路径也经 main blob 查询确认；[失败记录](../../artifacts/audio_construction_v13/legacy-auxiliary-failure.json)及原日志保留，不计成功。本工具的正式默认列表已改为五个已注册套件，后两项另行完成；没有修改旧辅助脚本、注册它或放宽正式门禁。旧辅助夹具兼容性仍待后续整理。

303 个原音频文件逐项比对 main blob／LFS SHA256，全部一致。主控制器 458 个原函数中只改准备计划和音频构造两个函数；导演 100 个原函数中只改 `set_chapter` 的共同准备入口。播放器控制器、NPC 动作与主界面代码均与该 main 相同。[源保留记录](../../artifacts/audio_construction_v13/source-preservation.json)。

新专项进入默认回归，211→212，并加入既有目录／启动准备 CI 的软件 GL 门禁。物品预热 #539 与设置拆分 #540 为独立待审升级，合并时保留各自新增专项。自然连续帧时间、初始化／发布其它尖峰、当前组合整合长跑及发布包退出仍需继续验收。
