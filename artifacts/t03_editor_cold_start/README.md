# T03 编辑器证据索引

`final_verified/` 为最终代码在私人用户/配置/缓存目录的三阶段真实 headless 编辑器检查；`runtime_gl/` 为最终代码的四套真实 GL 运行时检查。两者不能互换。

`baseline/` 原 main 插件 53 错误；`current/` 仅扫描等待/显式路径修复，仍有4退出错误；`immediate_free/` 仅及时释放主面板仍失败；`verbose/` 定位孤立 Button；`empty_dummy.log` 空编辑器无泄漏，否定 Dummy 后端必然泄漏假说。`gl/` 是修复前尝试真实 GL 编辑器的失败诊断，Vulkan surface 扩展不可用，不算通过。`owned_exit/`、`final/` 是两阶段中间结果；`final_three/` 加入立即退出后失败；`polled_exit/` 改为逐帧扫描检查后通过。各阶段保留当时的完整输出/结果，不回填成最终版本。

`no_button_free/` 为最终逐帧版插件撤销按钮释放的负例（严格门仍拒绝）；复现命令从仓库根运行 `python artifacts/t03_editor_cold_start/button_retirement_negative.py`，脚本在 finally 原字节恢复源码，使用本机引擎路径，需按环境调整。

最终检查允许正常的 headless VSync/提前退出 Scan thread aborted 提示；任何引擎 ERROR、ObjectDB/RID/资源残留告警均失败，退出码0或READY标记不能掩盖错误。运行时 metsys 组件的历史 ObjectDB warning单列，未被此编辑器修复消除。

`release_gate_scope_fix_ci_failure.log` 为整合main后旧广匹配触发23项发布测试中2项失败的原始CI日志；`release_gate_scope_fix_pass.log` 为收窄八个具体分支后的23项通过。该修正的workflow/test输入SHA另记于release_gate_scope_fix.json，不能用旧inputs_sha256.json冒充新workflow字节已测。
