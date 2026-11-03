# T03：CI 上接近限时的流式套件给足超时

所有 46 个任务包的最终验收仍开放。本批只改测试运行器的单套件超时，不改游戏代码。

## 问题

11-02 一天里，#489、#492、#494 的 runtime 分片 4 次失败，全部是流式套件超时（`world_route_walk`、`world_neighbor_gameplay_live`、`world_passage`、`world_async_loading`），套件本身没有失败项，重跑后通过。从同日通过的运行（#498）日志计算各套件实际耗时：

| 套件 | 通过时 CI 耗时 | 本机（无头） | 原限时 |
|---|---|---|---|
| `world_route_walk` | 175s | 135s | 180s |
| `world_passage` | 167s | — | 180s |
| `world_async_loading` | 141s | — | 180s |
| `world_neighbor_gameplay_live` | 130s | 100s | 180s |
| `world_neighbor_gameplay` | 174–196s | — | 300s（已单独设置） |

前四个与 180 秒的默认限时只差 5–50 秒，CI 机器稍慢就会超时。本机在昨天的 main（bd11a96f）和今天的 main 上耗时相同（101／100 秒，135／135 秒），不是新代码变慢。

## 现在

`world_route_walk`、`world_passage` 360 秒，`world_async_loading`、`world_neighbor_gameplay_live` 300 秒，约为通过时耗时的两倍；其余套件仍是 180 秒。runtime 作业限时 60 分钟，实际约 38 分钟，余量足够。

## 验证

`tools/test_regression_runner.py` 新增一项：超时表里的每个名字都必须是默认套件（防止拼错后静默退回 180 秒），且上述五个套件的限时不少于实测耗时的两倍。原有“超时照样判失败”的检查保留。34 项通过；`tools/test_ci_shards.py` 通过。

## 边界

只是避免误报。这些套件本身偏慢（两分多钟），拆分或加速它们属于另外的工作。
