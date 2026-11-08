# 缄 · 缠线小偶完整动作源

默认 Player 已改用 `godot/assets/sprites/player/thread_doll_v1/manifest.json`，不是可选皮肤或概念预览。实际覆盖 32 个状态，包含移动、转身、所有方向攻击、技能、战具、壁滑、钩索、治疗、格挡、受击、死亡及复生衔接。

素材由内置 image_gen 绘制。`generation_manifest.json` 记录源图、实际提示词、哈希与逐帧裁剪区域。`a/b/e/f/g/h/j/k/l/m` 是选中的十张源表；`c/d/i` 是保留的早期方案，长针刃版 `k/l/m` 修正了缝锥与原战斗距离的视觉关系，`j` 独立提供八张跑步上身。跑攻八张中选用六张，另外两张及旧上身草案不计作运行帧。

最终接入 172 张独立绘图：164 张完整身体动作、8 张跑步上身。`jump_start`/`jump`、`land`/`landing` 只共享同一动作的别名，不计新增绘图。两只跑步短足使用同一个真实脚部裁片，固定长度与尺寸，脚点由距离相位驱动，支撑时抵消身体位移。八张上身、重心曲线和布尾变化共同表现跑动。

`python tools/build_thread_doll.py` 只执行透明轮廓隔离、每张源表固定缩放、裁剪与定位，不制造补帧。锚点分别来自实际脚底、眼部亮缝、胸口线结和缝锥金属尖端；向下的针刃不能代替脚底作为落脚点。`--check` 复核全部源文件哈希、输出像素与清单。原人形素材及构建器作为历史源保留，不能改变默认小偶清单；发布包排除旧人形资源和运行脚本。

短足骨架：[thread_doll_run_cycle.gd](../../godot/scripts/thread_doll_run_cycle.gd)。原生渲染验证：`python tools/check_thread_doll_native.py --engine <Godot 4.6.1 executable>`。动作图册与第一章实机录像见 [artifacts/thread_doll_v1](../../artifacts/thread_doll_v1/)。固定 60Hz 捕获用于审阅动作，不作为真实帧时间性能证明。
