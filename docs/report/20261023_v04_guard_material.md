# V02/V04：主角格挡三素材运行时接入

2026-10-23，基于 main `79024ff7026520b161570f53594136dbe463a255`。本批只接入已交付的 FX_H2_guard_raise/block/perfect 三张源图，不重新出图；52 项中其余49项不在本批范围。46项最终验收全部保持 OPEN，组件验证不冒充自然探索或整合混战验收。

## 接入与语义

`player_guard_art.gd` 共用一张1152×576 RGBA atlas（192方格，3行×6帧）。素材原图实际1536×1024且实际切格不等于期望384方格；manifest记录原始SHA、sidecar实际cel、alpha>24有效区域外扩14px裁框、保持家族统一比例的paint_rect。`tools/build_player_guard_art.py` 从交付原图和冻结裁框重建，raw PNG SHA保持 `a94cdf3f3f7bdd7d90abd9dca96f64cf7d2e07345cc5b0a277266e52d94b59f1`。三张源图、sidecar本身不改；source_delivery_checks.json逐张验证原图hash和六个实际cel一致。

Q和ward起手改用朝前半护幕：0/1/2起手→3持盾→4/5收势；持盾时间读取实际guard_timer，末50ms收势，不由帧数决定保护时长。普通挡击用铜丝撞凹，完美挡击用针尖反弹，分别80px/104px局部画布，护幕112px，角色仍为实际约84px身高。命中后立刻撤护幕，只播放实际结算类型的反馈。Q仍8线量、0.42秒、前0.14秒完美、完美返还4；ward仍读取技能参数且上限0.65秒，防御技能不返还；前后侧/不可格挡/伤害/无敌/冷却都未改。

普通反向移动在guard_timer>0时保持锁朝向；现有墙跳分支可在防御期间翻面。实际输入分别验证两者，因此持续护幕绘制时取当前facing；已经发生的block/perfect保留接触时朝向，之后转身不会翻转历史撞击。未改生产转身或墙跳规则。

护幕接入共享state预算（12个、全secondary24个），保留旧护幕绝对Z60（上限75），挡击接入contact预算12个、Z80，危险100/预警110保持更高。预算饱和只丢装饰，不改变保护和返还。用已有Player预加载路径加载单一atlas，无新异步任务、计时器或额外资源所有者。无全屏闪光/震屏。低闪光模式在入树前设置稳定frame2/.65护幕和frame3/.55接触；第一_draw即可受限，不等_process。reset、真实伤害、死亡和离树清理新增节点，实际timer归零也在draw前检查。

## 验证与证据

新增默认 `player_guard_art`，默认含叙事合计140套；runner成功正则与合同数量同步。最终CPU `final_cpu_04`：guard113/0、player_state_cleanup、ui_build_accessibility全通过且零ERROR/warning。最终native `final_native_04`：guard113/0、截图fixture failures0，两PID源码及seed共13项冻结前后相同、每个进程严格180秒上限。另 `final_native_02` 的既有seal_combat194/0（内含player_skill_art254/0）、combat_visual_budget均干净通过；这两套之后没有生产改动，无重复运行挑选绿灯。

验证定位生产Player，直接damage检查前/后侧、普通/完美、不可挡和返还；Q、ward和墙跳/反向动作通过实际Input调用。它是机制/渲染组件夹具，不是自然流程。旧表现反向fixture保留相同生产Player，仅恢复三个原 `_ability_ring(46/56/64, THREAD_T3_CORE)` 调用；`negative_legacy_03`真实exit1、17个表现断言失败，基本保护/伤害规则仍可通过。退役pending0。默认runner合同31项（1执行、30需环境项跳过）通过；atlas重建字节相同。

最终12张960×540原生图：baseline/raise/block/perfect两朝向、reduced_raise_first、reduced_perfect_first、ward_hold、cancelled，见 `artifacts/v04_guard_material/final_native_04/`。没有放大角色。普通挡击明确等实际timer退出0.14完美窗后才施加damage，类型断言通过；低闪光两张在创建后只await frame_post_draw，未先await process。两朝向普通vs完美各1673像素差异，前方有效像素均>15；低闪光首张前方最大RGB总和护幕498、接触320，正常对应截图643/657；这些是这组固定组件画面的读回值，不是通用舒适度标准。逐张看图确认单侧、无黑底/格线、角色轮廓可见。cancelled中新增护幕消失，但既有seal_presentation的ward小叉形符号仍短暂显示；本批不宣称取消了所有既有技能装饰。

## 保留失败与边界

所有原始log逐字节gzip mtime=0保存，manifest记录压缩前后SHA并验证还原；finalsource保存最终13项冻结输入（含原camp seed）。首次编辑器导入达到180秒上限，保留import.log；后续实际已导入atlas可读，无重复全量导入。first/second CPU为类型推断和夹具残留速度问题；fourth/fifth的音频退出WAV持有保留，sixth/seventh固定120ms等待仅为诊断，未称修复生产泄漏。最终复用既有audio_retirement：树内retire_tree、释放场景、结束fixture的AudioDirector静态缓存所有权、await drain并断言pending0。production音频未改。最早negative文件因Windows默认编码未生成导致FileNotFound，核对自己的命令行后停止该PID并保留日志；后续UTF-8真实负向执行见03。

native_01最初标为block的截图等待不足，实际仍在完美窗口，不能作为普通反馈证据。native_02新增family断言准确抓住这个fixture问题；同轮drain还准确发现落地SFX的有意静态缓存引用，未跳过/清空retirement待验对象，而按现有音频验证结束缓存所有权。最终组件图用native_04（native_03已修正timer但未补旧60层）。CPU01两旧GL像素suite拒绝Dummy，也原样保留，之后native02通过。早期失败不是抹掉或重命名成通过。

提交前实际审阅发现新护幕默认z=0，而旧圆环挂载前设z=60；纯色组件不能暴露CaveWorld岩层12、设施3–8对它的遮挡。已恢复旧absolute60并加默认精确层级断言。`final_native_04`新guard113/0和组件截图在这个修复后干净通过；World fixture04首轮类型推断parse失败保留，显式Node2D后只重跑World，生产/atlas/guard组件源码不变。`final_world_05`恢复发布camp原始seed SHA `91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b`，原检查点save_ch05_lower_loop坐标(190,1909.996)完全未移动，未授能力/状态，HP5、287钱包、100线量，以实际Q扣到92；图中护幕在营地设施前可见。world_guard.png/world_baseline.png为实际1280×720 World图，退出pending0/52ms、零ERROR/warning。组件图仍是定位夹具；World这次仅证明已发布检查点的正常Q和层级，不冒充重新跑完整自然路线。

本批不覆盖六章自然混战、全部角色专属动作、剩余49张v2素材、长时间性能/舒适度、发布包或整合退出；V02/V04与T03最终验收保持OPEN。README中“v1的39张尚未接入”已纠正为已有逐类运行时报告；源交付记录保持历史原文。
