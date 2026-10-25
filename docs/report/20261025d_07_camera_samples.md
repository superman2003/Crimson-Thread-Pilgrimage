# 镜头观察和跟随的异常采样恢复

无效位置不再污染持久跟随基线，观察方向、强度与时间取有效范围；缺失镜头不会部分重置状态。覆盖窗口尺寸变化、场地限制和30/60/120Hz正常跟随。

本轮第 7/10 批，基于 main `43fbcf88` 独立提交。生产改动：`godot/scripts/camera_focus.gd`。未复用其他未合并 PR 的实现或测试改动；未修改共用 main_level、pilgrimage_interface、回归注册表或完成台账。

## 验证

Godot `4.6.1.stable.official.14d19694e`、headless、独立临时工程：仅覆盖本 PR 的生产文件，其他依赖从原 main 逐字读取。新套件 **15 项通过**。在临时工程内按 `mutation.json` 注入一处源代码故障后，同一套件有 **1 项语义断言失败**，无 SCRIPT ERROR；仓库生产源码保持正向版本。原始正反日志与独立输入 SHA256 见 `artifacts/reliability_20261025/07_camera_samples/`。

专用 `.github/workflows/reliability-camera_samples.yml` 包含完整复现命令，安装固定版本引擎，复制明确依赖、执行本套件，检查退出码、引擎错误和完成标记。没有为了通过测试放宽既有门禁。

## 范围

以上是模块与边界行为证据，不是自然剧情通关、完整实机视觉或实体手柄体验证明。现有 46 项最终验收保持 OPEN。没有自动合并或发布发行包。提交前已检查其他 14 个开放 PR 的最新文件列表，本批生产文件无重叠。
