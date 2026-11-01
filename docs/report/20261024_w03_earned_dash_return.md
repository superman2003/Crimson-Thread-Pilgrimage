# W03／A01／T04：正常取得突进、原静靴回访与独立读档

日期：2026-10-24。交付范围是实际输入回放与可复查证据，生产地形、敌人、能力、拾取和构筑逻辑均未修改。46 项最终验收继续 OPEN。

## 实际路线与原始种子

唯一初始输入是 `artifacts/t04_bishop_route/earned_bishop_seed.json` 的原字节，SHA-256 `f754c5ed76f8b0fa36caa2cd8166a74b20409f0421bf0ef469c9b18cc019d7f2`。该种子钱包 297、21 种物品，拥有重型线刃 `thread_burst`，没有永久移动能力 `thread_dash`；本批没有延续历史上将二者混称的说法。

完整正式链从这个种子开始，之后每个 PID 只复制前一 PID 实际导出的私有测试存档原字节。没有使用诊断中途种子替代正式前半段，没有授予能力、钱、生命或写角色位置，也没有直接调用交通切区。所有门、关卡和敌人参数沿用生产数据；输入辅助只使用已经实际拥有的能力。

1. 从 C4 主教胜利钟龛正常东行，通过原东出口进入 C5 西下路。第一台阶实际 F 使用原生产 `upgrade_archive_obsidian_branch_b` 运书互联通路，凭已经取得的双跳到 C3 蜡烛夹层；再实际 F 沿旧运书线返回 C1 初庭并安坐。三段交通收费均为 0，没有购买地图、伪造站点或进入模板工房。
2. 从初鸣钟龛沿西侧原台阶、蔓生门、盘根通道与旧藤井下行，实际 F 安坐迷园苔灯。旧尖刺造成一次真实伤害，正常休息恢复。
3. 绕原迷园根凳下到断枝祭坛，以正常攻击击败 E12，实际获得 8 碎钱与 1 苔壳，再跳上原 `col_thread_dash` 台座取得永久突进。E12 击杀是这次选择的策略，生产拾取没有硬编码要求必须清掉该敌人。双跳绕左边台座实体返回原苔灯并实际 F 休息。
4. 经原藤井、东螺旋梯、爬行道实体外缘到钟骨长梯站厅。实际按 dash，观察到 `ability_action("thread_dash")` 一次、正 `dash_timer=0.143333…`、165.75390625px 水平位移，随后 timer 自然到 `-0.006666…`（非活动）、冷却 0.4→0。没有主动取消键；本次没有观察到活动突进被真实伤害中断，受伤／下劈反弹／死亡的打断路径不计入本批自然流程覆盖。
5. 取得前已断言原 `gate_dash_cache` 实体仍关闭、静靴未收。取得能力后该门按原“拥有能力”条件移除；这与另行实际执行突进的证据分开，不冒称 dash 动作或 F 触发开门。实际穿门进入织线暗室，接触原 `col_quiet_sole` 自动拾取静靴×1，继续接触和离开后返回不重复。该物品不是手动 F 拾取；暗室的 F 标识属于邻近生产通路。沿原站厅、主路低爬道回初鸣钟龛实际 F 安坐。
6. 第五个独立 PID 从实际终态存档恢复，精确核对钱包、每件物品数量、全部构筑、故事／地图待补绘状态、拾取标记、捷径和钟龛，确认永久突进、原门放行、静靴恰好一件、满生命／能量且无动作计时残留。

## 正式结果与准确基线

`final_native_02/campaign.json` 是最新主线 `5f1fa82663fca3df131f3d9d5e6a65483b1a232c` 已正常整合后的完整正式 GL 链。工作分支冻结头 `9b80b1c2`，本批三个新 helper 明确纳入冻结；各阶段输入 save/proof 也纳入前后哈希。引擎命令使用 GL compatibility、Dummy 音频、固定 60fps 与隐藏到屏幕外的窗口，每个引擎硬上限 180 秒；任意 ERROR、WARNING、非零退出、缺少完成标记或源码变化均失败。

五个真实 PID 依次为 33992、37836、36300、6788、8564；耗时 31.297／15.172／8.235／23.266／5.015 秒。67 步路线，1 次扣血、0 次耗能治疗、0 死亡；五阶段所有源码前后相等，全部零 ERROR／warning。音频在仍处树中时退役再有界 drain，原生各段分别观测 26／7／10／6／3 次播放，没有过滤退出诊断。

终态钱包 297→329，无交通支出；原 C4 普通战斗、C1 入口敌人、旧迷宫 E11 和祭坛 E12 共提供 32 碎钱。全部原有物品保留，精确增量为：苔壳 2→5、蜡 19→20、心结 1→2、`thread_dash` 0→1、`quiet_sole` 0→1，21→23 种物品。构筑与初始种子深度完全相等，静靴没有被偷偷装备或替换为别的被动。C1 地图仍未购买，保留实际 pending 笔记，不冒称已补绘。

`final_headless_01` 是截图和门前置断言增加前的五 PID 链，`final_headless_02` 是门前置断言增加后、实际再踏入补充前的五 PID CPU 链；这两者基于较早主线 `8ee6e353…`，五阶段均零 ERROR／warning、零死亡。CPU02 耗时 39.688／28.328／15.110／47.906／8.187 秒，1 扣血、0 治疗。本批没有将这些旧主线 CPU 结果转记为新主线重跑；最新素材整合后的完整证据是上述原生链。

`final_headless_03` 是主线5f整合后、补齐重入的最终同 helper 五PID链，23.250／18.578／8.125／23.218／4.719秒，全零ERROR/warning、1扣血/0治疗/0死亡。`final_native_01` 的旧65步完整链也全部通过（2扣血/1治疗/0死亡），但没有实际再次踏入暗室；该缺口明确补进上述 native02，不把旧轮冒称新覆盖。正式五PID共同冻结文件哈希在 `final-summary.json` 再次核对一致。当前证据属于5f主线当时固定5生命/100线的历史范围，不证明未来容量升级修复已被此轮验证。

`negative_proof_01` 在早期正式 CPU 存档上验证九类拒绝；`negative_proof_02` 使用 native01 实际终态 save/proof 验证；`negative_proof_03` 在补齐真实重入后的最终同 helper CPU03 save/proof 上再次验证。三批九类均通过。钱包错误、静靴数量 1.5、构筑槽 0.5、剧情、拾取标记、捷径、钟龛、缺失 PID、区域错误均实际为 exit 1、恰好一个精确状态断言失败、没有额外警告。没有整型截断吞掉小数。

静态命令 `npm test` 与 `npm run test:campaign` 初轮因 Windows 默认 GBK 解码 UTF-8 文件失败，原日志保留；设置 `PYTHONUTF8=1` 后两条原命令均 exit 0。新 Python helper 通过 AST 解析，源文件按 LF 保存。

## 画面与失败保留

三张 1280×720 实际原生画面已经逐张打开检查，分别是活动突进、原暗室静靴收取提示、初鸣钟龛安坐；没有定位角色来取图。

- [活动突进](../../artifacts/w03_earned_dash/final_native_02/stage_4/actual_dash_active.png)
- [原静靴提示与邻近通路 F](../../artifacts/w03_earned_dash/final_native_02/stage_4/original_quiet_sole.png)
- [返回钟龛安坐](../../artifacts/w03_earned_dash/final_native_02/stage_4/rested_first_bell.png)

`headless_01` 至 `headless_43` 全部保留，包括错误路线、碰壁、死亡和失败断言。先前尝试 C3 底部逆向墙沿没有形成可靠回程，本批没有挖通地形；最终改走真实已有的 C5→C3 上层互联。后续诊断解决的是输入跳跃采样、低顶实体绕行、选台阶和回程落点。CPU39 在最新 guard 图片缓存尚未恢复时出现 11 个编译／资源 ERROR 及一个退出 warning；CPU40 路线失败伴一个未归因 ObjectDB 退出 warning，没有把它算成已修复。正式结果严格零警告。

恢复新主线 guard／heal／六 Boss 的八组导入缓存时，只读匹配工作区，不改对方源码。PNG 原字节均与已发布 main 完全相等；六 Boss import 原字节相等，guard／heal import 仅 CRLF／LF 差异、所有参数规范化后相等。`cache-restoration.json` 记录两端原 SHA、缓存 SHA 和来源。原日志、源码快照及前后清单可按 manifest 的 gzip mtime=0 归档恢复，归档清单同时记录原文与压缩字节的 SHA-256。

## 尚未完成

静靴原说明承诺“陷阱触发判定略微缩小”，但本主线只把旧 Charms 奖励收进背包，未接入当前行旅槽和实际陷阱检测。`_add_inventory_item` 的通用 category 处理只有 Tools／Relics／Materials，Charms 是背包展示分组；BuildSystem 的 unlock_item 目录也没有静靴映射。本批证明了原回访关口、原奖励收取与保存，没有证明静靴功能已经生效。该真实奖励价值缺口保留给下一独立 E03／W03 修复，不改文案消掉原承诺。心结容量功能也不在本批验收范围。

两处回访目标、更多能力／构筑、陌生玩家理解、实体手柄、自然突进受伤中断、长期性能和完整六区仍 OPEN。实际输入脚本不是人工体验记录，三张瞬时截图不是长期性能证据。

## 复跑

```powershell
python tools/run_earned_dash_return.py --engine <Godot-4.6.1> --campaign --native-gl --log-dir <new-empty-output>
python tools/verify_earned_dash_proofs.py --engine <Godot-4.6.1> --save <output>/stage_4/earned_save.json --proof <output>/stage_4/stage-proof.json --log-dir <negative-output>
```

正式复跑使用 `--campaign`，不得将诊断中途 save 冒充完整初始链；单段 `--stage` 参数用于定位。图像、JSON save/proof 保留可读原件，其余归档和原文哈希见 `artifacts/w03_earned_dash/manifest.json`。
