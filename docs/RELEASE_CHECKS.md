# T05 反向升级：独立桌面候选包

从 `docs/SILKSONG_ALIGNMENT_REVISED_PLAN.md` 第四批末尾的 **T05 发布检查** 开始。基线为 main `3bd62d199662fcd3a248e8d7a849ab00cea6c26a`。这次完成发布工具基础，不将其标记为 T05 全部人工验收完成。

## 并行边界

本分支只增加独立工具、导出预设和交付文档。没有更改运行控制器、World、配置校验/加载器、存档、输入设置、既有 Godot 验证脚本或现有 CI；不叠加 PR #35/#36，不合入 main。

按用户 2026-10-14 的分工，CI 已接入 `.github/workflows/release-candidate.yml`，对相关 PR 和 main 的变更执行 Linux/Windows 双原生 runner 检查。工作流只上传候选包和日志，不创建 GitHub Release、打标签或部署。

## 已实现

- Linux / Windows x86_64 的 Godot 4.6.1 导出预设；主入口仍为 World。
- 把项目复制到临时目录，排除验证、截图、预览、缓存和临时文件；只在临时副本禁用编辑器插件，保留 runtime autoload、插件类和 UID。原工程不变。
- 动态加载的 JSON、MapData 文本和素材清单纳入导出，避免仅导出场景依赖漏掉文件。
- 输入检查拒绝未水合 LFS 指针、已登记受限素材路径、符号链接、缺失章节/许可/说明文档与非法 JSON。检查不是完整著作权审计，也不是所有动态引用的静态证明。
- 导入和导出有超时；非零退出及日志中的 ERROR、SCRIPT ERROR、Parse Error、USER ERROR 均阻止通过，包括 ANSI 着色日志中的错误。
- 使用实际 release 可执行文件，移除整个临时工程后，在另一个空目录运行，不传源码 `--path` 或测试脚本；用户数据、设置和缓存全部隔离。
- 首次启动必须写出有效旅途记录；随后仅在临时存档插入一个无游戏作用的布尔标记，重启后必须保留，避免把“又开一局”误认作读档。
- 随包附项目、素材、字体、插件许可；通过固定引擎的 `Engine.get_license_text/get_license_info/get_copyright_info` 导出引擎及其依赖署名。
- ZIP 附 `BUILD_MANIFEST.json`（提交、dirty 状态、引擎、目标系统、验收范围及逐文件 SHA256）和外部 ZIP SHA256。保留失败日志，拒绝覆盖同名旧候选。

## 本地使用

需要 Python 3.10+、Git、Git LFS、Godot **4.6.1 stable** 及匹配的 release export template。工具在目标操作系统构建，以便验证真正的可执行文件；不要把交叉导出成功等同目标平台通过。

```sh
git lfs pull --include='godot/**'
python tools/test_release_builder.py
python tools/build_release.py --check
python tools/build_release.py --target linux --engine /absolute/path/to/godot --output dist/releases
# Windows 上运行：
python tools/build_release.py --target windows --engine C:/Godot/Godot_v4.6.1-stable_win64.exe --output dist/releases
```

`--check` 仅检查输入，不生成游戏包，也不宣称启动/玩法通过。实际包不需要玩家安装 Godot。失败后修正原因并换一个 `--output` 目录重试，保留此前日志；不能忽略错误重复运行到偶然通过。

正式候选应从 clean checkout 构建；本地开发构建会在清单中明确标为 `source_dirty=true`。构建包含当前工作树允许的资源，不使用 `git archive` 丢弃尚未提交的改动。

## T05 完成与剩余边界

| 检查点 | 状态 / 证据 |
|---|---|
| 素材水合、受限目录、必要配置与许可证输入检查 | 已实现，真实仓库输入通过 |
| 错误日志、超时、假读档、资源边界与校验和负面测试 | 15 项单元测试通过 |
| Linux 独立导出与两次启动 | 最终工具版本已通过：移除临时源码后启动、写出存档、重启保留探针标记；见下方验证记录 |
| Windows 原生导出与启动 | 工具和未启用 CI 草案就绪；本地 Linux 未宣称 Windows 通过 |
| 玩家启动说明、操作入口、保存位置、已知限制 | 随包 `README.md`，源文件 `RELEASE_PLAYER_GUIDE.md` |
| 整体剧情/终局/存档与设置流程验收 | 另一 agent 的 PR #35/#36 整合范围，本分支不替代 |
| 六区自然带伤流程、三契印、手柄、视觉和混音 | 尚需真实体验；headless 启动不能替代 |
| 所有素材的原创来源与第三方条款复核 | 保留已登记许可，完整来源审计仍待人工复核 |
| 失效入口、占位文本全量清理 | 后续结合逐章评测/文案候选处理，不擅改运行数据 |
| 正式发布 | 未进行；候选包与正式发布分开 |

## 2026-10-14 本地验证记录

- 最终工具版本来自本地提交 `3fbfd20db7b1c38dfca2656f758b30bc9179d5c4`；远端等价提交 `c049a991aa7f444fba39279450bb2ebf5201aadd` 的 Git tree 同为 `605b19c8af35bd24b6955f406b248b450e08592e`。后续仅补充本验证记录；CI 工作流启用提交为本分支后续提交。
- `python tools/test_release_builder.py` 的 15 项测试通过；`npm test` 与 `npm run test:campaign` 通过。
- 官方 Godot 4.6.1 Linux 编辑器和匹配导出模板经过官方 SHA512 清单核验。最终构建完成导入、导出、引擎许可采集和真实 Linux release 二进制两次独立启动，相关日志未发现 ERROR。
- 本地开发 ZIP 为 `CrimsonThreadPilgrimage-linux-3fbfd20db7b1.zip`，447,799,226 字节。构建开始时工作树曾有未跟踪的工作流草案副本，因此清单如实标为 `source_dirty=true`；该副本后来移出工作树，未提交或启用。不将此开发包称为 clean checkout 正式候选。
- 这些检查没有覆盖 Windows、六区自然带伤通关、终局流程、手柄、视觉或实机混音；对应待验收项保持不变。

## 下一批

按用户最新划定的保留区，暂不逆向修改 T03/T02/U06/N05 及控制器。下一批在独立分支交付美术、音频、剧情/教学文案和六章评测候选。资源先交付，不写运行数据，不合 main；接入时再与负责运行/整合的 agent 协调。

## 技术依据

- Godot 4.6 导出预设与非资源文件过滤：https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html
- Godot 4.6 CLI 参数与 release/extended 参数区别：https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html
- 官方固定版本发行和 SHA512 清单：https://github.com/godotengine/godot/releases/tag/4.6.1-stable
