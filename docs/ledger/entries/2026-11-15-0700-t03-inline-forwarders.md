## 2026-11-15：删去 148 个只在内部使用的转发方法（T03 代码整理）

拆分时，七个大脚本为每个搬走的方法保留了一行转发，共 935 个（按 main 上当时的状态统计）。这次删掉其中 148 个，调用处改为直接调用新脚本：在原脚本里写成 `新脚本.方法(self, …)`，在被转发到的新脚本里写成 `方法(参数, …)`。

| 原脚本 | 行数 |
|---|---|
| `main_level.gd` | 2509 → 2372 |
| `enemy_actor.gd` | 1213 → 1071 |
| `player_controller.gd` | 1268 → 1204 |
| `pilgrimage_interface.gd` | 997 → 939 |
| `audio_director.gd` | 965 → 922 |
| `build_system.gd` | 706 → 691 |
| `world_region_loader.gd` | 339 → 326 |

新工具 `tools/inline_forwarders.py` 只删同时满足以下条件的转发方法；其余的照旧保留：
- 不是公开方法（以下划线开头），也没有被任何验证子类重写。
- 项目里其他任何文件都没有提到这个名字（验证、工具、场景、数据）。
- 每一处使用都是直接调用：不以字符串形式出现（`callv`、`has_method`），不当作 Callable 引用，也不在别的实例上调用（如 `candidate._x()`）。
- 所有调用都在原脚本，或者就在它转发去的那个新脚本里，所以不会新增 preload，也就不会形成 preload 循环。
- 新脚本的函数签名保留了调用方依赖的默认值；新脚本里没有和目标函数同名的局部变量。

检查：所有改动脚本 `godot --check-only` 无错误；删掉的名字在全项目没有残留引用；`npm run test:ci`、`test:runner`、`test:campaign`、`test:export` 通过；复制脚本的 8 个契约通过。
