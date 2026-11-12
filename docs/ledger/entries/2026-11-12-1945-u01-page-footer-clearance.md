## 2026-11-12：构筑页与地图页的页尾说明不再压住边框角饰（U01）

实机截图：构筑页左下的“确认键执行 · Esc 返回”和地图页左下两行（图钉提示、返回／世界总览按键）印在页面边框的红线角饰和下边线上，字被线穿过。

两处都向右移出角饰范围并上移到边线之上：地图页的位置由 `map_control_layout.gd` 的 `STATUS`／`LEGEND` 决定（原先在别处又把宽度改回 965，已删掉那两行），构筑页是固定标签。文字内容、字号不变。

`map_control_layout` 新增检查：两行页尾文字的左边界不小于 150、下边界不越过边线。真实渲染截图确认两页文字完整可读；`map_control_layout` 647 项、`shrine_return` 336 项、`build_slots_ui`、`page_type_scale`、`dialog_dpad_focus`、`map_player_pins`、`map_directory`、`test_ui_type_scale.py` 通过。
