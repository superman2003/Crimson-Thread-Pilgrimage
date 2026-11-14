## 2026-11-13：实验性 macOS 候选包（T05）

此前导出预设只有 Windows 与 Linux。

- 新增 macOS 导出预设，打包内容与 Linux 相同。架构为通用（Intel 与 Apple 芯片都原生运行）：官方模板只提供通用二进制。通用导出要求开启 ETC2/ASTC 贴图导入，这个项目设置只在构建用的临时副本里打开，不改仓库里的 `project.godot`，Windows／Linux 的导入不受影响。
- `tools/build_macos_candidate.py` 在 macOS 上导出应用、检查应用包结构，再只凭导出的压缩包启动两次（首次与续玩），确认写出旅途存档。
- 发布流程里新增一个允许失败的 `macos` 任务跑这个脚本；Windows／Linux 的候选包门禁没有改动。
- 应用只有引擎内置的临时签名，未公证：下载后首次打开会被系统拦下，需要玩家在“隐私与安全性”里放行。正式分发需要 Apple 开发者证书。

验证：`test_build_macos_candidate.py` 6 项（应用包结构判定、预设与 Linux 打包内容一致、架构与贴图格式匹配）与导出审计（3 个预设）在本机通过。**导出与启动本身没有在本机跑过**（本机不是 macOS，也没有导出模板），是否可用以这个 PR 的 `macos` 任务结果为准。Steam Deck 没有单独处理：它运行的就是 Linux 包。
