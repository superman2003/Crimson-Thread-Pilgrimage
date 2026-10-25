# I20 · 旅途分享卡

明确白名单分享预览、默认条目计数/日期、常见路径与凭证格式过滤、CTP1校验码。

## 游戏内入口

Godot 的 World → 设置 → 旅途工作台 → 旅途分享卡。当前分析可建立编辑候选；显式保存后写入分槽辅助记录，可在记录库比较、编辑、收藏和导入导出。分享卡使用专用字段白名单导出。

## 范围和依赖

基于 I19（旅途快照差异），需先合并前序 PR；本 PR 包含分享功能新增文件，以及本批共用记录库的导入序号上限修复。 新增路径位于 `godot/journey/fieldwork/`、`godot/journey/features/i_*.gd` 及各自测试/CI，未改动 Player、main_level 或其它 agent 的现有文件。发布前已核对 46 个开放 PR 的文件路径，新增路径零重叠；这是路径层面的检查，不是其它未合并分支的完整组合运行验收。

本 PR 新增生产 GDScript **590 行**，按非空、非注释行计数，不计测试、文档、日志、UID、工作流及父 PR 已引入的代码。

## 验证

- Godot 4.6.1，当前累计前缀（#313 + I01 至本项）独立目录运行本项无界面测试，通过；前缀中不含后续模块。
- 本项 OpenGL Compatibility / Mesa llvmpipe 测试通过，覆盖实际原生控件构建、候选写入失败与重试、辅助 JSON 回读、撤销重做、同槽导入/去重和主数据/InputMap 不变。
- 算法用人工已获条件夹具覆盖，数据结构取真实地图、配方及构筑目录；夹具不等于自然游玩通关。
- 完整 I01–I20 组合实际 World：无界面与 OpenGL 均 29 项检查通过，21 个工作台模块打开，资源/构筑与主档不变；完整会话生命周期各后端 33 项检查通过。I12 附会话日志，I20 附组合 World/导出与截图，I01 附仓库检查日志。
- 两次资源恢复模式导入通过；该模式不验收编辑器插件行为。首次 GL World 加载触发原有 15 秒门槛，保留失败日志，导入后串行复测通过，未放宽门槛。仓库 npm 首轮有既有导入超时日志测试失败，保留初次日志，串行完整复测结果见 I01 的 npm-final.log。

复现本项：

```sh
python3 tools/run_fieldwork_tests.py --engine /path/to/Godot_v4.6.1-stable_linux.x86_64 --module i_20_share_cards --backend headless --log-dir /tmp/fieldwork-headless
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a python3 tools/run_fieldwork_tests.py --engine /path/to/Godot_v4.6.1-stable_linux.x86_64 --module i_20_share_cards --world --backend gl --log-dir /tmp/fieldwork-gl
```

## 实际边界

每类最多40项；过滤不是普遍隐私保证，校验码不是签名/加密；不会自动发送或上传。 未验证真实手柄硬件、Windows/macOS 原生窗口或六区自然流程全通关。CI 工作流已配置；本地日志不代表远端 Actions 已通过。

证据：[`artifacts/fieldwork_20261025i/20-share_cards`](../../artifacts/fieldwork_20261025i/20-share_cards)。


## 发布前的导入边界修复

共享记录库在序号已到100000000时，原合并流程仍尝试追加并访问新记录。现在在追加前检查序号上限，完整拒绝该候选；一批导入中途用尽序号时，也不发布部分记录。I20新增两个回归检查：空库序号已满，以及第二条记录才越界，两种情况均保留原数据。I20定向无界面/OpenGL各26项检查通过。新增生产代码行数仍按本项新文件计，共享文件修改不重复计入。

组合实际World、PCK和截图来自此边界补丁之前的提交 `b340a395cb84c93661a345b1a4e0cfde8627630b`；本次补丁没有更改资源引用、导出布局或会话流程。`pre-boundary-source_sha256.json`保留原校验，当前`source_sha256.json`记录最终源码（含共享修复）的校验。PCK日志证明原组合可打包、发现21项并排除测试，不能视为最终补丁后重新打包的字节证明。
