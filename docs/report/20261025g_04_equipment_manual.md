# 十种线术战具使用札记与实时改键说明

为六种线术、四种战具补齐朝向、起手、落点、后续危险和补给说明，按类别补入原有针击／钟龛手册页面。只公开初始装备和持有有效正整数遗物的条目，使用当前改键；资源费用继续参考真实HUD，不写死构筑数值。

本轮第 4/10 项，独立基于 `main 14dbb91bcd68f3f22029f5ada78dd4843091dbe0`，不依赖其它未合并 PR。生产范围：`godot/scripts/field_guide.gd`, `godot/scripts/equipment_field_notes.gd`, `godot/data/equipment_field_notes.json`。没有编辑共享入口、回归注册表和进度台账。提交前复核开放 PR 的最新文件列表；同轮十组生产文件也互不重叠。

## 验证

Godot 4.6.1：专项 **43 项，0 失败**，headless 与真实 Mesa llvmpipe OpenGL 均通过。生产脚本、数据和专项输入 SHA256 见 `artifacts/upgrade_20261025g/04_equipment_manual/source_sha256.json`；逐分支独立复验日志随后放在同目录。原有 `ui_world_integration` 回归另行通过。全轮叠加运行 `npm test`、`npm run test:campaign` 与两轮资源导入；原有 controller_comfort、world_map、journal_desk、scene_history、world_wayfinding、save_product、ui_world_integration、ui_build_accessibility 回归通过。

复现：

```bash
godot --headless --path godot --script res://tests/upgrade_g04_equipment_manual.gd
python tools/run_godot_regressions.py --engine godot --suite ui_world_integration
```

真实画面（有图时）由同专项设置 `UPGRADE_CAPTURE_DIR` 并使用 OpenGL 运行生成，使用隔离的测试存档／控制器样本，不代表实体手柄或自然流程取得。独立 CI 使用确切 PR head，检查完成标记及引擎错误。远端 CI 以 GitHub 最新提交为准；本批没有完成自然六区通关与46项最终验收。

初轮问题如实记录：地图弹窗查询的 Godot API 不兼容、弱引用类型推断及手册增页造成的旧界面断言失败均已修正；手册最终补入原页面，原有公共夹具未改。最初 GL 音频设备不可用，正式重跑明确选择 Dummy 音频；音频听感不在本批验证范围。

首次额外 World 拍摄触发原有15秒出版边界超时；保持原时限，增加失败传播检查后独立重跑通过，实际旅记内容和滚动区两项检查也通过（拍摄运行45项）。首次超时日志与最终拍摄日志均保留。
