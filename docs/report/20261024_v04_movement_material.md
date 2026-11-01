# V02/V04：二段跳、贴墙与落地素材

2026-10-24。自有movement分支从已发布缝补a20起步；暂存自有差量后正常合并main `5f1fa82663fca3df131f3d9d5e6a65483b1a232c`，仅.gitattributes追加冲突，保留Boss与本批全部规则。最终提交直接基于该main，仅包含本批差量，不重复206/207。46项最终验收保持OPEN，不把组件夹具等同自然流程。

## 源材质与注册

使用FX_H2_double_jump/wall_grip/land，三张均实际1536×1024、每张6格，共18格。逐张读取sidecar真实rect_xyxy与alpha>24材质范围，外扩16px并限制在各cel内，原图/sidecar SHA和实际裁格全部一致。没有新生成或改写源图。atlas1152×576、192方格6列3行；manifest保存原cel、裁框、来源锚点、家族统一缩放和paint_rect。双跳/落地依据来源foot锚点50%/80%，注册到(96,154)，墙丝按contact50%/50%注册到(96,96)，同家族统一比例且所有帧以同一语义锚点对齐，避免逐帧bbox居中造成接地漂移。

`tools/build_player_movement_art.py`按原图与manifest可重复重建，raw SHA `44557032dd3e2744fb7256ff5f5bd1dc494b5b11a2fe71bd3f497ff92c3dd275`完全相同。本批用独立最小Godot项目、相同res://assets/vfx/player_movement/player_movement.png资源路径导入同一原PNG，再复制这一个新atlas的.import/ctex/md5到工作区；不重新导入数千张历史恢复素材。原PNG、资源路径、metadata和两份缓存SHA及真实导入日志见import_provenance/isolated_import_01。正式引擎均从该导入缓存读回18格，源码/图片最终索引字节再次核对；新PNG属性显式禁LFS filter/diff/merge/text。

## 真实触发与预算

Player只增加表现钩子：已实际消耗air_jump_available并写入原-650速度的二段分支才创建扇形；普通起跳、长按、锁能力或第三次按跳不创建。原蹬墙分支在实际wall normal侧创建短擦丝、方向快照不跟之后的facing乱翻；持续贴墙只在真实wall_sliding+is_on_wall+非地面边界进入时分配一个held节点，离开或取消立即撤掉。side latch即使预算拒绝也保持到真实退出，额度后来空出也不每帧重新分配。重新接触才可再创建。

落地仍只由原was_on_floor=false→is_on_floor=true触发，用同一move_and_slide前fall_speed；原音效>=620轻重阈值同步到尘土画布88/128px与0.18/0.24秒尾势，方向保留接触时facing；站立不反复触发。二段扇106px、墙丝52px，在34×84角色碰撞/约84px身体尺度下局部显示，不替代人物或增加碰撞。原速度、重力、次数、墙跳冲量、输入缓冲/跳跃截断、动作、镜头、伤害和能力获取均未改。

二段/蹬墙短尾为motion预算，持续贴墙为state预算，各类12、全部secondary24；失败只丢装饰，不改位移/消耗。Z保留原二段痕迹58、落地34，墙丝58；危险100/预警110始终更高，不落回absolute0。低闪光入树前设置稳定frame3/opacity<=0.4，普通0.8，之后只淡出不闪大屏。暂停冻结已有节点年龄/实际物理；UI取消/离墙/reset/死亡/切树释放节点和预算，弱owner引用不延长Player生命周期。沿用已有音频退役屏障，没有修改音频生产机制。

## 验证与范围

新增默认player_movement_art，含叙事默认143套，正则和合同数量同步。`final_cpu_03`：新91/0、ability_movement、player_motion_continuity1192/0、player_action_buffer32/0、player_state_cleanup全exit0且零ERROR/warning。随后只为负向夹具统一清掉预算setup前遗留的旧图形并防止append已被拒绝释放的节点，生产Player/helper未变；`final_cpu_04`新91/0再次通过，旧相关四套是03的历史同生产字节检查，不声称后来整个项目全部重测。guard/heal不重复运行。

`final_native_05`组件102/0（91项+11张保存检查），11张960×540实际尺寸图含二段扇、轻/重落地、左右贴墙、左右蹬墙、实际低闪二段，以及三类创建前低闪默认的局部检查/截图。实际Input验证锁能力/普通起跳/长按/第三跳拒绝、冲量与air预算、真正接地及620阈值、持续contact同实例、取消/死亡/暂停、motion与state饱和以及离开重入。低闪first的额外直接helper调用只是表现初始化组件检查，不冒称自然输入触发。轻重尘图实际像素差异>100；逐张看图确认接地、左右侧、身体轮廓、无黑底/格线。

World采用发布原camp seed SHA `91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b`字节，唯一私人路径，未写位置/HP/能力，damage开启。05正常原地二跳、落地、走到西壁、攀附/蹬墙均通过，但原camp大F招牌遮住部分二跳材质；05原图/日志/原16项源码保留。仅修改World取证正常输入：先实际右行45tick到(402.5229,1909.996)，再真实二跳等3tick中帧，招牌不再挡住扇形；随后正常落地、西行至(81.0119,1919.994)真实normal(1,0)岩壁、跳起后下降攀附、蹬墙离开。CPU world_cpu_06先通过，`final_world_06`单独native exit0/零ERROR/warning、4张1280×720图通过。Player/helper/atlas及组件fixture始终和05相同，没有为截图改玩法。最终(95.07513,1845.579)，HP5/线100/钱包287不变，正常已有二跳/攀附，dash始终false。该短段只证明已获得能力的正常跑跳/接触，不冒称全C5或获得能力全流程。

05组件与06World分别冻结16项输入，前后SHA不变，finalsource05和finalsource06原字节分开gzip保存；最终06全部16项与git index raw SHA逐份一致，其中只有World取证脚本比05改变。源码gd/py/json在正式前LF规范，之后无生产变化。原始stdout逐字节gzip mtime0、长度和SHA反解验证；实际音频退役pending0（05组件12ms、06World45ms）。固定60不是FPS/性能或人工舒适度验收。

## 反向与保留问题

旧图形mutant保留全部机制条件，只恢复原_spawn_double_jump_vfx/_spawn_land_vfx并撤新增墙丝钩子。最终同组件fixture `negative_final_04`真实exit1、81检查11项表现断言失败，基本原速度/能力/消耗仍通过；legacy_player与validator原文SHA、执行命令保留。03负向先发现预算setup残留旧land尘导致第12个motion filler被拒绝，typed数组又追加已释放Node；这次原始错误保留，04仅统一清理组件预算setup并对拒绝值不append，未改生产预算/物理来迎合测试。其余首次CPU/World成功日志和合并警告也保留，不覆写旧结果。

运行时登记只新增这三图：当前v2接入39/52、待13，不把源图交付当运行时全部完成；历史guard/heal报告数字不回填。V02/V04剩余材质、真实混战遮挡/舒适度、全能力自然获得、长期性能与发布整合退出仍OPEN，46项最终验收不勾选。
