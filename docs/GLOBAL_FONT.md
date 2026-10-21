# 全局字体：一键应用、检查、还原

项目根目录双击 **`一键应用字体.cmd`**，会把所有游戏文字接到同一个实际字体文件。也可以把自己的 `.otf`／`.ttf` 文件拖到这个脚本上，统一切换全局字体。

覆盖菜单、正文、对话、地点、地图、数字、浮动提示、加载文字、路牌按键提示、弹窗和网页试玩版。没有「正文仍用黑体」的例外。原有字号、字幕大小设置和地图 MSDF 字体缓存保留。

命令行用法：

```powershell
npm run font:apply
npm run font:check
npm run font:coverage
npm run font:restore
```

替换成指定字库：

```powershell
python tools/apply_global_font.py apply --font "C:/Fonts/你的字体.otf"
```

还原也可以双击根目录 **`一键还原字体.cmd`**。备份位于本地 `tmp/font_switch_backups/`；重复应用相同字体不会产生重复改动。连续从字体 A 换成字体 B、或修复新加控件的字体引用后，仍保留第一次应用前的基线，一次还原即可回到最初状态。还原和再次换字体前都会核对已管理文件；手动修改过的内容会停止操作并报告冲突，保留后续改动。

统一入口是 `godot/assets/fonts/GlobalTypeface.otf` 和 `godot/assets/ui/global_typeface.tres`。`GlobalTypography` 自动加载节点在运行时为根窗口安装统一主题，避免编辑器首次导入前提前加载字库。脚本同时清理散落在场景与脚本中的字体覆盖以及默认字体绕过；新建控件也会继承。切换后在 Godot 编辑器中自动导入更新的字体；导出运行版需要重新导出。

当前默认字库为 **缝名刻宋 / Feng Ming Inscription**：真实 OpenType 字体，保留完整 Noto Serif CJK SC 的 **44,777 个 Unicode 字符**，再内置返回箭头、封闭路线标记和锁形 3 个界面符号，共 **44,780 个字符**。包含简繁中文、上游收录的生僻字与扩展区、日文、韩文、拉丁文、标点和数字；覆盖原版 Noto Sans SC 的全部字符。所有中文字符使用同一套针刻生成规则，不再按当前剧情裁剪。字库来源、修改和 SIL OFL 1.1 许可证随项目保留。

主字体已关闭系统字体后备。`font:coverage` 直接读取字体 cmap，核对完整字符清单，并扫描全部 Godot 运行源文件和 `index.html`、`src/` 网页文字；缺字会列出字符、Unicode 编码和文件行号并使 CI 失败。完整字库仍有明确的 Unicode 收录范围，不声称覆盖世界上所有文字或所有 emoji；将来加入上游范围外的语言或符号，需要随资源一起补充。

运行包只保留 `GlobalTypeface.otf` 这份新字体。默认字库的开发备份移到 `tools/font_assets/FengMingInscription.otf`，供一键切回默认字体使用；构建中间字体位于忽略的 `tmp/inscription/`。旧版 Noto Sans SC 留在仓库供历史回退，导出过滤器不打包它。

大标题的骨片纹理、穿线和旧铜纸面另外作为装饰美术存在，不影响文字主题的一键切换。

验证入口：`npm run test:font`（安全替换与连续还原、网页和游戏缺字门禁）、Godot `global_font`（关闭系统后备后的真实字体与控件继承）、现有布局、输入提示和地图回归。
