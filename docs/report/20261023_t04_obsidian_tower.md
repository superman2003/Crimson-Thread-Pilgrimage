# 黑曜绞盘、塔楼军墓回环与镜前正常存档（W01／W02／W05／A01／U04／T04 子项）

从 #201 正常营地种子继续：钱包287、23种物品、12补绘、灯影相位已取得，但 `boss_unlocked=false`、`opened_shortcuts={}`，并没有突进。先沿西阶真实下返灰坑，在 `(3610,2856)` 正常F开启 `ch05_funicular_shortcut`，沿免费轴梯及西阶走回营地安坐；相位不是首领解锁钥匙。随后走上段石路登塔、正常F开启修女对话并关闭，经塔西旗桥／军墓收取第五证言，再实际回营地安坐、重登塔抵镜池前钟龛。

本批无生产地形、玩家、敌人、首领或解锁参数修改。基线已由自身G02提交 `fa8aa775` 撤销未完成906 cherry-pick、ff-only main `2cd7cf62`，再ff-only PR201最新头 `849c5fb43479490f224a3d748370d148bce6d0df`，树 `e1e32f74bc9f5cb8a7141073b14ec8926a870f83`；已有import工作区改动保留。准确集成记录在 `integration.json`，不重复移植906。

## 实际路线与收入

正式记录 `artifacts/t04_obsidian_tower/final_native_01` 为 **84步**伤害开启Input，从原营地种子完整走到镜前实际F安坐，5次扣血、4次耗能治疗、0死亡。没有位置写入、物品授予、伤害屏蔽或快速旅行。两次经过塔楼第四踏板时先实际移到第三踏板左缘，再跳第四踏板右侧 `(3250,798)`，保留全部原平台功能。

塔顶是修女而非新增存档点；真实第五证言仍在军墓 `(275,1458)`，属于手动F故事物品。实际登上军墓地面1392，在x295使 `col_testimony_05` 成为最近目标，再正常F收取，未把旁边只读History_witness当作物品奖励。旗桥E12精英用现有斩裂战技和普通攻击真实击败；此前空中空挥／落错层失败保留。

钱包287→389：9名敌人的基础奖励各8，E12首次精英奖励额外30。黑曜碎片4→20：9份敌奖＋E12额外2＋自然经过灰坑收取5。第五证言新增1，物品23→24种；补绘12→19条。构筑及所有工具数量与起点完全相同，灯影相位保持1，`thread_dash`保持未取得。安坐后HP5、能量100，绞盘及Boss路线已解锁，新娘仍未开战／未击败。

## 精确持久化与来源

种子来自 #201 正常36步回放的 `earned_camp_seed.json`，SHA256 `91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b`；只复制原字节到唯一私人save，Windows不依赖XDG_DATA_HOME。正式新的Godot PID精确核对钱包、全部库存数量、完整构筑、所有故事标记、补绘、捷径、区域与检查点，保留已付费地图和绘针，并再次打开无定位地图。不是只看非零输出。

Godot4.6.1／原生NVIDIA GL，主进程47.59秒，双进程共55.86秒；每进程严格180秒，8755份tracked Godot与新脚本／runner／误证明helper／seed／生成器冻结前后一致。两进程退出0、零ERROR／ObjectDB退出warning。固定60Hz输入不代表FPS或人工体验。`final_headless_01` 是此前CPU完整快照，新native快照已加入误证明helper，不混称同一次冻结。

九类错误钱包、小数库存、小数构筑、缺故事字段、缺补绘、缺捷径、错检查点、缺PID、错区域证明分别退出1且只有一条预期错误；不是损坏存档恢复测试。`npm test`、`npm run test:campaign` 在UTF8环境真实退出0，Python编译及导出审计通过。

正常镜前seed为 `earned_mirror_seed.json`，SHA256 `5ac89dd500d23d4aa7c8fd7cb59cd92ae9c932f19d1dcf981688e148dfe73f68`，由 `seed_provenance.json` 绑定正式回放及新进程证明。下一独立批次将从此精确正常检查点真实开启22HP镜池新娘，记录真实Boss死亡／归途结／手动F重试成本，再观察四招并完整击败、战后安坐与独立重启，随后自然走向C6；本批不声称已完成这些事项。

所有失败保留：逆向误跳落上层、E06过远施技死亡、下行缺口误走／起跳过早、E12空挥推落旗桥、军墓目标楼层及F目标选错，均属控制选择，未为脚本修改生产几何。归档gzip mtime0逐字节校验，manifest记录原文件SHA256；提交源码字节与正式冻结一致。46项最终验收继续OPEN。

重放：`python tools/run_obsidian_tower.py --native-gl --engine <Godot> --log-dir <目录>`；省略native使用CPU定位。误证明：`python tools/verify_obsidian_tower_proofs.py --proof <restart-proof.json> --log-dir <目录>`。
