# 素材源图交付

已保存 **10／52 张、60／320 格**。通过内置 imagegen 按 [PR #202](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/202) 制作；原始 PNG 字节保持不变，未缩放、重排或切帧。尚未接入游戏。

每张附实际使用的提示词 `.txt` 与检查记录 `.json`。实际图幅可能与提示词要求不同，按检查记录的 `frames[].rect_xyxy` 切格；锚点对齐、警戒范围、光束接缝和实机缩小后的辨识度继续待验收。完整进度见 [delivery_status.json](delivery_status.json)。

- [FX_H2_guard_raise.png](FX_H2_guard_raise.png) — 格挡起手／护幕，6 格；[实际提示词](FX_H2_guard_raise.txt)、[检查记录](FX_H2_guard_raise.json)，`source_reviewed_runtime_pending`。
- [FX_H2_guard_block.png](FX_H2_guard_block.png) — 普通挡击，6 格；[实际提示词](FX_H2_guard_block.txt)、[检查记录](FX_H2_guard_block.json)，`source_reviewed_runtime_pending`。
- [FX_H2_guard_perfect.png](FX_H2_guard_perfect.png) — 完美格挡，6 格；[实际提示词](FX_H2_guard_perfect.txt)、[检查记录](FX_H2_guard_perfect.json)，`source_reviewed_runtime_pending`。
- [FX_T_moss_roots.png](FX_T_moss_roots.png) — 苔钟守母·根冠苏醒预警，6 格；[实际提示词](FX_T_moss_roots.txt)、[检查记录](FX_T_moss_roots.json)，`source_reviewed_runtime_pending`。
- [FX_T_shears_thread.png](FX_T_shears_thread.png) — 绯线执剪者·绯线封路预警，6 格；[实际提示词](FX_T_shears_thread.txt)、[检查记录](FX_T_shears_thread.json)，`source_reviewed_runtime_pending`。
- [FX_T_shears_knots.png](FX_T_shears_knots.png) — 绯线执剪者·断线结阵预警，6 格；[实际提示词](FX_T_shears_knots.txt)、[检查记录](FX_T_shears_knots.json)，`source_reviewed_runtime_pending`。
- [FX_T_bishop_roots.png](FX_T_bishop_roots.png) — 铜根主教·循地根刺预警，6 格；[实际提示词](FX_T_bishop_roots.txt)、[检查记录](FX_T_bishop_roots.json)，`source_reviewed_runtime_pending`。
- [FX_T_bishop_cage.png](FX_T_bishop_cage.png) — 铜根主教·交错根笼预警，6 格；[实际提示词](FX_T_bishop_cage.txt)、[检查记录](FX_T_bishop_cage.json)，`source_reviewed_runtime_pending`。
- [FX_T_bride_pools.png](FX_T_bride_pools.png) — 镜池新娘·镜池迟影预警，6 格；[实际提示词](FX_T_bride_pools.txt)、[检查记录](FX_T_bride_pools.json)，`source_reviewed_runtime_pending`。
- [FX_T_key_gate.png](FX_T_key_gate.png) — 百钥看门人·冠门封线预警，6 格；[实际提示词](FX_T_key_gate.txt)、[检查记录](FX_T_key_gate.json)，`source_reviewed_runtime_pending`。

使用 `python -X utf8 art_requests/combat_presentation_v2/inspect_sources.py` 更新检查记录；加 `--check` 可校验记录未漂移。检查脚本只读取图片，不修改像素。逐张预写任务提示词在 `../prompts/`；不要混入 v1 已交付的 39 张。
