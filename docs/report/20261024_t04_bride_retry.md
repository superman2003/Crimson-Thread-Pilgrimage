# C5 镜池新娘：实际死亡、找回、手动重试与胜利

以 PR204 正常取得的镜前存档继续；输入 seed SHA256 `5ac89dd500d23d4aa7c8fd7cb59cd92ae9c932f19d1dcf981688e148dfe73f68`。最终基线 main `5f1fa82663fca3df131f3d9d5e6a65483b1a232c`，树 `ba28ae67d794f80ad7cd567fea60f7943119cea7`，包含206疗伤和207 Boss技能素材。本批只新增自动输入回放／严格证明与证据，没有修改生产AI、生命、伤害、关卡、奖励或开门规则。

## 实际流程与成本

角色389钱包、24种物品、既有大劈构筑，无突进。正常往返清掉E13战车并在镜前F安坐后397钱包；正常F开启完整22HP新娘。静止承受真实Boss五次伤害而死，Boss仍22HP；生产复活到镜前，199钱包＋198归途结（floor(397/2)），能量0，库存与构筑不变。同进程等待复活及后续15帧，确认Boss未自动重生、无锁、无Boss音乐，再由独立新PID精确证明该状态。

下一进程正常F找回198，恢复397并清空结；正常F安坐，物理往返清死亡后重新出现的E13，钱包405／黑曜碎屑22，再次F手动开完整22HP。找回至重新开战为8个回放控制步骤，包含清守卫与安坐；不是人的脚步数、真实玩家重试时长或刷钱要求。

正常输入战胜新娘，实际active记录为弧斩5、镜移7、镜池6、掠袭4次。重试阶段共8次扣血，其中守卫1、Boss7；Boss战中4次正常治疗，逐次实际扣60能量、各回1HP，战斗末2HP。大劈沿生产扣费／普攻击中回能使用，未单独采集完整能量流水，不把治疗支出冒称所有技能总成本。两个既有碎片工具均未消耗。胜利实得30钱包和唯一沉默军令：435钱包、25种物品，库存仅两次守卫黑曜＋2和军令＋1，完整构筑／工具计数仍等于原seed。

胜后物理越门返回镜前，正常F安坐到5HP/100能量，再由独立新PID核对钱包、每项库存、构筑、故事、补绘、捷径、checkpoint及坐标、全regions、Boss解锁/击败、空归途结。能力未授写，未调用伤害/死亡/传送，也未赋写角色位置、HP或剧情状态。

## 最终验证与历史边界

`artifacts/t04_bride_retry/final_native_02/verification.json`：四个实际进程12.33／4.50／30.62／4.45秒，完整runner55.77秒，各自严格180秒上限；8788个冻结文件前后完全一致，四PID均0 ERROR、0 ObjectDB warning。固定60Hz是自动输入配置，不是FPS或人工性能验收。流程结束后才树内捕获/退休音频，释放AudioDirector真正静态流缓存所有权，再free与有界drain；不清弱引用待验对象。

同最终代码CPU四PID及17类错误证明全部通过；每个错误证明必须exit1、恰好一个对应ERROR和failures=1标记，包括非法小数、完整字典/数组、阶段交叉、PID及货币/结/Boss状态。main5f的UTF8 `npm test`、`npm run test:campaign`均实际exit0。

早期失败、所有源码快照、两次中断均保留：近战距离与镜弹续空控制导致的真实战败不是生产缺陷；death01计数器重复计零血钱包事件、fight02中断、negative02中断、缺guard／新Boss纹理导入的失败都不计最终通过。native01玩法四PID断言通过，但retry退出有一条**未归因**ObjectDB warning；没有verbose资源身份与同源码因果反向，后续零warning不能宣称已归因修复。native01及旧CPU基线不冒称与main5f最终快照相同。

输出 `earned_bride_seed.json` SHA256 `d8e950d6fac3e1be55b4fb7bbb5b85eac09fdfdc45a6d8ed9fbc6410535e443f`，来源见seed_provenance。所有日志gzip mtime=0、逐字节回解核对，manifest归档。下一批从此真实胜利seed继续战后出口/C6；本批未走C6。G02新增真实Boss重试成本子项，远程找回、不同构筑／顺序与陌生玩家理解仍待验，全部46最终验收继续OPEN。

重放：`python tools/run_bride_retry.py --phase chain --native-gl --log-dir artifacts/t04_bride_retry/replay_unique`（Windows Godot4.6.1；须用独立日志目录）。CPU省略native参数；反向工具接收本次retry-proof.json，必须在同一私人save仍为该胜后状态时运行。
