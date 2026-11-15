## 2026-11-15：六个 Python 生成工具按职责拆成模块（T03 代码整理）

素材与地图生成工具里最大的六个拆成主流程加若干模块。函数原样搬走，原文件用 `from 模块 import (…)` 显式导回，所以命名空间和导入它们的脚本都不变。

| 工具 | 行数 | 新模块 |
|---|---|---|
| `build_small_enemy_runtime_assets.py` | 2182 → 533 | `small_enemy_frames`、`small_enemy_poses`、`small_enemy_reviews` |
| `generate_music_pack.py` | 1800 → 317 | `music_dsp`、`music_region_tracks`、`music_story_tracks` |
| `generate_ambience_pack.py` | 1597 → 365 | `ambience_dsp`、`ambience_beds`、`ambience_cues` |
| `build_silksong_scale_map_blueprints.py` | 1355 → 601 | `blueprint_rendering`、`blueprint_data` |
| `generate_sfx_pack.py` | 1088 → 279 | `sfx_dsp`、`sfx_recipes` |
| `blueprint_to_godot_runtime.py` | 1006 → 311 | `blueprint_runtime_parts` |

- 新工具 `tools/split_python_module.py`：给定函数名，把它们连同依赖到的顶层函数、类、常量和所用的导入一起搬走；读 `globals()`、用 `global` 的定义或被保留名依赖的定义会直接报错。
- 核对：分别加载拆分前后的模块，逐个比较原模块里的每个名字。454 个函数的字节码或语法树一致，常量值一致：`PACK` 里的函数引用按名字比较；`CHAPTERS` 里由 `__file__` 推出的路径按所在目录比较。
