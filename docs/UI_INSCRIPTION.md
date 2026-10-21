# 缝名刻印：字体与界面

2026-10-21，第二版。根据参考图重新制作字体美术和纸面材质，并接入 Godot 实际游戏界面，包含 HUD、契印、行囊、旅记、地图、设置和对话。全局文字的一键替换、检查和还原见 [GLOBAL_FONT.md](GLOBAL_FONT.md)。

## 字体与字标

- 大标题：六组透明 PNG 字标，包含「绯线巡礼、契印、行囊、旅记、地图、设定」。第二版直接参考原图的尖锐断笔、旧骨材质、穿线孔和朱红连接线。第一版 SVG 字标保留作历史资源。
- 所有实时文字：`godot/assets/fonts/GlobalTypeface.otf`，默认是「缝名刻宋 / Feng Ming Inscription」。菜单、正文、地点、数字、对话、小字提示全部统一，不保留原先正文黑体的例外。
- 新建控件：继承项目默认字体主题；地图仍使用同一字库的 MSDF 缓存，字幕大小和速度设置保留。

这是派生字体、项目专用字标和 UI 组件的实现；缝名刻宋在开源宋体的曲线字形上加入斜向刻痕，并非从零绘制的完整中文字库。字体遵循 SIL OFL 1.1，随附许可证与来源指纹，见 `THIRD_PARTY_NOTICES.md` 和 `godot/assets/fonts/FengMingInscription.json`。

字标与字体可用以下命令重新生成，需要 fontTools 和上游原始 OTF：

```powershell
python tools/build_inscription_assets.py path/to/NotoSerifCJKsc-Regular.otf
python tools/build_inscription_font.py
python tools/apply_global_font.py apply
```

## 界面语言

墨青底、骨白字、旧铜细框、绯红焦点、苔绿辅助色。切角按钮以红线、菱形结点和针形标记反馈悬停、键盘／手柄焦点与选中状态；禁用项降低对比。

生命值为红线串联的骨白名牌，失去的生命显示空牌与裂纹；濒死时剩余名牌转红边。能量保留细条和数值。面板沿用现有 1280×720 设计坐标与等比适配，铜框、缝线和罗盘由 Godot 在 UI 比例下绘制。旅记分类自动切换到「旅记」字标。

地图沿用现有购图、补绘、迷雾、图钉、缩放和平移逻辑，更新框体、标题、下拉菜单与线色。装备、存档、货币和操作规则沿用原系统。

## 预览与复现

独立字样场景：`godot/scenes/InscriptionSpecimen.tscn`。默认游戏入口仍为 `World.tscn`。

第二版图集位于 `artifacts/inscription_ui_v2/`，包括字体控件总览、HUD、濒死、契印、铭饰、行囊、旅记、地图、设置、对话、960×540 HUD、1600×720 行囊。

第二版美术由内置 image_gen 工具根据用户参考生成，已保存至 `godot/assets/ui/inscription/v2/`。完整生成提示词和素材列表见该目录 `generation_prompts.json`。界面功能、文字内容、焦点和点击仍由真实控件处理。

```powershell
godot --path godot --script res://scripts/capture_inscription_ui.gd -- --capture-output=C:/absolute/output/directory
```

截图使用隔离的展示进度，预置获得、配装、碎钱与部分补绘房间；不代表自然游玩获得或通关结果，不读取玩家主存档。截图脚本结束时删除展示存档。

验证：资源导入（recovery mode，不加载编辑器插件）、`ui_redesign`、`ui_world_integration`、`ui_build_accessibility`、`input_prompt`、`seal_ui`、`build_slots_ui`、`world_map`、`inventory_map`、`cartography`。`build_slots_ui` 在真实 OpenGL 渲染下验证；无图形后端的 Godot 4.6 在其截图步骤会报告空纹理。
