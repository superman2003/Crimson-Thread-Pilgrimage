# 2026-10-25 十个独立可靠性升级 PR

每项包含生产实现、行为回归、原始日志、故障反例和专用 CI；原 46 项最终游戏验收仍 OPEN。这十项是可靠性与性能子项，不等于新增十套游戏系统或最终完成游戏。

| 批次 | PR | 内容 | 文件数（索引追加前） |
| --- | --- | --- | --- |
| 1 | [#262](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/262) | 预览服务媒体分段、请求容错与文件边界 | 6 |
| 2 | [#263](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/263) | 旅记偏好最近使用淘汰、失败重试与写入快照 | 8 |
| 3 | [#265](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/265) | 长篇旅记与对话书签的内存和生命周期 | 9 |
| 4 | [#266](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/266) | 战斗装饰批量准入与节点所有权 | 8 |
| 5 | [#268](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/268) | HUD 遮挡随攻击生命周期更新 | 8 |
| 6 | [#269](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/269) | 打击停顿的真实时钟与全局速度归还 | 8 |
| 7 | [#270](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/270) | 镜头观察和跟随的异常采样恢复 | 8 |
| 8 | [#271](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/271) | 房间镜头配置隔离与窄门稳定选择 | 8 |
| 9 | [#272](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/272) | 设备操作提示的有效输入与专属绑定选择 | 8 |
| 10 | [#273](https://github.com/superman2003/Crimson-Thread-Pilgrimage/pull/273) | 世界坐标预编译缓存与存档位置校验 | 8 |

全部独立基于 main `43fbcf88`，没有相互分支依赖；十个远端 commit 的 tree SHA 均与本地独立分支一致。最新检查时全部 PR `mergeable=true`。没有自动合并。已检查原 #248–#261 的最新文件列表以及过程中新增 #264/#267；本轮生产文件与这些 PR 无重叠。不承诺未来提交或其他未合并功能组合不会产生语义冲突。

## 验证和证据

九组独立 Godot 模块测试共 **190 项通过**，HTTP 真实 socket 测试通过。每组独立工程仅包含本项修改，其余依赖从原 main 逐字读取；九次临时源代码故障注入均触发预期语义断言失败，没有 SCRIPT ERROR。逐组证据见各 PR 的报告及 `artifacts/reliability_20261025/02_*` 至 `10_*`。

十项组合生产树 `2ca1fd9b630e8994dc794846ddadf775af9991d1` 的最终冻结检查：5 套 headless（无障碍、真实玩家房间镜头、旅记工作台、输入提示、865项坐标/存档迁移）与4套真实 llvmpipe GL（战斗视觉预算、世界HUD、无障碍、镜头）全部通过；两轮严格资源导入、`npm test`、`npm run test:campaign` 和最终 HTTP 测试通过。14项生产/依赖输入在测试后哈希保持一致。GL预算含44项主检查和52项次级装饰检查，无障碍含17项，镜头86项。

组合证据保存在 `artifacts/reliability_20261025/integration/`。索引和本目录追加到第10项 PR，仅增加文档/日志，没有改变上述生产文件。远端 GitHub CI 最后查询仍为 queued，不能记为 CI 已通过。

## 保留的失败和限制

早期选套命令错误地请求了未注册的两个辅助脚本，并用 headless 请求必须 GL 的视觉套件；三项门禁失败日志保留。随后按正式入口进行最终冻结测试。初次 GL 运行因本机缺少 xkbcomp，X11 显示服务退出，四套未执行成功；补齐环境后同源码的四套真实 GL 全通过，初次失败日志保留。Xvfb键符警告和原有 V-Sync 提示按日志保留，未用错误过滤器跳过引擎错误。

没有全跑整个仓库 Godot 集合、Windows/Linux发行包、实体手柄体验或自然六区全流程；也没有将其他 agent 未合并功能整合进此组合。不能以组件测试替代46项最终验收。
