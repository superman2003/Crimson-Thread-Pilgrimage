# T03／T05：真实编辑器冷启动与退出资源所有权

新增八批第8批。在不使用 recovery mode、不用运行时 `--script` 替代的正常 headless 编辑器中，MetSys 原插件在首次扫描未结束时按 UID 加载数据库：原 main `93365331bc8d0bcf588244c2000c43df7be16f04` 的插件原字节 SHA 与 baseline 一致，冷项目退出0却有53条引擎/脚本错误，未完成初始化。

插件现在逐帧检查 EditorFileSystem.is_scanning()，扫描完成后只初始化一次，并以明确资源路径加载主面板；提前收到可见性/布局回调会保留请求，有限 Vector2 偏移在面板就绪后应用。退出时先释放属于编辑器主屏的面板，注销菜单/命令/翻译并清空单例的插件引用。未初始化退出不注销未注册菜单。

仅释放主面板不足以解决泄漏：编辑器扩展将工具栏 Button 移出容器却没释放，孤立按钮继续持有主题、字体与排版资源。扩展现明确释放自有按钮，并断开预览信号和清空引用。最初 await 逐帧等待又在立即退出时留下9个资源，因此改成 `_process` 扫描轮询，避免悬挂协程。

| 最终检查 | 结果 |
| --- | --- |
| 正常冷编辑器；全新 `.godot`、私有用户/配置/缓存目录 | ready=1，exit0，ERROR=0，资源残留告警=0 |
| 同一项目暖启动 | ready=1，exit0，ERROR=0，资源残留告警=0 |
| 同一项目 `--quit-after 1` 提前退出 | ready=0，exit0，ERROR=0，资源残留告警=0 |
| 撤去按钮 free 的实际负例 | ready=1且exit0，但4条ERROR及2条资源残留告警；门正确拒绝 |
| 输出判定契约／原集成workflow结构守护 | 6／6项通过 |
| 最终真实GL运行时组合 | metsys、ui_world_integration、build_slots_ui54、map_player_pins161通过 |
| 完整 `npm test`／`npm run test:campaign` | 均exit0 |

`tools/test_metsys_cold_import.py` 将真实 addon、真实 MetSysSettings/MapData 和最小启用项目复制到临时目录，不复制导入缓存；保存每项原输入SHA与完整输出。冷/暖各240帧，提前退出1帧，每进程90秒上限。严格检查退出码、独占整行ready、所有ERROR及资源残留告警。提前退出允许0或1次ready，普通启动要求恰1次。Godot4.6.1，实际headless编辑器而非GUI视觉验收。

独立检查接入原Godot runtime CI的recovery导入之前；两条原集成作业、所有原运行时/像素命令与时间预算保留。CI补拉addon LFS纹理。桌面发布PR分支匹配增加 `codex/**`，让依序串接的升级也运行原Windows/Linux打包门；打包逻辑和权限不变。

完整证据见 `artifacts/t03_editor_cold_start/README.md`。修复前尝试GL编辑器时当前环境Vulkan surface扩展不可用，失败保留，不算GL编辑器通过。最终四套GL运行时没有ERROR；其中既有metsys组件仍有ObjectDB退出warning，单列而不归为本次编辑器修复已解决。正常headless VSync或提前退出扫描中止提示保留。此批未验证完整大项目无缓存GUI编辑器、所有编辑功能、实体桌面退出或发行包最终验收，T03/T05及全部46项最终验收保持OPEN。
