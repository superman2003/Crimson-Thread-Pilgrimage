# T05：导出审计不再漏掉预设与运行时资源

基线：main `93365331bc8d0bcf588244c2000c43df7be16f04`。开工前进度图已先提交为独立 PR #228。本批只改发布审计与回归，不改 Player、敌人、地形、导出预设或运行参数，不包含尚未合并 #227 的收招取消。

## 问题与结果

旧审计只拿运行时 `.gd`／`.tscn` 与排除规则比较，尽管已经找到 JSON／着色器引用，误排除它们仍会返回 PASS。没有预设或某预设缺少字段时，正则解析会直接跳过它，甚至输出 `presets=0 errors=0`。此外 Python `fnmatch` 与 Godot 导出过滤器不同，会漏掉大小写、`res://` 前缀和带空格的有效规则，也会误解 `?` 与方括号。

现在每个预设都必须有非空唯一名称、显式 `all_resources` 模式与字符串排除字段；空文件、缺失文件、坏语法、缺字段、重复名称和未支持模式都明确失败，CLI 返回 1 并可写 JSON 报告。空排除串仍是合法预设，会继续审计，不能成为跳过检查的办法。其它导出模式需要单独实现分析，不能冒称已经验证。

运行时图沿显式 `res://` 和脚本 `class_name` 继续追踪，新增图像／音频／字体等叶子与着色器 include；全部可达资源检查排除，二进制文件不再当源码扫描。报告保留原 `reachable` 脚本／场景字段，另列 `reachable_resources` 全集。本版本正式 Linux／Windows 两套预设通过：93 个脚本／场景、3,730 个显式引用资源、0 个动态脚本加载器、0 个错误。

过滤规则按 [Godot 4.6.1 `_edit_files_with_filter` / `_edit_filter_list`](https://github.com/godotengine/godot/blob/4.6.1-stable/editor/export/editor_export_platform.cpp) 对齐：去规则首尾空格，在完整路径与去 `res://` 路径上进行不区分大小写的匹配，只将 `*`／`?` 视为通配符，`?` 不匹配点号。[String.match 文档](https://docs.godotengine.org/en/4.6/classes/class_string.html#class-string-method-match)解释通配规则。

没有加入“JSON 必须匹配 include_filter”的新门禁。初步探针中无 include 的 JSON 在旧工具也通过，但这不能证明导出丢文件：4.6.1 的 [ResourceFormatLoaderJSON](https://github.com/godotengine/godot/blob/4.6.1-stable/core/io/json.cpp) 已识别 `.json` 为资源，因此不把这个探针当作已证明的缺陷。一般非资源文件的 include/exclude 说明见[官方导出文档](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html)。

## 验证

| 检查 | 结果 |
| --- | --- |
| `python tools/test_export_audit.py` | 17 个测试方法通过；包含多组资源、坏预设与过滤语义子案例 |
| 同一临时项目新旧对照 | 10 组通过：旧工具放行的 8 组危险配置现在拒绝；旧工具误拒的 `?`／方括号 2 组合法配置现在接受 |
| 正式两平台导出配置静态审计 | PASS，2 预设／93 脚本场景／3,730 引用资源 |
| `PYTHONUTF8=1 npm test` | exit 0，含新增审计测试及正式审计 |
| `PYTHONUTF8=1 npm run test:campaign` | exit 0 |
| `git diff --check` | 通过 |

原有 4 个测试保留，新增 13 个测试方法覆盖资源误排除／缺失、二进制叶子、着色器 include、过滤语义、多预设、空规则、坏配置与 CLI 失败报告。已有 npm 与桌面候选 CI 会自动运行该文件，无需另外改工作流。

[新旧对照及日志](../../artifacts/t05_export_audit/README.md)保留旧工具原字节 SHA、正式工具／项目／预设输入 SHA 和完整 npm 输出；标准输出有 npm 代理配置警告，不宣称全部输出零 warning。

## 边界与台账

这是静态审计覆盖修复，不是实际构建／启动新发布包，也不是 Godot 玩法回归或实机验收。拼接的资产路径、二进制 `.res` 内部依赖、导出插件、自定义导出模式与 addon 中的开发文件清理仍不由本工具完整模拟。字体／图片存在性检查不等于验证其导入或 LFS 内容，正式候选包仍要使用原构建、校验、启动与重启门禁。

T05 与全部 46 项最终验收保持 OPEN。下一阶段仍需最终候选包、入口／结局／许可一致性、真实设备与人工体验证据；不以这次静态审计关闭发布或整体完成率。
