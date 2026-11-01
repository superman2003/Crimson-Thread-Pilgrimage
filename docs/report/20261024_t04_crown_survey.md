# T04：C6 地图、西环、第六证言及真实前廊龛

2026-10-24。本批完成自动正常 Input 的 47 步探索与独立 PID 精确回读，修复金库底部封住前廊龛的两个端角及一格派生岩体。最终 Boss / 结局留给紧接下一批；全部 46 项最终验收继续 OPEN。

## 真实来源与结果

原样输入 PR220 公开 seed `991da3aee7e085764c400b51792a48a28f9cf226cea89b50794d2c0610c03dae`，没有改动它的 HP5、心结1、钱包529或能力。先整合 PR217 容量/静靴/N02/防潮、PR219 素材，角色按真实已有心结恢复为 maxHP6 / HP5；正常 F 下环休整才补到6。没有免费补满或授予 dash。

正常跳到六印守望者前廊、F 打开商店，读取实际报价55后 Enter 购买：529→474。实际返下环 F 使已购地图合法补绘。沿西环、黑曜和盐白回声上行；使用已有二跳和蹬墙规则，控制器在移动净空段不连按攻击，战斗段使用已有 cleave / 普通攻击，伤害和所有敌人参数保持。

实际击败 E07/E13/E08/E12/E09/E10/E14 共七敌；正常奖励7×8钱及精英额外30，所以474→560。冠碎片13+7+精英2+苔庭暗灯旁可选奖励3=25。正常 F 暗灯安坐、F 真实升降笼搭乘至上层，再 F 拾取 `col_testimony_06`；库存27→28种。当前 World overlay 没有将主路第六证言放进 R 门，旧 collectible note 不是运行条件；R 门在独立共鸣工房，本批未按 R、不声称打开它。

升降笼是作者已有物理移动篮，F 请求后正常等待搭乘，没有调用 request 或直接写角色位置。冠肋直接上攀会顶住既有顶部实心 dock，改走免费笼不修改它。返程再 F 搭笼下降、实际侧绕及下落重返下环，清王座门槛守卫，正常 F 前廊龛。新 seed `artifacts/t04_crown_boss/earned_boss_door_seed.json` SHA256 `4bde536d3c3fe55a3df3b764a614fb8d45f7d3c9771a449dada44375f6bbe178`：钱包560、28种、冠碎片25、证言06、HP6/energy100、checkpoint `save_late_runback`；构筑/工具数与输入完全相同，无dash，地图owned且charted13/pending0，Boss解锁但未生成、无锁/无Boss音乐、未败。

## 真实净空缺陷与隔离修复

金库 `vault_floor` 顶面 [2500..2920,y2900] 原 terrain 深104，底3004；下面前廊两侧坡道的实际足点地面仅3045..3060，无法容纳34×84角色。自然旧路线 `west_approach_33` 已到门槛后右行返龛，在 (2937.006,3059.994) 被金库侧壁阻住。只读排查主路/World portal/lift，没有进入该龛的另一条作者路线。

定位夹具独立于 earned 流程：明确设置左右起点，暂停敌人/危险，禁用双跳/抓墙，普通角色碰撞与无无敌检查仍开启。相同最终夹具的旧数据分别卡 right (2937.003,3060) / left (2482.975,3045.439)，反向必须确切一个指定阶段 ERROR 才认可。首候选端64/80px深70失败，第二候选右进龛后反向仍卡；都保留，不能称修复通过。

最终仅将金库左80px底深104→54、右96px底深104→70，中央244px仍104，完整顶面/所有平台 ID、XY、材质和能力要求不变。实际斜坡由角色两端足点碰撞决定，不能只按中心地面算净空；最终左入口约91px、右入口90px。

削薄后另露出 CaveMass [2880,3072,32,64] 的上格阻在原前廊右坡。生成器的两个平台 protected 区在2858..2902之间漏了44px，bulk 岩体重新盖住已有坡面。仅对 C6 `throne_rest_b`→`boss_threshold` 原坡加100px头顶/3px足下 protected 带；实际旧/新栅格差只去掉一格 [2880,3072..2912,3104]，下格保留。

最终几何差在 `vault_geometry/geometry_delta_final.json`：terrain 仅去7264px²（左4000+右3264），区域由两端组成，联合边界 [2500,2954,2920,3004]；CaveMass仅去1024px²，无新增材料。所有无关 terrain 原记录（包括 cave_link）与平台、非几何字段保留。一次 terrain-only 准备漏了旧 cave_link，被差集检查抓出，candidate04 恢复后重新正反及自然重走；该中间数据不算最终修复。

最终六章旧/新双生成器隔离在 `vault_geometry/final_isolation/comparison.json`；C1–C5字节完全相同。沿用 PR220 的发布隔离原则，保留原已存在的 [1856,1088..1888,1120] 历史格；不将全重建 JSON 冒称与发布 JSON 逐字相等。

## 正式验证和边界

正式 `final_native_01`：47步25.14秒，0死、7次受伤、2次正常疗伤；新PID4.36秒，均180秒硬上限、零ERROR/退出ObjectDB warning，8923源前后相同。固定60仅调度自动输入，不是人工时间或FPS。

同最终原生定位旧右8.58秒/旧左8.59秒为准确预期失败；修后右8.45秒/左8.73秒普通双向通行、上层普通单跳均通过。最终 CPU47步29.34秒+新PID4.38秒通过；19错误证明逐字段拒绝，含非法小数及错误非空pending（避免原pending为空时错误case相等）。恢复比对全部库存/build/story/regions、地图、钱、HP/上限/energy、checkpoint、归途结、spawn、Boss状态以及真实PID变化。

新默认 `crown_vault_door` 同步 runner/markers/跨平台契约，实际合并集合154；默认夹具同时验证左右两侧。相关三套 crown_vault_door / crown_rain_slot / silent_crown_experience(427checks)通过。UTF8 Windows npm test / campaign 均成功。整合中将继承来的 fixed-fps 条件中连在一起的三套名称拆成三个独立项；不把旧标准runner的三套记录冒称固定60Hz。

早期缺素材缓存、解析、控制误起跳、危险受伤/死亡和中间几何失败均保留。旧继承死亡计数曾在钱包写回且HP仍0时重复记2，本批控制器改为实际正HP→0边沿计数，原日志不追改。定位/组件结果不替代自然证据。资源恢复仅在源PNG raw和import LF参数匹配后复制ctex/md5，来源与原始CRLF差异有清单。日志gzip mtime0可解回原字节，manifest与暂存raw检查约束归档。

Boss首轮额外诊断已有28HP手动开战与四招，但缺技能ctex，严格判失败，另留下一批现场；本报告不将它计作正式通关。前廊 seed 只有四份编号证言03..06，缺01/02，不能补flag称真结局完成。最终Boss完整胜利/战后返程/结局门条件、陌生玩家可读性与长期混战仍OPEN。

## 发布前外部父链整合

正式 native01 基线是 c9e1c5e；之后普通合入准确公开 PR217 `34eed2d0`、PR219 `354bc5cc`、PR220 `17695668`，保留完整父链为 `479143ad1557f81e43bcfd2ea80f435b235bb4ff`。对实际冻结逐项比较，既有快照只变化 quiet_sole_traps_validation / secondary_visual_budget_validation 两个别线夹具，另追加工具与静态目录合同；本批全部生产/控制器/数据输入原字节相同。不宣称发布全tracked树等于旧8923快照，亦不为无关夹具重复47步。

追加检查：最新 quiet_sole_traps 24项CPU通过；secondary 是 RefCounted 子夹具，初次误作独立suite被合同拒绝，保留dispatch失败记录；改用单独CPU wrapper调用实际子夹具5.83秒通过、source不变、零ERROR/warning，不冒充GL像素验证。整合后 npm test / campaign 再次均通过，默认集合仍154。
