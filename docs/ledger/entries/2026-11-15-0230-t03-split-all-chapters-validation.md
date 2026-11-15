## 2026-11-15：全章节验证脚本拆分（T03 代码整理）

`all_chapters_demo_validation.gd` 1013 → 448 行。章节差异、视觉与首领清单检查搬到 `chapter_uniqueness_checks.gd`，房间、落点、地面、出口与多层布局检查搬到 `chapter_route_checks.gd`。原脚本保留同名转发方法和每章主流程 `_validate_chapter`。

拆分前后各跑一次 `all_chapters_demo`：2190 条检查结果逐行相同，无失败。

`world_second_order_playback.gd`（969 行）不拆：`verify_second_order_crown.py` 会冻结它的源码快照，用来核对既有证据。
