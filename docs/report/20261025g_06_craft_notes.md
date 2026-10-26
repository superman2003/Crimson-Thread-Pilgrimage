# 六区旧物工艺细读与巡礼者手记

六件既有日常旧物各增加近看工艺与巡礼者手记两层细读。通过同一生产条目进入现场阅读和已发现旅记，保留原地点、物件、证词与发现条件；返回快照独立，读物不发放成长或物资。

本轮第 6/10 项，独立基于 `main 14dbb91bcd68f3f22029f5ada78dd4843091dbe0`，不依赖其它未合并 PR。生产范围：`godot/scripts/scene_history.gd`, `godot/data/scene_craft_notes.json`。没有编辑共享入口、回归注册表和进度台账。提交前复核开放 PR 的最新文件列表；同轮十组生产文件也互不重叠。

## 验证

Godot 4.6.1：专项 **45 项，0 失败**，headless 与真实 Mesa llvmpipe OpenGL 均通过。生产脚本、数据和专项输入 SHA256 见 `artifacts/upgrade_20261025g/06_craft_notes/source_sha256.json`；逐分支独立复验日志随后放在同目录。原有 `scene_history` 回归另行通过。全轮叠加运行 `npm test`、`npm run test:campaign` 与两轮资源导入；原有 controller_comfort、world_map、journal_desk、scene_history、world_wayfinding、save_product、ui_world_integration、ui_build_accessibility 回归通过。

复现：

```bash
godot --headless --path godot --script res://tests/upgrade_g06_craft_notes.gd
python tools/run_godot_regressions.py --engine godot --suite scene_history
```

真实画面（有图时）由同专项设置 `UPGRADE_CAPTURE_DIR` 并使用 OpenGL 运行生成，使用隔离的测试存档／控制器样本，不代表实体手柄或自然流程取得。独立 CI 使用确切 PR head，检查完成标记及引擎错误。远端 CI 以 GitHub 最新提交为准；本批没有完成自然六区通关与46项最终验收。

初轮问题如实记录：地图弹窗查询的 Godot API 不兼容、弱引用类型推断及手册增页造成的旧界面断言失败均已修正；手册最终补入原页面，原有公共夹具未改。最初 GL 音频设备不可用，正式重跑明确选择 Dummy 音频；音频听感不在本批验证范围。
