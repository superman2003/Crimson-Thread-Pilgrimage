## 2026-11-26：CI 预算对齐、发布版免伤加固与产物清理工具（T03 子项）

将 `material-conversion-plan-wip.yml` 整理为 `material-conversion-plan.yml`，清理该工作流与 `settings-dialog-layout.yml` 的过期 WIP 分支监听，并将两者的冷资源导入超时统一对齐到 900 秒、任务上限调整为 30 分钟，修复近期 `main` 推送的冷导入超时失败。

`player_damage.gd` 限制 `debug_invulnerable` 仅在 Godot debug/editor 构建生效，防止发布版误启用。新增 `tools/ci/prune_unreferenced_artifact_logs.py` 及专项单元测试，在清理未引用诊断日志时一并保护 CI/验证脚本目录、文档路径前缀、`artifacts/**/*.json` 证据引用和动态路径模板，并显式使用 UTF-8 解码。
