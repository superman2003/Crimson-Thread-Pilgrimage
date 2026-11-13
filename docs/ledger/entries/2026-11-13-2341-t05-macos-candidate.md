## 2026-11-13：实验性 macOS 候选包（T05）

此前导出预设只有 Windows 与 Linux。

- 新增 macOS 导出预设，打包内容与 Linux 相同。架构为 x86_64：项目贴图是 S3TC 格式，通用（含 Apple 芯片原生）构建需要把全部贴图另导入一份 ETC2/ASTC，本次不做；Apple 芯片的 Mac 通过 Rosetta 运行。
- `tools/build_macos_candidate.py` 在 macOS 上导出应用、检查应用包结构，再只凭导出的压缩包启动两次（首次与续玩），确认写出旅途存档。
- 发布流程里新增一个允许失败的 `macos` 任务跑这个脚本；Windows／Linux 的候选包门禁没有改动。
- 应用只有引擎内置的临时签名，未公证：下载后首次打开会被系统拦下，需要玩家在“隐私与安全性”里放行。正式分发需要 Apple 开发者证书。

验证：`test_build_macos_candidate.py` 6 项（应用包结构判定、预设与 Linux 打包内容一致、架构与贴图格式匹配）与导出审计（3 个预设）在本机通过。**导出与启动本身没有在本机跑过**（本机不是 macOS，也没有导出模板），是否可用以这个 PR 的 `macos` 任务结果为准。Steam Deck 没有单独处理：它运行的就是 Linux 包。
