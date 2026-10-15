# T05：桌面候选包与发布检查

> 文档状态校准（2026-10-15）：本文维护候选包工具合同；下方2026-10-14包、71套和具体run是历史证据，不替PR #67运行时认证。最新代码须按同一流程重新构建、解压启动与读档写回，以包内BUILD_MANIFEST记录的提交为准；当前还未取得新版本双平台最终包验收结论。

本 PR 完成 Windows / Linux x86_64 的独立打包、最终 ZIP 校验、解压启动和读档写回检查，接入双平台原生 CI。范围属于 `docs/SILKSONG_ALIGNMENT_REVISED_PLAN.md` 的 T05 发布工具；自然通关、实机手柄和混音仍按人工验收记录处理。

## 打包与验证流程

1. 检查 World 入口、章节配置、动态 JSON、许可和玩家说明；拒绝未水合 LFS 指针、受限目录与符号链接。
2. 在临时工程中导入和 release 导出，只移除编辑器插件激活配置，保留运行时 autoload、插件类和 UID。
3. 收集项目、素材、字体、插件及固定 Godot 引擎的许可；为每个随包文件生成大小和 SHA256 清单。
4. 删除临时工程后生成 ZIP；校验 ZIP 的外部 SHA256、文件列表及清单中的每个文件，不允许重复、额外或越界成员。
5. 删除原始导出目录，把最终 ZIP 解压到一个新目录，恢复 Linux 可执行权限，从解压包启动实际 release 二进制。用户数据、设置、缓存与工作目录全部隔离，不传源码 `--path` 或测试脚本。
6. 首次启动必须生成有效旅途记录。在临时存档加入无游戏作用的探针标记，并删除首次启动留下的备份；重启必须保留标记，且产生包含标记的新 `.bak`，证明实际执行了读档后的写回。第二次启动仅留下原存档不动会被拒绝。
7. 验证通过后才把 ZIP 与 `.sha256` 复制到输出目录；失败保留日志，不交付未验证的 ZIP，不覆盖旧候选或校验文件。

所有引擎命令都有超时；非零退出与 ERROR、SCRIPT ERROR、Parse Error、USER ERROR 均失败，包括 ANSI 着色错误。构建清单记录源提交、dirty 状态、引擎、目标平台与具体验证范围。

运行时控制器、World、存档格式、输入设置和现有游戏回归脚本均不由本 PR 修改。候选包工作流只上传构建与日志，不创建公开 Release、打标签或部署。唯一生效工作流是 `.github/workflows/release-candidate.yml`，旧的 tools 工作流草案已移除。

## 使用

需要 Python 3.10+、Git / Git LFS、Godot **4.6.1 stable** 和匹配的 release export template。在目标操作系统构建，以实际可执行文件验证该平台。

```sh
git lfs pull --include='godot/**'
python tools/test_release_builder.py
python tools/build_release.py --check
python tools/build_release.py --target linux --engine /absolute/path/to/godot --output dist/releases
# Windows 上运行：
python tools/build_release.py --target windows --engine C:/Godot/Godot_v4.6.1-stable_win64.exe --output dist/releases
```

`--check` 只检查输入。实际游戏包不要求玩家安装 Godot。失败后保留日志，修正原因并使用新的输出目录重试。建议使用 clean checkout；本地改动会如实记录为 `source_dirty=true`。

## 已核实的验证证据（2026-10-14）

| 检查 | 已核实结果 |
|---|---|
| 原分支完整 CI | `c2afa0a0039d9e617a6b882befccc24b7866e521` 的三个检查均成功 |
| Linux 原生导出、首次启动、重启 | [桌面构建 run 38539036007](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38539036007)，Linux job 115768949429 成功 |
| Windows 原生导出、首次启动、重启 | 同一 run 的 Windows job 115768949057 成功；不是 Linux 交叉导出 |
| 完整游戏回归 | [run 38539035956](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38539035956)：71 套回归零失败，资源导入与后续 GPU 探针通过 |
| 本次工具负面测试 | 20 项通过；新增不读不写的假重启、无关备份、ZIP 损坏、内部文件损坏和额外/越界成员检查 |
| 本次真实 ZIP 解压验证 | 对上述 CI 的 Linux ZIP 校验 23 个随包文件，再启动解压出的二进制；首次保存、保留探针与生成新备份均通过，无引擎错误 |

原 CI 包测试的是合并预览提交 `db3d963ee4673b13722e02601903969843e29a81`，不是分支头提交。Linux 清单中的 `source_dirty=true` 保持原样，不把此包称为 clean release。本次在本地对该既有二进制复核了加强后的包校验及读档门禁；更新后的双平台完整重建由新一轮 CI 验证，旧 run 的成功不等同新提交已通过 CI。

此前本地开发构建 `3fbfd20` / 远端等价树 `c049a99` 的 Linux 导出和启动记录属于旧版本证据，不再作为当前 Windows 或最终解压门禁的通过证明。

## 玩家交付与验收边界

随包 `README.md` 来自 `docs/RELEASE_PLAYER_GUIDE.md`，包含解压启动、操作设置、存档位置、问题入口和限制；`licenses/` 保留各类许可，代码 MIT 不替代素材条款。

- 自动门禁验证打包、启动、保存和重启写回；不等同六区自然带伤通关、全部结局或实机手柄体验。
- 正常尺寸视觉、混音和所有素材的完整原创来源复核仍需独立验收。
- 转为正式 PR 表示可供代码审查；游戏仍是开发中的候选版本。

## 技术依据

- Godot 4.6 导出：https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html
- Godot 4.6 CLI：https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html
- 固定引擎与校验清单：https://github.com/godotengine/godot/releases/tag/4.6.1-stable
