# 野外死亡不会隔空开启钟门首领（G02／T04 子项）

#198 正常西路种子（259 碎钱）实际死亡后，`pending_enemy_respawn` 在下一帧对已解锁首领无条件调用 `_spawn_boss()`，即使玩家仍在温室西侧。它重新开启首领音乐及 HUD，让下一次野外死亡误走 Boss 场外检查点分支。旧实际输入日志 `approach_03` 明确记录第一次结在西侧、后两次 `boss_spawned=true` 且结落树心；这不是正常 Boss 重试证据。

修复只给普通敌群复活后的自动首领生成加 `not world_mode`：World 继续由钟门 F 手动开战；非 World 自动行为及试炼专门重试路径保留。没有更改货币损失、玩家伤害、首领参数或地形。

默认新增 `g02_respawn`：正式 World 定位夹具明确使用位置夹具及真实控制器致命伤害，不作自然路线证据。覆盖野外复活不生成首领／不锁门／无首领音乐、再死亡仍取永久安全地面；真实门前 F 正常开战封门并启首领音乐；首领战死亡把结放在场外，World 等待下次手动进门；试炼及非 World 自动重试保留。最终同一夹具在修复条件通过，恢复旧唯一条件准确失败四项，均零非预期引擎错误；夹具 SHA256 `79b4f89a54c71ca6f6d2883d098a4b3c4ec6bb43c31f10361368d1777d9938fd`。回退脚本 finally 按字节恢复生产源码。

正式自动输入续跑为 `artifacts/g02_earned_death/final_native_01`。种子为 #198 实际赚取的 `earned_west_seed.json`，SHA256 `4f9a624b6c55a656e711053397511e3388fd1a16e45b9d40fbf0c952d38f2cc1`，由其 `seed_provenance.json` 绑定正常西路回环。只复制原字节到唯一私人 save，五个独立进程依次传承该 save，没有挑改存档。

1. 正常走到西侧假苔，承受现有敌人和危险伤害至真实死亡；259→130，结 129。
2. 新 PID 精确恢复该结及剩余钱包，实际走回、F 找回 129，钱包回到259；再次在假苔真实死亡，钱包130，结129。
3. 新 PID 精确恢复，实际再走同一路，不按F找旧结，承受伤害再次死亡；钱包130→65，新结65替换旧129，没有累加旧结。
4. 新 PID 精确恢复新结，正常返程F只找回65，钱包65→130，永久损失旧结129。
5. 最后新 PID 精确恢复130钱包及空归途结，全部库存数量／完整构筑／地图补绘／区域／树心检查点精确相等。

三次死亡各有5次实际扣血，共15次；每次由5HP复活至5HP，绯线按生产 `_hard_respawn` 归零。没有治疗、消耗工具、击杀奖励或新增采集；20种材料与能力的所有数量、构筑及16条补绘不变。每次致命帧读取真实 `last_safe_ground`，新结精确落在 `(1897.2783,1561.9253)` 的永久地面。每次复活后同进程额外15tick检查无首领实体、无锁门、无首领音乐；不是靠退出重启消掉错误瞬态。

Godot4.6.1 原生 NVIDIA GL 五进程合计48.44秒，各严格180秒；冻结8753份tracked Godot及新回放／runner／fixture／seed／生成器前后一致。五进程均退出0、零ERROR／ObjectDB warning。固定60Hz不代表FPS或人工体验。七类错误钱包、旧结、物品小数、构筑小数、PID小数、缺补绘、错检查点证明，各退出1且恰好一条预期错误；不冒充损坏存档恢复。

`death_cache_placement` 9项、`world_death_cache_flush` 27项、`boss_trial` 及新默认套件通过；boss_trial有未归因ObjectDB退出warning。首轮相关runner在GBK打印替换字符时报错，日志保留，设置UTF-8后重跑通过。旧输入与所有失败留存；`staged_headless_01` 虽完成账目仍使用旧生产逻辑，不能作为修复后结位置证据。

默认套件现在133+4=137，成功marker与跨平台契约同步。重放：`python tools/run_g02_death.py --native-gl --log-dir <目录>`；省略native参数进行CPU定位。正反夹具：`python tools/run_g02_respawn_fixture.py --log-dir <目录>`。

本批覆盖自动输入死亡、全额找回、二次死亡替换、精确持久化；实际Boss对战死亡／重试资源成本、三守门者后的六成远程找回和人工理解仍待验收。定位夹具只证明Boss规则，不把它计作自然Boss战。46项最终清单继续OPEN。基线 #198 尚未合并，本PR依赖 #198，目标main；不合并main。

`npm test`、`npm run test:campaign` 在 `PYTHONUTF8=1`／`PYTHONIOENCODING=utf-8` 环境真实退出0；此前GBK读JSON失败日志保留。Python编译、默认137套成功契约与发布导出审计通过。五份实际阶段save离线核对：库存与构筑均与起点完全相同，故事标记只新增实际看见归途结的 `tutorial_interaction_seen_death_cache`，地图所有权和补绘未变，见 `save_invariants.json`。
