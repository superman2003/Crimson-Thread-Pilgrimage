## 2026-11-05：逐招矩阵套件退出前释放音频缓存（T03 子项）

`enemy_move_matrix_late` 合入集成后，在 CI 的 3 次运行里有 2 次在退出时报“1 resources still in use”，而 230 项检查全部通过。原因是 AudioDirector 的静态音频缓存在章节场景释放后仍持有音频资源；其他 49 个 World 套件都会在退出前清掉这份缓存，两个逐招矩阵套件（小怪、Boss；`_mid`／`_late` 继承同一实现）没有。现在按同样方式清空 `_stream_cache` 与 `_npc_voice_cache`，再退出。
