# S01：正式 World 在释放音频前保存探索曲进度

六区生命周期压力夹具发现，独立 AudioDirector 的续播测试虽通过，正式 World 跨区时却始终没有音乐书签：MainLevel 先递归停止播放器并置空 stream，Director 退树时已经无法读取播放位置。

本批在 `_release_region_audio()` 的停止边界之前捕获当前 Director 的乐句位置，沿用现有会话代际、所有者检查和八项数值缓存。原停止、资源释放、总线复位与新旅途清理规则保留。回归扩到真实 World 的实际探索播放器：推进至第七秒，调用生产释放入口，检查书签和再次播放后的进度，并验证音频原生资源最终退出。

先加回归、未修生产代码时，两项正式 World 断言失败；修复后六套真实 GL 通过：audio_retirement（音乐续播 15 项及原音频/音量检查）、world_enemy_residency 56、world_resume_regression 38、world_death_cache_flush 27、input_prompt 36、save_product 37。Godot 4.6.1，原始日志分别在 `artifacts/s01_world_music_before` 与 `artifacts/s01_world_music_retirement`，不以重跑掩盖原失败。

三个既有 World 套件退出仍有 ObjectDB warning，保留为 T03 待查；此次不声称全程稳定、人工实听或自然六区通关已完成。长时压力运行另行记录。
