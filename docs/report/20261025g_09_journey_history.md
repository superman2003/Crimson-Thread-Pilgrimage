# 旧旅途有界分页、身份复核与准确计数

扫描时只保留所需最新归档窗口，单页和偏移有界；读取前执行单份与整页字节预算，前后SHA256确认来源稳定。识别实际写入器的小数时间戳，排除备份／临时旁档及符号链接；仅计真实已访问房间和已知地区，保留受损归档与明确原因。浏览不写盘。

本轮第 9/10 项，独立基于 `main 14dbb91bcd68f3f22029f5ada78dd4843091dbe0`，不依赖其它未合并 PR。生产范围：`godot/scripts/journey_history.gd`。没有编辑共享入口、回归注册表和进度台账。提交前复核开放 PR 的最新文件列表；同轮十组生产文件也互不重叠。

## 验证

Godot 4.6.1：专项 **21 项，0 失败**，headless 与真实 Mesa llvmpipe OpenGL 均通过。生产脚本、数据和专项输入 SHA256 见 `artifacts/upgrade_20261025g/09_journey_history/source_sha256.json`；逐分支独立复验日志随后放在同目录。原有 `save_product` 回归另行通过。全轮叠加运行 `npm test`、`npm run test:campaign` 与两轮资源导入；原有 controller_comfort、world_map、journal_desk、scene_history、world_wayfinding、save_product、ui_world_integration、ui_build_accessibility 回归通过。

复现：

```bash
godot --headless --path godot --script res://tests/upgrade_g09_journey_history.gd
python tools/run_godot_regressions.py --engine godot --suite save_product
```

真实画面（有图时）由同专项设置 `UPGRADE_CAPTURE_DIR` 并使用 OpenGL 运行生成，使用隔离的测试存档／控制器样本，不代表实体手柄或自然流程取得。独立 CI 使用确切 PR head，检查完成标记及引擎错误。远端 CI 以 GitHub 最新提交为准；本批没有完成自然六区通关与46项最终验收。

初轮问题如实记录：地图弹窗查询的 Godot API 不兼容、弱引用类型推断及手册增页造成的旧界面断言失败均已修正；手册最终补入原页面，原有公共夹具未改。最初 GL 音频设备不可用，正式重跑明确选择 Dummy 音频；音频听感不在本批验证范围。
