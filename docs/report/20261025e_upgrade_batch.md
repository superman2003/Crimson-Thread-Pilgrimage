# 2026-10-25 E：十个独立升级 PR

本轮按功能边界拆成 10 个可独立审阅的 PR。每项包含生产改动、专项、语义故障注入、日志和独立工作流；没有修改共享回归注册表，没有合并 PR。

| PR | 升级 | GL 检查数 | 功能提交 |
| --- | --- | ---: | --- |
| [#277](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/277) | 图钉命名、分类编辑与持久确认 | 15 | 685ae74f01455ba2852a9d14ac17899096cbea93 |
| [#278](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/278) | 已知地图自然排序、结果导航与分类计数 | 8 | 62f54fb397dd84e5934e2e343b5a94fa31237eea |
| [#279](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/279) | 四种补给清单预设、部分报价与滚动明细 | 13 | af047ebe3994caff4ea9f5e489a48b842df800c9 |
| [#280](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/280) | 保存构筑内容预览、规范目标复核与提交收尾 | 6 | f8fbe882d5998b776db980ecd76e7155b20f3e8f |
| [#281](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/281) | 十二篇能力组合自述与已获条件校验 | 34 | 499bd0877017076ca0d24e72641f23c8c2f982f3 |
| [#282](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/282) | 敌方及反射弹道的连续接触与地形先后判定 | 12 | 0201b9162c644360e23aa8c9df784587b3c71c5f |
| [#283](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/283) | 六区材料化密道线索与发现后静态反馈 | 32 | a80851c69477fa53ae501f612a19ee7305077b77 |
| [#284](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/284) | 环境旧物聚焦说明、已读标记与视线交互 | 8 | 1d3b4b3d3fa1ae0e2c2be80ffc78c94f086d551f |
| [#285](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/285) | 存档读取租约、旧实例保护与备份核验 | 9 | 4cb37ff23c5ec67fdfaf7ece9739deec1e58be33 |
| [#286](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/286) | NPC声音地标公平轮询、限频与来源退役 | 13 | 12f8a3013267fb51a431ea4b6d01f5996093881a |

## 冲突与来源

发布前逐项检查了其它 14 个开放 PR 的完整文件清单；本轮生产文件与其没有重叠，本轮各 PR 之间的生产文件也不重叠。没有向他人 PR 推送实现改动。#277 的另一个 agent 在 bcc61789 增补根 .gitattributes 的截图存储规则，已保留；生产代码和测试与我们验证的 685ae74f 相同。

#277 原始基线为 856010d8；后九个功能提交基于 d335d707。各项均已在 856010d8 的隔离目录中单独叠加验证，不依赖其它未合并 PR。后九项恢复后使用重新生成的测试和新日志，旧环境的日志没有用于证明恢复版本。

main 随后推进到 e99b79fb，仅新增 input_prompt_bindings.gd、world_coordinates.gd 两个生产文件及其测试、报告、CI；与本轮生产文件仍无重叠。检查时 10 个 PR 的 GitHub mergeable 均为 true；这不代表远端 CI 已完成。

## 实际验证边界

- d335d707 加本轮全部 10 项：真实 Mesa llvmpipe OpenGL 下 10 套专项、共 150 项检查通过；14 套既有回归通过。完整日志见 integration/d335_specialized 和 integration/d335_gl。
- e99b79fb 的两个新依赖文件加上述组合：追加运行 world_coordinates、world_state、world_save_candidate、map_player_pins、save_product、input_prompt、ui_build_accessibility，7 套真实 GL 回归通过。没有把这一轮 7 套称为重新跑过全部 14 套。
- 10 个临时语义故障注入均被捕获。后九项在独立目录中修改精确一个生产片段；专项退出码均为 1，产生预期断言失败，无 SCRIPT ERROR。原始文件通过 finally 恢复；每项目录保留 mutation.json 与正反日志。
- npm test、npm run test:campaign 通过；Godot 4.6.1 资源严格导入两次通过。导入用 recovery-mode，未验证编辑器插件行为。导入第一轮完整日志很长，记录其 SHA256；第二轮日志随附。
- 四张本轮恢复后的真实 GL 截图和 #277 原截图已查看；界面证据为隔离功能夹具，不代表完整关卡验收。
- 部分既有回归退出时有 ObjectDB 资源回收警告，日志原样保留；专项正例均没有 SCRIPT ERROR 或 ERROR。原项目最终验收状态保持 OPEN。

## 证据定位

本目录的各项报告给出源文件、测试、操作规则及故障片段。共同证据在 [artifacts/upgrade_20261025e/integration](https://github.com/superman2003/Crimson-Thread-Pilgrimage/tree/codex/upgrade-20261025e-10-npc-schedule/artifacts/upgrade_20261025e/integration)：

- verification.json：冻结基线、提交、专项数量和运行边界。
- source_sha256_d335.json / source_sha256_e99.json：实际测试的生产文件、测试和两个变化依赖的字节身份。
- d335_summary.log、e99_summary.log：两轮回归执行结果。
- npm.log、campaign.log、import_summary.json：仓库级检查与导入记录。

后九项 CI 固定检查精确 PR head，校验 Godot 4.6.1 压缩包 SHA256，运行现有相关回归、真实 GL 专项和负对照，并上传日志。发布时这些远端任务仍在排队或执行；此处报告的是本地完成的验证。

存档读取租约采用乐观身份检查，最终核验与重命名之间仍有竞争窗口，不是跨进程文件锁。其它功能的限制分别见各项报告。
