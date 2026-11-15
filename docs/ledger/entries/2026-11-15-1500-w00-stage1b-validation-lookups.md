## 2026-11-15：W00 阶段 1b——验证与工具改走 level_host（行为不变）

接 1a。验证、回放和工具脚本里原先直接在关卡宿主上按名字取节点、遍历子节点，或用父节点判断归属；这次全部改走 `level_host.gd`，为 1c 把区域节点挪进 `RegionRoot` 做准备。

- **范围**：123 个文件，308 处，由脚本一次改写。
- **改写方式**：
  - `get_node_or_null`、`get_node` 改为 `LEVEL_HOST.find`；`has_node` 改为 `LEVEL_HOST.find(...) != null`。
  - `get_children`、`get_child_count`、`get_child` 改为 `LEVEL_HOST.children`。
  - `x.get_parent() == 宿主` 改为 `LEVEL_HOST.owns`。
- **为什么不改变行为**：这些辅助函数对不是关卡宿主的对象（对话框、提示框之类）会退回原来的写法；容器也还是空的。
- **契约**：会把验证脚本复制到临时工程的三个契约（成就、危险提示 r08、视觉归属）的复制清单补上了 `level_host.gd`。
- **检查**：
  - 改写过的脚本全部 `--check-only` 通过。去掉了 4 个子类里与父类重复的常量。
  - 上面三个契约分别通过 49、7、27 项。
  - `test:ci`、`test:runner`、`test:campaign`、`test:export` 通过。
  - 受影响的 77 个 Godot 套件以本次 CI 为准。
