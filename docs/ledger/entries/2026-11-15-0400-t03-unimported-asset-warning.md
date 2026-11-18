## 2026-11-15：本机 ch03 换区回滚查清，套件运行前提醒未导入的素材（T03）

本机 `world_async_loading`、`room_ambience_world`、`interaction_reach` 三项一直在进盐白书库时回滚（“已返回来路”），CI 上却通过。逐个打点后查到原因：角色贴图预热报 `Texture resource does not exist: …/wax_lancer/motion_redraw_01.png`。文件其实在，只是本机从没导入过（缺 `.png.import`），所以运行时读不到，整次换区因此回滚。CI 每次都会先导入，不受影响。重新运行 `tools/run_godot_import.py` 后，三项在本机全部通过。

- `run_godot_regressions.py` 开跑前扫描 `godot/` 下从未导入的图片、音频和字体，发现就打印警告，并提示先运行导入脚本。跳过带 `.gdignore` 的目录和隐藏目录。只警告、不中止。
- `test_regression_runner.py` 增加对应单元测试。
