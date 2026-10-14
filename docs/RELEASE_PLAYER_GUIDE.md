# 绯线巡礼 · 桌面候选版

这是开发中的原创银河恶魔城原型。候选包通过自动导出和独立启动检查，不代表已完成六区自然流程、全部结局、手柄、视觉或听感验收。

## 启动

完整解压压缩包。Windows 双击 `CrimsonThreadPilgrimage.exe`；Linux 运行 `./CrimsonThreadPilgrimage.x86_64`（若解压工具未保留权限，先执行 `chmod +x CrimsonThreadPilgrimage.x86_64`）。可执行文件与同名 `.pck` 必须放在一起，不需要安装 Godot 或下载源码。

只支持 Windows/Linux x86_64；需要可运行 Godot 4.6 Compatibility 渲染器的图形环境。Windows 包未签名。macOS、移动端及 Web 不在本候选包范围内。

## 操作和设置

- 左右方向键 / A、D：移动；空格：跳跃。
- J：攻击；V：设置。具体攻击、交互、移动能力与手柄绑定以游戏设置页为准；设置中可调整按键、字幕、音量、闪光和震动。
- F：交谈和交互；M：地图，地图内 Tab：区域 / 互联图。
- B：构筑；L / C：施放 / 切换技能；T / G：使用 / 切换战具；K / X：已获得的钩索。
- F9 会弹出新旅途确认，请先备份已有记录。

## 保存与问题报告

记录保存在 Godot 的用户数据目录，通常为：

- Windows：`%APPDATA%/Godot/app_userdata/绯线巡礼 - 互联世界/`
- Linux：`~/.local/share/godot/app_userdata/绯线巡礼 - 互联世界/`（设置 `XDG_DATA_HOME` 时遵循该目录）。

升级前退出游戏，备份整个用户数据目录。不要仅备份一个 JSON：该目录还可能包含槽位、设置、备份和既往旅途。候选版沿用现有游戏存档位置；新数据版本未必能被旧构建读取。

报告问题时附上 `BUILD_MANIFEST.json`、系统信息、复现步骤与日志；分享存档前自行检查其中内容。问题入口：https://github.com/superman2003/Crimson-Thread-Pilgrimage/issues

## 当前验收边界

- 全六区、多构筑、伤害开启的自然通关与三结局逐项验收仍待完成。
- 地图非线性路线、后期房间、手柄体验、音频混音和正常尺寸视觉仍需人工体验。
- 导出与启动检查不验证正在独立分支修复的存档、输入、终局或世界加载问题；具体构建以清单中的提交为准。
- `licenses/` 保留项目许可证、素材 NOTICE、字体许可与插件许可。代码 MIT 不替代素材各自的条款。
