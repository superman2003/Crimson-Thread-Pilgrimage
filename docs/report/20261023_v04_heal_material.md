# V02/V04：缝补蓄力、完成与中断三素材

2026-10-23。原分支从已发布guard提交b25及仅文档修正95a起步；安全保存自有差量后正常合并main `8ee6e353e6f0f6ccdb7133a6eb00b07cfdf39d7f`，正式验证以该main+本批差量为准。未改Player任何疗伤数值、损失/返还、无敌、动作姿态或三契印规则。46项最终验收全部OPEN。

## 素材、生命周期与范围

使用交付原图FX_H2_heal_channel/complete/interrupt，共8/6/6=20格，不新生成图、不改源图与sidecar历史交付记录。channel实际1774×887、complete与interrupt实际1536×1024，均按各sidecar真实rect_xyxy裁切，不照期望384方格盲切。运行时atlas为1536×576（192方格、8列3行，后两行各留2空格），原alpha>24有效范围外扩18px并限制在本cel内，保持同一家族统一像素比例、居中body锚点。manifest记录原图、sidecar SHA和source/atlas/paint矩形。`tools/build_player_heal_art.py`重建原atlas raw SHA相同：`ac7151fdb68f9fa644b879a24aa49e9a2ea078a11b0d44d30d813754313e2fc7`。source_delivery_checks逐张核对原图hash、sidecar hash及20个真实裁格。

新helper通过Player三处真实生命周期接入：已扣资源且reservation generation仍有效才开始channel；实际HP完成结算时只播放complete；只有heal_timer>0的实际_interrupt_heal才播放interrupt。满血、能量不足、忙碌/空中受限的拒绝无闪光；付款监听取消后不创建旧channel，替换预约只拥有新generation。channel逐次绘制检查heal_timer、heal_reserved_cost和generation，使用真实剩余时长取帧，0/1起手、2–5两轮持线、6/7收线；不是固定播放0.42秒。终态complete0.30秒、interrupt0.24秒，随后释放。任何新的channel清掉旧终态。

三契印仍读取catalog原规则：缝名60线/1HP/0.55秒、可空中；司铸80线/2HP/1.15秒、须落地、中断损失40；校录50线/1HP/0.9秒、须落地。各自已有治疗后机制、铜背扣减速、受伤/移动/跳跃/突进/构筑取消、付款重入边界及动画姿态不变。组件图里的三契印均沿用原heal动作，不声称本批新画了三套角色动画。

局部body素材画布channel108px、终态112px，实际角色约84px；channel正常透明度0.50避免遮住身体，低闪光0.34；终态正常0.75、低闪光0.40。低闪光在入树前初始化稳定channel frame2、终态frame3，首_draw即受限。全部装饰用既有state预算（同类12、全部secondary24），一项一个Node2D，absolute Z45延续旧heal ring45（旧线条44），高于岩层12/一般设施、低于danger100/warning110。预算拒绝只丢画面，不改资源结算。暂停由实际heal_timer/节点树处理冻结；reset清理、死亡或切树无新增残影。既有seal_presentation等其它系统的短符号不是本批新节点，不声称统一解决所有装饰取消。

## 验证与实际图像

新增默认player_heal_art，含叙事默认共141套，成功正则和数量合同同步。最终 `final_cpu_03` 五套均exit0且零ERROR/warning：新heal95/0、seal_identity4889/0、combat_resource_cycle146/0、player_state_cleanup及ui_build_accessibility。前两旧套覆盖三契印全部合法饰件与原资源事务；它们运行于最终同字节Player/helper，没有借用旧绿灯。runner合同31项（1执行、30需环境项跳过）通过。

最终 `final_native_04` 两独立PID顺序执行，严格每进程180秒：组件107/0（95机制/素材检查+12张保存检查，5.703秒），World failures0（10.297秒），全部零ERROR/warning；15项输入（Player、helper、两个fixture、main_level、build系统/catalog、原camp seed、atlas/manifest、builder、runner及默认注册合同）冻结前后相同，并逐份和git index raw SHA核对。原始stdout gzip mtime0归档并反解长度/SHA，finalsource保存全部15项原文。实际退休pending0：组件28ms、World7ms；复用现有retire_tree+场景释放+fixture静态缓存所有权结束+可观察drain，不用固定sleep冒充音频泄漏修复。

三契印组件使用定位生产Player、显式构筑/伤势设置，通过实际H与移动/跳跃/突进输入启动和取消；直接damage只是组件边界检查，不能算自然受伤。12张960×540实际尺寸PNG为crimson/bell/salt各channel/complete/interrupt，加reduced三类first。每个低闪光first在创建后只await frame_post_draw，不先await process。三契印各channel与完成/中断的实际像素差异>150，逐张看图确认缝线/闭结/断线不同、身体与面部仍清楚、没有黑底或格线。它们证明三契印在既有姿态与不同持续时间下的构图，不是三条自然升级线。

World为单crimson正常缝补证据：从已发布原camp seed SHA `91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b`字节恢复独有私人路径。初始(190,1909.996)、5HP/100线/287钱包、伤害开启；实际右走下阶，x923.46/y2069.091真实生产命中扣到4HP，左退并自然落到下层x767.0875/y2711.978，然后正常H花60线、完整结算到5HP/40线/287钱包。无写位置/HP/能力、无暂停敌人/无敌、无更改seed。三张1280×720原生图world_actual_injury/world_heal_channel/world_heal_complete与HUD吻合。脚本未定位具体攻击source ID，因此不把这次伤害归因到某个敌人的某一招；它证明实际生产场景通过正常输入受伤与H，不重称完整C5自然流程或三契印全部World验收。

## 反向证明、失败和未决

`negative_final_03`使用同一最终95项验证fixture，只将Player的start/interrupt接入撤回、成功时恢复原_spawn_heal_effect，不改机制。真实exit1、91检查中19个新素材/生命周期断言失败（条件图层/预约附加检查因无新节点跳过）；基本成本、HP和中断损失仍可通过。legacy_player.gd、执行命令/原文SHA与validator SHA保留，runtime临时副本删除。不是靠源码字符串或人为宣称旧行为失败。

首次atlas编辑器导入180秒超时原文保留；此时新PNG已导入并产生ctex，后续实际CPU/native均正常读取，没有重复全量导入。headless01/02与World01均为准备成功日志，负向01为预期失败，全部保留，未用改生产参数迎合脚本。正式冻结以后没有生产/测试/数据字节改动，仅补报告、归档和README进度。README将已接入更新为格挡+缝补6项，其余46项v2素材仍待接入。

三契印自然获得后的World全流程、全部受击招式、真实混战遮挡/舒适度、长时间性能和整合发布退出仍OPEN；本批不扩大覆盖承诺，不替代V02/V04最终人工验收。
