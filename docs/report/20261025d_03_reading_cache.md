# 长篇旅记与对话书签的内存和生命周期

旅记缓存改存文字指纹，避免复制长篇正文；两类书签读取时更新最近使用顺序，失效正文清除旧偏移，限制键和滚动范围，并提供明确的会话清理入口。

本轮第 3/10 批，基于 main `43fbcf88` 独立提交。生产改动：`godot/scripts/journal_reading.gd`, `godot/scripts/dialogue_reading_memory.gd`。未复用其他未合并 PR 的实现或测试改动；未修改共用 main_level、pilgrimage_interface、回归注册表或完成台账。

## 验证

Godot `4.6.1.stable.official.14d19694e`、headless、独立临时工程：仅覆盖本 PR 的生产文件，其他依赖从原 main 逐字读取。新套件 **18 项通过**。在临时工程内按 `mutation.json` 注入一处源代码故障后，同一套件有 **1 项语义断言失败**，无 SCRIPT ERROR；仓库生产源码保持正向版本。原始正反日志与独立输入 SHA256 见 `artifacts/reliability_20261025/03_reading_cache/`。

专用 `.github/workflows/reliability-reading_cache.yml` 包含完整复现命令，安装固定版本引擎，复制明确依赖、执行本套件，检查退出码、引擎错误和完成标记。没有为了通过测试放宽既有门禁。

## 范围

以上是模块与边界行为证据，不是自然剧情通关、完整实机视觉或实体手柄体验证明。现有 46 项最终验收保持 OPEN。没有自动合并或发布发行包。提交前已检查其他 14 个开放 PR 的最新文件列表，本批生产文件无重叠。
