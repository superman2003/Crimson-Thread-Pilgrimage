# 怪物、Boss与NPC真实动画覆盖审计
审计日期：2026-10-16。源码基线：`e3e7d0a6c243ce45b9f9aae19aecc084e596d112`。范围：默认 `World.tscn` 的六个正式区域；单独列出 GeneratedMain、旧Boss注册表和旧Bestiary。只读审计，没有修改产品资源、代码、映射或进度文档，没有启动 Godot/GL、录屏、提交、上传或发布。

## 1. 结论与优先级
1. 正式World实际使用40种普通怪、6种Boss，共85个普通出生点和6个Boss配置；命名NPC为25个。怪物/Boss都被 `enemy_actor.configure()` 优先解析到 `original_creatures/<kind>/manifest.json`。旧Bestiary、旧20Boss目录的帧数不能算进当前角色完成度。
2. 当前敌方素材是52张PNG图集、624个不同裁区、624组不同可见RGBA像素；这不是624个单帧PNG。正常状态选择路径的裁区上界为576；另32个是驻守怪不应机械要求播放的walk帧，16个是四位Boss未被现有招式选择的基础windup/attack。受打断、计时和可见性影响，上界不等于实录显示数量。
3. 40种普通怪均为 idle2 / walk4 / windup2 / attack2 / hurt1 / death1。6位Boss另有heavy、cast、phase各2前摇+2有效帧，但各Boss实际招式不完全使用同一组动作。所有敌方收招都直接选idle，普通怪的两种不同招式共用同一套windup/attack。
4. 优先处理已目检的裁帧完整性问题：长武器/肢体跨格被截、下一帧带前一格残片；多位Boss技能裁区顶沿也带邻行残片。扩大帧数会保留这些缺陷。先净化源帧、登记完整角色，再针对真实动作缺口补关键帧。
5. 25套NPC图集共150个不同裁区/像素，实际只选idle2与talk2，共100个正常可选裁区。greet1/rest1存在但无当前调用；没有行走状态。对话、道路问答、愿望和交付都共用talk，叙事迁移是位置更新/重建。不能因此凭空增加行走、作战、死亡玩法或声称这些动画缺失。
6. 本审计确认静态覆盖、复用关系和明显裁帧/跳姿风险，不确认动态流畅、掉帧根因、加载性能、实际帧呈现或视觉验收通过。未开始生成新素材。

## 2. 证据口径与来源
- `E` = `godot/scripts/enemy_actor.gd`；`H` = `godot/scripts/hand_drawn_assets.gd`；`M` = `godot/scripts/main_level.gd`；`UI` = `godot/scripts/pilgrimage_interface.gd`。
- `C/<kind>` = `godot/assets/sprites/original_creatures/<kind>/manifest.json`；`N/<npc_id>` = `godot/assets/sprites/original_npcs/<npc_id>/manifest.json`。后文每行的kind/npc_id即给出精确资源目录。随报告的 `enemy-npc-animation-coverage.compact.json` 保留71个正式角色的状态/招式映射、逐帧atlas索引/region/margin、计数与manifest/PNG基线hash；完整逐帧像素hash、旧库存别名和边界明细保存在完整离线JSON中。
- 世界入口：`godot/project.godot:11`、`godot/scenes/World.tscn`；六区路径来自 `world_routes.json` 与 `world_routes.gd:48–51,103–105`，当前路线叠加没有新增/替换敌方与NPC清单。
- 敌方选择优先级：`E:395–456` 合并配置AI→物种combat→出生点encounter_profile，再强制选择存在的原创manifest；`E:1557–1572,1629–1652` 构建角色；`H:33–65` 构造AtlasTexture/SpriteFrames。
- 本次对2186个已读取文件核验基线：普通Git blob逐字节对应；1944个旧Boss PNG按Git LFS指针的SHA256和大小对应。全部匹配所列commit。工作目录的无关修改没有被当成本审计内容或覆盖。
- “独特像素”只表示解码内容不同，不证明骨架连续、动作语义充分或每张都是可接受关键帧。图集内不同裁区不等于不同文件；跨动画/跨角色重复必须去重。
- 正常选择上界576不包含8种驻守怪的32个walk裁区。静态代码仍有击退/返家路径可能请求walk后又被stationary定位复位；此为条件路径，未运行验证，不据此要求驻守怪步态。
- 运行性能、帧时间、状态切换实录、左右朝向录像和首尾循环均未测；不复用历史测试日志充当本次动态通过证据。

## 3. 真实共用选择器：状态 → 动画 → 源帧
| 状态 | 实际动画与源帧 | 选择与时序 | 缺口/边界 |
| --- | --- | --- | --- |
| 出生/闲置/威胁 | idle[0,1] | 3fps循环；E:1566,1685–1697 | 无独立转身/起步/停步桥；方向通常flip_h |
| 地面巡逻/追近/拉距/返家 | walk[0..3] | 9fps时钟循环；E:770–816,823–867,1007–1055 | 速度变化不改变9fps，需检查脚底滑移；不直接判定发生掉帧 |
| 飞行巡逻/悬停/追近 | walk[0..3]或idle[0,1] | 与地面同名选择器，加E:81–110程序纵向悬浮 | 不能要求足底接触；需优先检查翼尖/身体重心与俯冲衔接 |
| 驻守/固定施法 | idle[0,1] | E:82–84,771–774,1008–1010 | walk存在但不是正常移动状态；不机械补walk |
| 攻击前摇 | requested_windup[0,1]；没有则windup[0,1] | E:1244–1266,1752–1775；speed_scale=帧数/(manifest_fps×前摇时长) | 两源姿态各约占前摇一半；实际不按6fps固定播放 |
| 攻击有效/技能 | requested[0,1]；没有则attack[0,1] | E:1282–1330,1760–1775；按active时长缩放速度 | 两姿态覆盖有效段；程序冲锋/跳跃/弹幕/VFX不增加身体帧 |
| 收招 | idle[0,1] | E:1328–1348,1766–1767 | 无专用回收/站稳帧；跨动作直接切回idle |
| 非致命受击 | hurt[0] | E:460–499；普通怪recover 0.16s；Boss不强制进入hurt状态 | 单姿态+白闪+击退；Boss可被原状态下一次选帧覆盖 |
| 绊倒/错乱/诱饵/盐印 | 沿用当前动作、recover或普通移动 | E:25–75,739–769 | 状态/程序效果不代表新增身体动画；不把所有状态机械列为缺素材 |
| 死亡 | death[0] | E:504–540；0.05s后普通怪0.45s/Boss0.9s渐隐+下移+缩放 | 单张倒伏姿态，无连续倒地关键帧；渐隐不等于身体帧 |
| Boss半血阶段 | phase[0,1] | E:360–372；0.9s停顿，不选phase_windup | 复用技能phase；若之前已处于同名动画，不保证重启首帧 |
| 同名动画重复请求 | 保留当前同名动画 | E:1695–1697仅名称不同才play | 重复hurt/phase可能不从0重启；静态时序风险，需后续实录 |

所有当前原创manifest均无_left/_right身体序列；`E:1700–1727`在找不到方向动画时用flip_h。映像翻转没有增加源关键帧，也不等于已检验双向武器/姿态质量。

## 4. 40种普通怪：逐种覆盖
每行来源都是 `C/<kind>`；数字序列为 idle / walk / windup / attack / hurt / death，每个数字同时是该动画内部的不同裁区与不同可见像素数。所有40种各有12个manifest帧引用、1张atlas、12种独特裁区/像素，未检出精确别名；行为招式仍会复用动画。
| kind / 资源目录 | 章 | 形态 | I/W/U/A/H/D | 正常可选裁区 | 实际两招 | 优先边界 |
| --- | --- | --- | --- | --- | --- | --- |
| moss_larva | 01 | 地面 | 2/4/2/2/1/1 | 12 | 抬头咬击(melee)；蜷壳扑身(lunge) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 2帧 |
| spore_bellmaker | 01 | 驻守 | 2/4/2/2/1/1 | 8 | 孢子扇射(fan)；菌圈落点(pool) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 4帧 |
| bronze_moth | 01 | 飞行 | 2/4/2/2/1/1 | 12 | 铜翼俯冲(dive)；翼粉弧射(fan) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 6帧 |
| gear_sentinel | 01 | 地面 | 2/4/2/2/1/1 | 12 | 架盾反突(guard)；齿矛长刺(melee) | 4姿态步态/出入；两招共用2+2；收招→idle；已目检截断/残片 9帧 |
| corridor_heavy | 01 | 地面 | 2/4/2/2/1/1 | 12 | 钟壳滚撞(lunge)；重壳震地(wave) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 8帧 |
| bellroot_acolyte | 01 | 地面 | 2/4/2/2/1/1 | 12 | 铃杖敲击(melee)；贴地双钟波(wave) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 3帧 |
| drain_leech | 02 | 地面 | 2/4/2/2/1/1 | 12 | 吸血咬(melee)；渠虫弧跃(vault) | 4姿态步态/出入；两招共用2+2；收招→idle；已目检截断/残片 4帧 |
| pipe_thrower | 02 | 驻守 | 2/4/2/2/1/1 | 8 | 管弹曲射(mortar)；近身蒸汽反喷(beam) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 4帧 |
| waterwheel_knight | 02 | 地面 | 2/4/2/2/1/1 | 12 | 轮盾推进(lunge)；返轮刃(projectile) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 7帧 |
| rust_diver | 02 | 地面 | 2/4/2/2/1/1 | 12 | 锈枪跃刺(vault)；潜盔涌浪(wave) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 10帧 |
| bell_mote | 02 | 飞行 | 2/4/2/2/1/1 | 12 | 缓追钟珠(projectile)；铃蛾扑击(dive) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 3帧 |
| valve_crawler | 02 | 地面 | 2/4/2/2/1/1 | 12 | 阀轮滚撞(lunge)；排汽横扫(beam) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 4帧 |
| rain_censer_mote | 02 | 飞行 | 2/4/2/2/1/1 | 12 | 雨香落弹(fan)；香灰落圈(pool) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 4帧 |
| salt_bookmite | 03 | 地面 | 2/4/2/2/1/1 | 12 | 伏书钻咬(lunge)；啮页咬(melee) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 6帧 |
| index_scribe | 03 | 驻守 | 2/4/2/2/1/1 | 8 | 索引页扇(fan)；落点封印(pool) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 8帧 |
| page_duelist | 03 | 地面 | 2/4/2/2/1/1 | 12 | 虚晃退刺(feint)；双段追刺(combo) | 4姿态步态/出入；两招共用2+2；收招→idle；已目检截断/残片 4帧 |
| wax_lancer | 03 | 地面 | 2/4/2/2/1/1 | 12 | 熔蜡冲枪(lunge)；挑枪截空(melee) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 5帧 |
| erasure_bailiff | 03 | 地面 | 2/4/2/2/1/1 | 12 | 断页大刀(melee)；擦除直线(beam) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 7帧 |
| summoned_page | 03 | 飞行 | 2/4/2/2/1/1 | 12 | 环页散刃(nova)；折页俯掠(dive) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 4帧 |
| vine_crawler | 04 | 地面 | 2/4/2/2/1/1 | 12 | 藤口咬(melee)；三段根刺(rootline) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 3帧 |
| root_cage_hunter | 04 | 地面 | 2/4/2/2/1/1 | 12 | 根网投掷(projectile)；根笼扑刺(vault) | 4姿态步态/出入；两招共用2+2；收招→idle；已目检截断/残片 4帧 |
| wax_bee | 04 | 飞行 | 2/4/2/2/1/1 | 12 | 蜡蜂刺冲(dive)；双针连射(fan) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 1帧 |
| thorn_sentinel | 04 | 驻守 | 2/4/2/2/1/1 | 8 | 荆针轮射(nova)；根墙封路(rootline) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 3帧 |
| pollen_lutist | 04 | 驻守 | 2/4/2/2/1/1 | 8 | 弦音花粉(fan)；错位花粉圈(pool) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 1帧 |
| thorn_bloom_mote | 04 | 飞行 | 2/4/2/2/1/1 | 12 | 花种落刺(rootline)；花蕊针(projectile) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 5帧 |
| obsidian_spearman | 05 | 地面 | 2/4/2/2/1/1 | 12 | 黑曜直刺(lunge)；抬枪截空(melee) | 4姿态步态/出入；两招共用2+2；收招→idle；已目检截断/残片 6帧 |
| phase_censor | 05 | 飞行 | 2/4/2/2/1/1 | 12 | 侧移弯刃(blink)；审灯三刃(fan) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 5帧 |
| pilgrim_chariot | 05 | 地面 | 2/4/2/2/1/1 | 12 | 巡礼战车(lunge)；灰钉阵(pool) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 4帧 |
| silent_bugbler | 05 | 驻守 | 2/4/2/2/1/1 | 8 | 无声号阵(fan)；号口震波(wave) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 4帧 |
| kneeling_crossbowman | 05 | 驻守 | 2/4/2/2/1/1 | 8 | 锁线三矢(fan)；贴地重矢(projectile) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 4帧 |
| ash_banner_imp | 05 | 地面 | 2/4/2/2/1/1 | 12 | 旗枪三连(combo)；回旗退刺(retreat) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 12帧 |
| obsidian_bellwheel | 05 | 地面 | 2/4/2/2/1/1 | 12 | 黑钟滚撞(lunge)；双向钟涟(wave) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 4帧 |
| echo_waterwheel_knight | 06 | 地面 | 2/4/2/2/1/1 | 12 | 回声盾反(guard)；快慢双轮波(wave) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 12帧 |
| echo_moss_larva | 06 | 地面 | 2/4/2/2/1/1 | 12 | 回声潜扑(lunge)；迟发苔音(pool) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 3帧 |
| echo_thorn_sentinel | 06 | 驻守 | 2/4/2/2/1/1 | 8 | 双环荆针(nova)；间隔根刺(rootline) | 驻守idle/施法/收招；不补不存在的行走；边界候选待目检 7帧 |
| echo_contract_scribe | 06 | 飞行 | 2/4/2/2/1/1 | 12 | 冠页斜射(fan)；双落印(pool) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 4帧 |
| falling_clapper | 06 | 飞行 | 2/4/2/2/1/1 | 12 | 标记落锤(dive)；钟浪斜射(fan) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 3帧 |
| delayed_shadow | 06 | 飞行 | 2/4/2/2/1/1 | 12 | 迟影侧刺(blink)；影落封圈(pool) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 7帧 |
| echo_pilgrim_commander_minor | 06 | 地面 | 2/4/2/2/1/1 | 12 | 巡礼三枪(combo)；军旗落阵(rootline) | 4姿态步态/出入；两招共用2+2；收招→idle；边界候选待目检 10帧 |
| isotope_lumen | 06 | 飞行 | 2/4/2/2/1/1 | 12 | 光核环弹(nova)；延迟聚光(pool) | 翼循环/俯冲或施法衔接；两招共用2+2；收招→idle；边界候选待目检 3帧 |


## 5. 6位正式Boss：逐种、逐动画覆盖
每位来源都是 `C/<kind>`；每位2张PNG（atlas与attacks），12个动画名，24次帧引用，24个不同裁区/可见像素，无精确帧别名。以下“共用”是多种招式选择同一个动画，不是重复计算新图。
### 苔钟守母 · `rust_crown_guardian`
来源：`godot/assets/sprites/original_creatures/rust_crown_guardian/manifest.json`。正常选择裁区上界：24；未被现有命令选择：无。
| 动画 | 帧引用/独特裁区/独特像素 | manifest FPS/循环 | 真实用途 |
| --- | --- | --- | --- |
| idle | 2/2/2 | 3/循环 | 选择器可达；时序见逐招表 |
| walk | 4/4/4 | 9/循环 | 选择器可达；时序见逐招表 |
| windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| attack | 2/2/2 | 10/非循环 | 选择器可达；时序见逐招表 |
| hurt | 1/1/1 | 8/非循环 | 选择器可达；时序见逐招表 |
| death | 1/1/1 | 4/非循环 | 选择器可达；时序见逐招表 |
| heavy_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| heavy | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| cast_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| cast | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| phase_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| phase | 2/2/2 | 9/非循环 | HP相变与技能共用 |

| 招式ID / 名称 | 逻辑类型 | 前摇→有效→收招 | 秒 U/A/R | 实际身体源帧与复用 |
| --- | --- | --- | --- | --- |
| boss_moss_scythe / 苔镰横扫 | melee | `windup`→`attack`→`idle` | 0.68/0.24/0.7 | 2前摇 + 2有效；0专用收招 |
| boss_moss_stamp / 钟冠重压 | wave | `heavy_windup`→`heavy`→`idle` | 1.05/0.24/1.05 | 2前摇 + 2有效；0专用收招 |
| boss_moss_spores / 守庭孢子 | fan | `cast_windup`→`cast`→`idle` | 0.9/0.24/0.8 | 2前摇 + 2有效；0专用收招 |
| boss_moss_roots / 根冠苏醒 | rootline，二阶段 | `phase_windup`→`phase`→`idle` | 1.1/0.24/1.1 | 2前摇 + 2有效；0专用收招 |

边界：4帧walk；每段2姿态；hurt/death各1；phase还兼作半血变化；全部收招直接idle。优先净化裁区后检查长武器轨迹、技能↔idle、跨图集身份/比例/脚底一致性。

### 绯线执剪者 · `sunken_hammer_smith`
来源：`godot/assets/sprites/original_creatures/sunken_hammer_smith/manifest.json`。正常选择裁区上界：20；未被现有命令选择：`attack`, `windup`。
| 动画 | 帧引用/独特裁区/独特像素 | manifest FPS/循环 | 真实用途 |
| --- | --- | --- | --- |
| idle | 2/2/2 | 3/循环 | 选择器可达；时序见逐招表 |
| walk | 4/4/4 | 9/循环 | 选择器可达；时序见逐招表 |
| windup | 2/2/2 | 6/非循环 | 当前未直接选用 |
| attack | 2/2/2 | 10/非循环 | 当前未直接选用 |
| hurt | 1/1/1 | 8/非循环 | 选择器可达；时序见逐招表 |
| death | 1/1/1 | 4/非循环 | 选择器可达；时序见逐招表 |
| heavy_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| heavy | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| cast_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| cast | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| phase_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| phase | 2/2/2 | 9/非循环 | HP相变与技能共用 |

| 招式ID / 名称 | 逻辑类型 | 前摇→有效→收招 | 秒 U/A/R | 实际身体源帧与复用 |
| --- | --- | --- | --- | --- |
| boss_shears_close / 合剪夹击 | melee | `heavy_windup`→`heavy`→`idle` | 0.7/0.24/0.8 | 2前摇 + 2有效；0专用收招 |
| boss_shears_thread / 绯线封路 | beam | `cast_windup`→`cast`→`idle` | 1/0.24/0.8 | 2前摇 + 2有效；0专用收招；与其他招式共用cast |
| boss_shears_knots / 断线结阵 | pool | `cast_windup`→`cast`→`idle` | 0.9/0.24/0.5 | 2前摇 + 2有效；0专用收招；与其他招式共用cast |
| boss_shears_turn / 跃转双剪 | vault，二阶段 | `phase_windup`→`phase`→`idle` | 0.75/0.85/1.05 | 2前摇 + 2有效；0专用收招 |

边界：4帧walk；每段2姿态；hurt/death各1；phase还兼作半血变化；全部收招直接idle。优先净化裁区后检查长武器轨迹、技能↔idle、跨图集身份/比例/脚底一致性。

### 灰冠螳将 · `saltwhite_contract_judge`
来源：`godot/assets/sprites/original_creatures/saltwhite_contract_judge/manifest.json`。正常选择裁区上界：24；未被现有命令选择：无。
| 动画 | 帧引用/独特裁区/独特像素 | manifest FPS/循环 | 真实用途 |
| --- | --- | --- | --- |
| idle | 2/2/2 | 3/循环 | 选择器可达；时序见逐招表 |
| walk | 4/4/4 | 9/循环 | 选择器可达；时序见逐招表 |
| windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| attack | 2/2/2 | 10/非循环 | 选择器可达；时序见逐招表 |
| hurt | 1/1/1 | 8/非循环 | 选择器可达；时序见逐招表 |
| death | 1/1/1 | 4/非循环 | 选择器可达；时序见逐招表 |
| heavy_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| heavy | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| cast_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| cast | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| phase_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| phase | 2/2/2 | 9/非循环 | HP相变与技能共用 |

| 招式ID / 名称 | 逻辑类型 | 前摇→有效→收招 | 秒 U/A/R | 实际身体源帧与复用 |
| --- | --- | --- | --- | --- |
| boss_mantis_guard / 交刃反击 | guard | `cast_windup`→`cast`→`idle` | 0.9/0.32/0.72 | 2前摇 + 2有效；0专用收招 |
| boss_mantis_lunge / 灰冠长突 | lunge | `windup`→`attack`→`idle` | 0.72/0.52/0.85 | 2前摇 + 2有效；0专用收招 |
| boss_mantis_overhead / 冠刃下劈 | melee | `heavy_windup`→`heavy`→`idle` | 0.9/0.24/1 | 2前摇 + 2有效；0专用收招 |
| boss_mantis_flurry / 左右三连斩 | combo，二阶段 | `phase_windup`→`phase`→`idle` | 0.7/0.82/1.1 | 2前摇 + 2有效；0专用收招 |

边界：4帧walk；每段2姿态；hurt/death各1；phase还兼作半血变化；全部收招直接idle。优先净化裁区后检查长武器轨迹、技能↔idle、跨图集身份/比例/脚底一致性。

### 铜根主教 · `broken_string_gardener`
来源：`godot/assets/sprites/original_creatures/broken_string_gardener/manifest.json`。正常选择裁区上界：20；未被现有命令选择：`attack`, `windup`。
| 动画 | 帧引用/独特裁区/独特像素 | manifest FPS/循环 | 真实用途 |
| --- | --- | --- | --- |
| idle | 2/2/2 | 3/循环 | 选择器可达；时序见逐招表 |
| walk | 4/4/4 | 9/循环 | 选择器可达；时序见逐招表 |
| windup | 2/2/2 | 6/非循环 | 当前未直接选用 |
| attack | 2/2/2 | 10/非循环 | 当前未直接选用 |
| hurt | 1/1/1 | 8/非循环 | 选择器可达；时序见逐招表 |
| death | 1/1/1 | 4/非循环 | 选择器可达；时序见逐招表 |
| heavy_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| heavy | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| cast_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| cast | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| phase_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| phase | 2/2/2 | 9/非循环 | HP相变与技能共用 |

| 招式ID / 名称 | 逻辑类型 | 前摇→有效→收招 | 秒 U/A/R | 实际身体源帧与复用 |
| --- | --- | --- | --- | --- |
| boss_bishop_staff / 根杖敲击 | melee | `heavy_windup`→`heavy`→`idle` | 0.8/0.24/0.8 | 2前摇 + 2有效；0专用收招 |
| boss_bishop_seeds / 藤种布道 | fan | `cast_windup`→`cast`→`idle` | 0.95/0.24/0.5 | 2前摇 + 2有效；0专用收招；与其他招式共用cast |
| boss_bishop_roots / 循地根刺 | rootline | `cast_windup`→`cast`→`idle` | 0.9/0.24/0.5 | 2前摇 + 2有效；0专用收招；与其他招式共用cast |
| boss_bishop_cage / 交错根笼 | pool，二阶段 | `phase_windup`→`phase`→`idle` | 1.15/0.24/1.2 | 2前摇 + 2有效；0专用收招 |

边界：4帧walk；每段2姿态；hurt/death各1；phase还兼作半血变化；全部收招直接idle。优先净化裁区后检查长武器轨迹、技能↔idle、跨图集身份/比例/脚底一致性。

### 镜池新娘 · `silent_pilgrim_commander`
来源：`godot/assets/sprites/original_creatures/silent_pilgrim_commander/manifest.json`。正常选择裁区上界：20；未被现有命令选择：`attack`, `windup`。
| 动画 | 帧引用/独特裁区/独特像素 | manifest FPS/循环 | 真实用途 |
| --- | --- | --- | --- |
| idle | 2/2/2 | 3/循环 | 选择器可达；时序见逐招表 |
| walk | 4/4/4 | 9/循环 | 选择器可达；时序见逐招表 |
| windup | 2/2/2 | 6/非循环 | 当前未直接选用 |
| attack | 2/2/2 | 10/非循环 | 当前未直接选用 |
| hurt | 1/1/1 | 8/非循环 | 选择器可达；时序见逐招表 |
| death | 1/1/1 | 4/非循环 | 选择器可达；时序见逐招表 |
| heavy_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| heavy | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| cast_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| cast | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| phase_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| phase | 2/2/2 | 9/非循环 | HP相变与技能共用 |

| 招式ID / 名称 | 逻辑类型 | 前摇→有效→收招 | 秒 U/A/R | 实际身体源帧与复用 |
| --- | --- | --- | --- | --- |
| boss_bride_crescent / 镜杖弧扫 | melee | `heavy_windup`→`heavy`→`idle` | 0.6/0.24/0.65 | 2前摇 + 2有效；0专用收招 |
| boss_bride_mirror / 镜像侧刺 | blink | `cast_windup`→`cast`→`idle` | 0.9/0.24/0.7 | 2前摇 + 2有效；0专用收招；与其他招式共用cast |
| boss_bride_pools / 镜池迟影 | pool | `cast_windup`→`cast`→`idle` | 0.75/0.24/0.5 | 2前摇 + 2有效；0专用收招；与其他招式共用cast |
| boss_bride_dash / 月镜掠袭 | vault，二阶段 | `phase_windup`→`phase`→`idle` | 0.65/0.75/0.9 | 2前摇 + 2有效；0专用收招 |

边界：4帧walk；每段2姿态；hurt/death各1；phase还兼作半血变化；全部收招直接idle。优先净化裁区后检查长武器轨迹、技能↔idle、跨图集身份/比例/脚底一致性。

### 百钥守门人 · `silent_crown_core`
来源：`godot/assets/sprites/original_creatures/silent_crown_core/manifest.json`。正常选择裁区上界：20；未被现有命令选择：`attack`, `windup`。
| 动画 | 帧引用/独特裁区/独特像素 | manifest FPS/循环 | 真实用途 |
| --- | --- | --- | --- |
| idle | 2/2/2 | 3/循环 | 选择器可达；时序见逐招表 |
| walk | 4/4/4 | 9/循环 | 选择器可达；时序见逐招表 |
| windup | 2/2/2 | 6/非循环 | 当前未直接选用 |
| attack | 2/2/2 | 10/非循环 | 当前未直接选用 |
| hurt | 1/1/1 | 8/非循环 | 选择器可达；时序见逐招表 |
| death | 1/1/1 | 4/非循环 | 选择器可达；时序见逐招表 |
| heavy_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| heavy | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| cast_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| cast | 2/2/2 | 9/非循环 | 选择器可达；时序见逐招表 |
| phase_windup | 2/2/2 | 6/非循环 | 选择器可达；时序见逐招表 |
| phase | 2/2/2 | 9/非循环 | HP相变与技能共用 |

| 招式ID / 名称 | 逻辑类型 | 前摇→有效→收招 | 秒 U/A/R | 实际身体源帧与复用 |
| --- | --- | --- | --- | --- |
| boss_key_cleave / 百钥重劈 | melee | `heavy_windup`→`heavy`→`idle` | 0.85/0.24/0.9 | 2前摇 + 2有效；0专用收招 |
| boss_key_return / 回旋钥阵 | fan | `cast_windup`→`cast`→`idle` | 1/0.24/0.5 | 2前摇 + 2有效；0专用收招 |
| boss_key_gate / 冠门封线 | beam，二阶段 | `phase_windup`→`phase`→`idle` | 1.15/0.24/1 | 2前摇 + 2有效；0专用收招；与其他招式共用phase |
| boss_key_rings / 钥环震地 | wave，二阶段 | `phase_windup`→`phase`→`idle` | 0.95/0.24/1.1 | 2前摇 + 2有效；0专用收招；与其他招式共用phase |

边界：4帧walk；每段2姿态；hurt/death各1；phase还兼作半血变化；全部收招直接idle。优先净化裁区后检查长武器轨迹、技能↔idle、跨图集身份/比例/脚底一致性。

## 6. 普通怪104招中的80招：逐动作实际选择表
此表逐条列出40种×2物种默认招式；加上一节6Boss×4招即104个不同命令。所有普通招式前摇 `windup[0,1]`、有效 `attack[0,1]`、收招 `idle[0,1]`。前摇与有效速度由持续时间决定，不能拿manifest 6/10fps声称实际固定帧率。
| kind | 招式ID / 名称 | 逻辑类型 | 选择序列 | 秒 U/A/R | 单姿态约持有秒 U/A |
| --- | --- | --- | --- | --- | --- |
| moss_larva | larva_snap / 抬头咬击 | melee | windup2→attack2→idle2 | 0.25/0.24/0.55 | 0.125/0.12 |
| moss_larva | larva_curl / 蜷壳扑身 | lunge | windup2→attack2→idle2 | 0.65/0.32/0.8 | 0.325/0.16 |
| spore_bellmaker | bell_spores / 孢子扇射 | fan | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| spore_bellmaker | bell_fungus / 菌圈落点 | pool | windup2→attack2→idle2 | 0.45/0.24/0.5 | 0.225/0.12 |
| bronze_moth | moth_dive / 铜翼俯冲 | dive | windup2→attack2→idle2 | 0.6/0.55/0.9 | 0.3/0.275 |
| bronze_moth | moth_dust / 翼粉弧射 | fan | windup2→attack2→idle2 | 0.45/0.24/0.5 | 0.225/0.12 |
| gear_sentinel | gear_guard / 架盾反突 | guard | windup2→attack2→idle2 | 0.7/0.25/0.7 | 0.35/0.125 |
| gear_sentinel | gear_spear / 齿矛长刺 | melee | windup2→attack2→idle2 | 0.48/0.24/0.5 | 0.24/0.12 |
| corridor_heavy | heavy_roll / 钟壳滚撞 | lunge | windup2→attack2→idle2 | 0.8/0.55/1.1 | 0.4/0.275 |
| corridor_heavy | heavy_stamp / 重壳震地 | wave | windup2→attack2→idle2 | 0.9/0.24/1 | 0.45/0.12 |
| bellroot_acolyte | root_staff / 铃杖敲击 | melee | windup2→attack2→idle2 | 0.55/0.24/0.5 | 0.275/0.12 |
| bellroot_acolyte | root_bell_wave / 贴地双钟波 | wave | windup2→attack2→idle2 | 0.72/0.24/0.5 | 0.36/0.12 |
| drain_leech | leech_drain / 吸血咬 | melee | windup2→attack2→idle2 | 0.35/0.24/0.5 | 0.175/0.12 |
| drain_leech | leech_leap / 渠虫弧跃 | vault | windup2→attack2→idle2 | 0.55/0.65/0.8 | 0.275/0.325 |
| pipe_thrower | pipe_mortar / 管弹曲射 | mortar | windup2→attack2→idle2 | 0.8/0.24/0.5 | 0.4/0.12 |
| pipe_thrower | pipe_backblast / 近身蒸汽反喷 | beam | windup2→attack2→idle2 | 0.65/0.24/0.5 | 0.325/0.12 |
| waterwheel_knight | wheel_charge / 轮盾推进 | lunge | windup2→attack2→idle2 | 0.7/0.4/0.5 | 0.35/0.2 |
| waterwheel_knight | wheel_return / 返轮刃 | projectile | windup2→attack2→idle2 | 0.75/0.24/0.5 | 0.375/0.12 |
| rust_diver | diver_vault / 锈枪跃刺 | vault | windup2→attack2→idle2 | 0.55/0.75/0.85 | 0.275/0.375 |
| rust_diver | diver_splash / 潜盔涌浪 | wave | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| bell_mote | mote_seek / 缓追钟珠 | projectile | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| bell_mote | mote_peck / 铃蛾扑击 | dive | windup2→attack2→idle2 | 0.48/0.5/0.7 | 0.24/0.25 |
| valve_crawler | valve_roll / 阀轮滚撞 | lunge | windup2→attack2→idle2 | 0.7/0.4/0.5 | 0.35/0.2 |
| valve_crawler | valve_vent / 排汽横扫 | beam | windup2→attack2→idle2 | 0.9/0.24/0.5 | 0.45/0.12 |
| rain_censer_mote | censer_rain / 雨香落弹 | fan | windup2→attack2→idle2 | 0.75/0.24/0.5 | 0.375/0.12 |
| rain_censer_mote | censer_cloud / 香灰落圈 | pool | windup2→attack2→idle2 | 0.45/0.24/0.5 | 0.225/0.12 |
| salt_bookmite | book_burrow / 伏书钻咬 | lunge | windup2→attack2→idle2 | 0.75/0.38/0.85 | 0.375/0.19 |
| salt_bookmite | book_bite / 啮页咬 | melee | windup2→attack2→idle2 | 0.28/0.24/0.5 | 0.14/0.12 |
| index_scribe | index_pages / 索引页扇 | fan | windup2→attack2→idle2 | 0.65/0.24/0.5 | 0.325/0.12 |
| index_scribe | index_seal / 落点封印 | pool | windup2→attack2→idle2 | 0.45/0.24/0.5 | 0.225/0.12 |
| page_duelist | page_feint / 虚晃退刺 | feint | windup2→attack2→idle2 | 0.48/0.26/0.38 | 0.24/0.13 |
| page_duelist | page_combo / 双段追刺 | combo | windup2→attack2→idle2 | 0.62/0.55/0.7 | 0.31/0.275 |
| wax_lancer | wax_charge / 熔蜡冲枪 | lunge | windup2→attack2→idle2 | 0.82/0.6/0.95 | 0.41/0.3 |
| wax_lancer | wax_high / 挑枪截空 | melee | windup2→attack2→idle2 | 0.45/0.24/0.5 | 0.225/0.12 |
| erasure_bailiff | bailiff_cleave / 断页大刀 | melee | windup2→attack2→idle2 | 0.85/0.24/1 | 0.425/0.12 |
| erasure_bailiff | bailiff_erase / 擦除直线 | beam | windup2→attack2→idle2 | 1.1/0.24/0.5 | 0.55/0.12 |
| summoned_page | page_orbit / 环页散刃 | nova | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| summoned_page | page_skim / 折页俯掠 | dive | windup2→attack2→idle2 | 0.5/0.55/0.7 | 0.25/0.275 |
| vine_crawler | vine_bite / 藤口咬 | melee | windup2→attack2→idle2 | 0.42/0.24/0.5 | 0.21/0.12 |
| vine_crawler | vine_roots / 三段根刺 | rootline | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| root_cage_hunter | cage_net / 根网投掷 | projectile | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| root_cage_hunter | cage_pounce / 根笼扑刺 | vault | windup2→attack2→idle2 | 0.55/0.6/0.5 | 0.275/0.3 |
| wax_bee | bee_dive / 蜡蜂刺冲 | dive | windup2→attack2→idle2 | 0.62/0.48/0.85 | 0.31/0.24 |
| wax_bee | bee_stingers / 双针连射 | fan | windup2→attack2→idle2 | 0.65/0.24/0.5 | 0.325/0.12 |
| thorn_sentinel | thorn_ring / 荆针轮射 | nova | windup2→attack2→idle2 | 0.85/0.24/0.5 | 0.425/0.12 |
| thorn_sentinel | thorn_wall / 根墙封路 | rootline | windup2→attack2→idle2 | 0.45/0.24/0.5 | 0.225/0.12 |
| pollen_lutist | pollen_arcs / 弦音花粉 | fan | windup2→attack2→idle2 | 0.85/0.24/0.5 | 0.425/0.12 |
| pollen_lutist | pollen_spots / 错位花粉圈 | pool | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| thorn_bloom_mote | bloom_seeds / 花种落刺 | rootline | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| thorn_bloom_mote | bloom_needle / 花蕊针 | projectile | windup2→attack2→idle2 | 0.5/0.24/0.5 | 0.25/0.12 |
| obsidian_spearman | obsidian_thrust / 黑曜直刺 | lunge | windup2→attack2→idle2 | 0.6/0.3/0.5 | 0.3/0.15 |
| obsidian_spearman | obsidian_raise / 抬枪截空 | melee | windup2→attack2→idle2 | 0.6/0.24/0.5 | 0.3/0.12 |
| phase_censor | censor_blink / 侧移弯刃 | blink | windup2→attack2→idle2 | 0.8/0.32/0.5 | 0.4/0.16 |
| phase_censor | censor_fan / 审灯三刃 | fan | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| pilgrim_chariot | chariot_charge / 巡礼战车 | lunge | windup2→attack2→idle2 | 0.95/0.65/1.15 | 0.475/0.325 |
| pilgrim_chariot | chariot_caltrops / 灰钉阵 | pool | windup2→attack2→idle2 | 0.8/0.24/0.5 | 0.4/0.12 |
| silent_bugbler | bugle_volley / 无声号阵 | fan | windup2→attack2→idle2 | 0.95/0.24/0.5 | 0.475/0.12 |
| silent_bugbler | bugle_pulse / 号口震波 | wave | windup2→attack2→idle2 | 0.65/0.24/0.5 | 0.325/0.12 |
| kneeling_crossbowman | crossbow_burst / 锁线三矢 | fan | windup2→attack2→idle2 | 1/0.24/0.5 | 0.5/0.12 |
| kneeling_crossbowman | crossbow_low / 贴地重矢 | projectile | windup2→attack2→idle2 | 0.8/0.24/0.5 | 0.4/0.12 |
| ash_banner_imp | imp_flurry / 旗枪三连 | combo | windup2→attack2→idle2 | 0.42/0.55/0.55 | 0.21/0.275 |
| ash_banner_imp | imp_retreat / 回旗退刺 | retreat | windup2→attack2→idle2 | 0.45/0.3/0.5 | 0.225/0.15 |
| obsidian_bellwheel | bellwheel_roll / 黑钟滚撞 | lunge | windup2→attack2→idle2 | 0.7/0.55/0.5 | 0.35/0.275 |
| obsidian_bellwheel | bellwheel_waves / 双向钟涟 | wave | windup2→attack2→idle2 | 0.82/0.24/0.5 | 0.41/0.12 |
| echo_waterwheel_knight | echo_wheel_guard / 回声盾反 | guard | windup2→attack2→idle2 | 0.8/0.3/0.7 | 0.4/0.15 |
| echo_waterwheel_knight | echo_wheel_wave / 快慢双轮波 | wave | windup2→attack2→idle2 | 0.9/0.24/0.5 | 0.45/0.12 |
| echo_moss_larva | echo_larva_burrow / 回声潜扑 | lunge | windup2→attack2→idle2 | 0.7/0.42/0.5 | 0.35/0.21 |
| echo_moss_larva | echo_larva_mark / 迟发苔音 | pool | windup2→attack2→idle2 | 0.6/0.24/0.5 | 0.3/0.12 |
| echo_thorn_sentinel | echo_thorn_double / 双环荆针 | nova | windup2→attack2→idle2 | 1/0.24/0.5 | 0.5/0.12 |
| echo_thorn_sentinel | echo_thorn_roots / 间隔根刺 | rootline | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| echo_contract_scribe | echo_scribe_pages / 冠页斜射 | fan | windup2→attack2→idle2 | 0.7/0.24/0.5 | 0.35/0.12 |
| echo_contract_scribe | echo_scribe_seals / 双落印 | pool | windup2→attack2→idle2 | 0.6/0.24/0.5 | 0.3/0.12 |
| falling_clapper | clapper_fall / 标记落锤 | dive | windup2→attack2→idle2 | 0.95/0.48/1.15 | 0.475/0.24 |
| falling_clapper | clapper_wave / 钟浪斜射 | fan | windup2→attack2→idle2 | 0.75/0.24/0.5 | 0.375/0.12 |
| delayed_shadow | shadow_blink / 迟影侧刺 | blink | windup2→attack2→idle2 | 0.95/0.24/0.5 | 0.475/0.12 |
| delayed_shadow | shadow_echo / 影落封圈 | pool | windup2→attack2→idle2 | 0.55/0.24/0.5 | 0.275/0.12 |
| echo_pilgrim_commander_minor | minor_lances / 巡礼三枪 | combo | windup2→attack2→idle2 | 0.75/0.7/0.95 | 0.375/0.35 |
| echo_pilgrim_commander_minor | minor_banner / 军旗落阵 | rootline | windup2→attack2→idle2 | 0.85/0.24/0.5 | 0.425/0.12 |
| isotope_lumen | lumen_orbits / 光核环弹 | nova | windup2→attack2→idle2 | 0.8/0.24/0.5 | 0.4/0.12 |
| isotope_lumen | lumen_focus / 延迟聚光 | pool | windup2→attack2→idle2 | 0.6/0.24/0.5 | 0.3/0.12 |

### 出生点覆盖：配置会覆盖物种节奏
已核对全部85个出生点与Boss配置。以下7个出生点显式覆盖attacks（共14条），动画映射未改变，但时长/首次冷却不同，不能拿物种默认时长代替实际遭遇。完整命令及来源在JSON。
| 正式配置 | 出生点 | kind | 命令 | 秒 U/A/R | 映射 |
| --- | --- | --- | --- | --- | --- |
| demo_ch01_moss_bell_court.json | E01 | moss_larva | larva_snap | 0.55/0.24/1.15 | windup2→attack2→idle2 |
| demo_ch01_moss_bell_court.json | E01 | moss_larva | larva_curl | 0.75/0.18/1.25 | windup2→attack2→idle2 |
| demo_ch02_rain_foundry_canal.json | E02 | pipe_thrower | pipe_mortar | 0.8/0.24/0.85 | windup2→attack2→idle2 |
| demo_ch02_rain_foundry_canal.json | E02 | pipe_thrower | pipe_backblast | 0.65/0.24/0.85 | windup2→attack2→idle2 |
| demo_ch02_rain_foundry_canal.json | E14 | waterwheel_knight | wheel_charge | 0.7/0.4/1.15 | windup2→attack2→idle2 |
| demo_ch02_rain_foundry_canal.json | E14 | waterwheel_knight | wheel_return | 0.75/0.24/1.15 | windup2→attack2→idle2 |
| demo_ch03_saltwhite_archive.json | E04 | page_duelist | page_feint | 0.48/0.26/1.05 | windup2→attack2→idle2 |
| demo_ch03_saltwhite_archive.json | E04 | page_duelist | page_combo | 0.62/0.55/1.15 | windup2→attack2→idle2 |
| demo_ch04_broken_string_greenhouse.json | E11 | root_cage_hunter | cage_net | 0.7/0.24/1.1 | windup2→attack2→idle2 |
| demo_ch04_broken_string_greenhouse.json | E11 | root_cage_hunter | cage_pounce | 0.55/0.6/1.2 | windup2→attack2→idle2 |
| demo_ch05_obsidian_pilgrim_road.json | E13 | pilgrim_chariot | chariot_charge | 0.95/0.65/1.15 | windup2→attack2→idle2 |
| demo_ch05_obsidian_pilgrim_road.json | E13 | pilgrim_chariot | chariot_caltrops | 0.8/0.24/1.2 | windup2→attack2→idle2 |
| demo_ch05_obsidian_pilgrim_road.json | E07 | obsidian_bellwheel | bellwheel_roll | 0.7/0.55/1.2 | windup2→attack2→idle2 |
| demo_ch05_obsidian_pilgrim_road.json | E07 | obsidian_bellwheel | bellwheel_waves | 0.82/0.24/1.1 | windup2→attack2→idle2 |

程序动作补充：dive按位置线性下冲；vault用sin抛物线并在收招复位高度；combo每0.20s可重新开放命中，但不因此新增身体帧；lunge/retreat/feint修改位移；blink跳位置；beam/pool/rootline等生成独立效果。依据 `E:156–200,1294–1334`。这些可以强化辨识，但不能当作身体关键帧数量。

## 7. 25个正式NPC：逐个状态与实际素材
每行均为独立的 `N/<npc_id>`，1张PNG、6个不同裁区/像素。等待/结束对话→idle[0,1]（2.5fps循环）；交谈/问路/问心愿/交付→talk[0,1]（4fps循环）。greet[0]（4fps）与rest[0]（3fps）没有当前选择调用。肖像是atlas里的另一个裁区用途，不是新的身体动画帧。
| 角色 | NPC ID | 章 | 实际资源ID | 真实状态→动画（引用/独特像素） | 未选资源/不存在的状态 | 可见缺口边界 |
| --- | --- | --- | --- | --- | --- | --- |
| 织线学徒 | npc_threadsmith_apprentice | 01 | npc_threadsmith_apprentice | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 守门朝圣者 | npc_gate_pilgrim | 01 | npc_gate_pilgrim | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核1帧边界；循环/切换未动态验收 |
| 升台绘图师 | npc_gear_cartographer | 01 | npc_gear_cartographer | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 后门司铃人 | npc_backdoor_sacristan | 01 | npc_backdoor_sacristan | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 回廊斥候 | npc_runback_scout | 01 | npc_runback_scout | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 管渠童子 | npc_canal_child | 02 | npc_canal_child | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 失聪铁匠柳 | npc_rain_smith_liu | 02 | npc_rain_smith_liu | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核1帧边界；循环/切换未动态验收 |
| 锈泵修女 | npc_sluice_nun | 02 | npc_sluice_nun | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核1帧边界；循环/切换未动态验收 |
| 半沉工头 | npc_drowned_foreman | 02 | npc_drowned_foreman | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核1帧边界；循环/切换未动态验收 |
| 盐页管理员叶 | npc_salt_librarian_ye | 03 | npc_salt_librarian_ye | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 沉默读者 | npc_quiet_reader | 03 | npc_quiet_reader | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核4帧边界；循环/切换未动态验收 |
| 逃亡书记 | npc_fugitive_scribe | 03 | npc_fugitive_scribe | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核3帧边界；循环/切换未动态验收 |
| 封蜡档案员 | npc_sealed_archivist | 03 | npc_sealed_archivist | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 老园丁弦伯 | npc_old_gardener | 04 | npc_old_gardener | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 蜂蜡商人蜜岚 | npc_beeswax_vendor | 04 | npc_beeswax_vendor | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 断弦歌者 | npc_broken_singer | 04 | npc_broken_singer | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 根笼囚徒 | npc_root_prisoner | 04 | npc_root_prisoner | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核4帧边界；循环/切换未动态验收 |
| 黑曜引路人 | npc_obsidian_guide | 05 | npc_obsidian_guide | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 盲钟骑士 | npc_blind_bell_knight | 05 | npc_blind_bell_knight | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核3帧边界；循环/切换未动态验收 |
| 灯影修女 | npc_lantern_sister | 05 | npc_lantern_sister | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 逃旗手 | npc_deserter_flagbearer | 05 | npc_deserter_flagbearer | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核2帧边界；循环/切换未动态验收 |
| 初代巡礼者回声 | npc_first_pilgrim_echo | 06 | npc_first_pilgrim_echo | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 待复核1帧边界；循环/切换未动态验收 |
| 旧王钟舌 | npc_crown_tongue | 06 | npc_crown_tongue | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 六印守望者 | npc_six_mark_keeper | 06 | npc_six_mark_keeper | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |
| 黑潮童声 | npc_black_tide_child | 06 | npc_black_tide_child | idle 2/2 → talk 2/2 → idle 2/2 | greet1/rest1；无行走状态 | 未触发边界候选；循环/切换未动态验收 |

选择证据：`M:4826–4866` 只创建idle；`UI:542–556`交谈选talk，`UI:588–592`关闭选idle；`M:5972–5993`与`UI:558–586`改变对话/交付内容而不建立新的身体动画状态。`M:1428–1438`更新叙事位置，没有步行迁移动画。
缺口只按实际需要列：低频双姿态idle/talk可能产生两姿态交替观感；idle↔talk没有专门抬手/收手过渡；当前相同talk循环覆盖各类交流。是否增加轻微呼吸、眨眼、手势回收由实录与角色身份决定，不能为了填表强制所有NPC同帧数。

## 8. GeneratedMain的36个NPC：共享模型单独登记
`godot/scenes/GeneratedMain.tscn`仍可载入generated配置，但它不是默认World入口。36个灰盒NPC ID都没有同名原创manifest，`H:75–82`按章节回退到下表六套正式NPC。每个实例仍只用idle2/talk2，不是36套原创人物。
| Generated NPC ID | 章 | 共享素材ID | 实际状态 |
| --- | --- | --- | --- |
| npc_ch01_05_1 | 01 | npc_threadsmith_apprentice | idle[0,1] ↔ talk[0,1] |
| npc_ch01_17_2 | 01 | npc_threadsmith_apprentice | idle[0,1] ↔ talk[0,1] |
| npc_ch01_29_3 | 01 | npc_threadsmith_apprentice | idle[0,1] ↔ talk[0,1] |
| npc_ch01_41_4 | 01 | npc_threadsmith_apprentice | idle[0,1] ↔ talk[0,1] |
| npc_ch01_53_5 | 01 | npc_threadsmith_apprentice | idle[0,1] ↔ talk[0,1] |
| npc_ch01_55_6 | 01 | npc_threadsmith_apprentice | idle[0,1] ↔ talk[0,1] |
| npc_ch02_05_1 | 02 | npc_canal_child | idle[0,1] ↔ talk[0,1] |
| npc_ch02_17_2 | 02 | npc_canal_child | idle[0,1] ↔ talk[0,1] |
| npc_ch02_29_3 | 02 | npc_canal_child | idle[0,1] ↔ talk[0,1] |
| npc_ch02_41_4 | 02 | npc_canal_child | idle[0,1] ↔ talk[0,1] |
| npc_ch02_53_5 | 02 | npc_canal_child | idle[0,1] ↔ talk[0,1] |
| npc_ch02_58_6 | 02 | npc_canal_child | idle[0,1] ↔ talk[0,1] |
| npc_ch03_05_1 | 03 | npc_salt_librarian_ye | idle[0,1] ↔ talk[0,1] |
| npc_ch03_17_2 | 03 | npc_salt_librarian_ye | idle[0,1] ↔ talk[0,1] |
| npc_ch03_29_3 | 03 | npc_salt_librarian_ye | idle[0,1] ↔ talk[0,1] |
| npc_ch03_41_4 | 03 | npc_salt_librarian_ye | idle[0,1] ↔ talk[0,1] |
| npc_ch03_53_5 | 03 | npc_salt_librarian_ye | idle[0,1] ↔ talk[0,1] |
| npc_ch03_56_6 | 03 | npc_salt_librarian_ye | idle[0,1] ↔ talk[0,1] |
| npc_ch04_05_1 | 04 | npc_old_gardener | idle[0,1] ↔ talk[0,1] |
| npc_ch04_17_2 | 04 | npc_old_gardener | idle[0,1] ↔ talk[0,1] |
| npc_ch04_29_3 | 04 | npc_old_gardener | idle[0,1] ↔ talk[0,1] |
| npc_ch04_41_4 | 04 | npc_old_gardener | idle[0,1] ↔ talk[0,1] |
| npc_ch04_53_5 | 04 | npc_old_gardener | idle[0,1] ↔ talk[0,1] |
| npc_ch04_62_6 | 04 | npc_old_gardener | idle[0,1] ↔ talk[0,1] |
| npc_ch05_05_1 | 05 | npc_obsidian_guide | idle[0,1] ↔ talk[0,1] |
| npc_ch05_17_2 | 05 | npc_obsidian_guide | idle[0,1] ↔ talk[0,1] |
| npc_ch05_29_3 | 05 | npc_obsidian_guide | idle[0,1] ↔ talk[0,1] |
| npc_ch05_41_4 | 05 | npc_obsidian_guide | idle[0,1] ↔ talk[0,1] |
| npc_ch05_53_5 | 05 | npc_obsidian_guide | idle[0,1] ↔ talk[0,1] |
| npc_ch05_60_6 | 05 | npc_obsidian_guide | idle[0,1] ↔ talk[0,1] |
| npc_ch06_05_1 | 06 | npc_first_pilgrim_echo | idle[0,1] ↔ talk[0,1] |
| npc_ch06_17_2 | 06 | npc_first_pilgrim_echo | idle[0,1] ↔ talk[0,1] |
| npc_ch06_29_3 | 06 | npc_first_pilgrim_echo | idle[0,1] ↔ talk[0,1] |
| npc_ch06_41_4 | 06 | npc_first_pilgrim_echo | idle[0,1] ↔ talk[0,1] |
| npc_ch06_53_5 | 06 | npc_first_pilgrim_echo | idle[0,1] ↔ talk[0,1] |
| npc_ch06_64_6 | 06 | npc_first_pilgrim_echo | idle[0,1] ↔ talk[0,1] |

GeneratedMain各章敌方仍按kind走同一个原创覆盖优先级，因此没有额外46套新源帧。完整离线JSON保留每个generated敌出生记录；不得和正式World出生点叠加成当前在线数量。

## 9. 旧20Boss注册表与旧Bestiary：资源在，当前World不选
旧Boss数据及注册验证使用boss_01…boss_20种类，而正式六Boss使用rust_crown_guardian等kind。配置字段、常量SPRITES或历史验证里有旧路径，不代表它最终赢过 `E:434–446` 的原创覆盖。旧目录全部仍作资产库存核计，不能作本次补帧已完成证据。
| 库存ID | 名字 | manifest引用 | 独特PNG/可见像素 | 基础I/W/A/H/D | 当前World选择 |
| --- | --- | --- | --- | --- | --- |
| boss_01 | 苔钟守母 | 127 | 120/120 | 2/3/6/1/1 | 否 |
| boss_02 | 绯线执剪者 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_03 | 灰冠螳将 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_04 | 铜根主教 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_05 | 镜池新娘 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_06 | 百钥看门人 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_07 | 烛脊兽 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_08 | 无面钟童 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_09 | 铁蔷薇女爵 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_10 | 菌墓驮碑者 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_11 | 金翅验尸官 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_12 | 绣骨圣徒 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_13 | 黑钟骑士 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_14 | 雨廊盲乐师 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_15 | 赤茧产婆 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_16 | 断阶巡礼王 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_17 | 银槲鹿灵 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_18 | 砂漏修女 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_19 | 青焰墓钟 | 150 | 96/96 | 4/16/8/1/1 | 否 |
| boss_20 | 绯庭终礼者 | 150 | 96/96 | 4/16/8/1/1 | 否 |

旧boss_02…20每套150次引用但只有96个不同PNG/像素，未定向基础动画与right方向/技能名有大量引用别名；旧boss_01为127引用/120个不同PNG。其18个动画名、完整逐帧别名组在完整离线JSON，compact只保留旧库存摘要。不要把同一个PNG被多个名字引用算多张新帧。
旧Bestiary另有46套runtime_keyframes manifest，均被当前同kind原创图集覆盖；JSON记录每个动画名与引用数，但没有把其未用像素重新计入当前624。`NPC_SPRITES`常量的旧静态头像未被当前_make_npc采用。`enemy_dummy.gd`为旧程序平移/翻转/变色的静态灰盒类，默认World构建走enemy_actor，不能混算为新物种。

## 10. 裁区与静态目检：先修完整性，再谈增加帧
本文的5张 `evidence-*.png` 联系表均为离线审查证据，未打包入源码；文件名是证据标签，不是仓库附件或链接。可在仓库按各行kind定位 `godot/assets/sprites/original_creatures/<kind>/atlas.png` 与对应manifest；Boss技能另取同目录 `attacks.png`，NPC取 `godot/assets/sprites/original_npcs/<npc_id>/atlas.png` 与manifest。compact也明确记录这些源定位。

对当前624敌方+150NPC身体裁区，alpha>128的相邻像素对检测发现 344 个裁区边缘有连续不透明内容跨出边界，其中 316 个属于正常可选动画。覆盖46敌种与13套NPC。它是自动候选，不是344个已确认视觉缺陷；粒子、紧裁和设计性分离部件必须人工复核。完整离线JSON保留每条边与像素对计数，compact保留逐角色候选数。所有裁区矩形都位于对应PNG边界内，这不排除裁错角色。
| 已目检对象 | 静态事实 | 证据 |
| --- | --- | --- |
| page_duelist / gear_sentinel / obsidian_spearman | attack[0]前伸武器在右边缘截断，attack[1]左沿出现跨格武器片段 | evidence-ground-priority.png |
| drain_leech / root_cage_hunter | attack[0]前伸口器/肢体跨格，下一裁区有分离片段 | evidence-ground-priority.png |
| sunken_hammer_smith | cast/phase系列部分帧顶沿含邻行残片，长剪也跨格；已对照原始attacks.png | evidence-boss-skills.png；原始attacks.png |
| silent_pilgrim_commander | phase系列上沿含大块邻行衣摆残片，部分cast帧也有顶部残片 | evidence-boss-skills.png |
| priority flight samples | 已核对walk命名实际是翼/身体姿态；部分攻击长附肢也有边界候选 | evidence-flight-priority.png |
| 6套章节回退NPC | idle两姿态与talk手势均可辨认；只有两帧；rest中的片段不能报告为实际idle/talk播放问题 | evidence-npc-priority.png |

目检范围：ground6、flight6、boss基础6、boss技能6、NPC6联系表及一张Boss原始技能图。其余角色已完成逐资源/逐状态/逐帧像素与边界核计，没有宣称逐帧人工视觉通过。联系表只还原当前region+margin，没有修图或生成新姿势，也不能替代角色实际比例、地面和镜头下的实录。

## 11. 后续独立素材目录批次建议（本次未执行）
建议统一候选根目录 `assets/proposals/enemy_npc_motion/<batch>/<actor_id>/`，包含 `source/`、`frames/`、`contact_sheets/`、`registration.json`、`coverage.json`、`review.md`。这是素材隔离目录建议，不改Player/敌人代码/正式manifest/状态映射。每批先锁1–2个代表角色和真实动作，再以审核结论扩展同类，不按全物种统一帧数。
| 顺序 | 角色/动作 | 先交付什么 | 通过后再扩展 |
| --- | --- | --- | --- |
| P0 源帧完整性 | 上节已确认长武器5种 + 2位Boss；再逐条复核边界候选 | 完整持械/四肢、无邻格残片的同姿态候选；保存原始图并标注替换对应裁区 | 不改变身份/比例/调色；完整性未通过不插更多帧 |
| P1 主路线地面攻击 | moss_larva、page_duelist或gear_sentinel | 根据真实两招区分咬/扑、虚晃/双段刺、架盾/刺击；补有效轨迹与回收站稳桥 | 覆盖windup→active→recover→idle及左右镜像；不预设每招都8/12/16帧 |
| P1 Boss大动作 | 苔钟守母先一招；再绯线执剪者跃转剪、灰冠螳将三连 | 各命中/方向改变点的清楚关键姿态，完整回收；先修跨格武器与顶沿残片 | 让phase技能与HP相变需要区分的身体姿态可独立审查；不修改现有选择器 |
| P2 移动与空中 | 一地面步态 + bronze_moth或wax_bee | 接触/经过/推离/回收的连续关系；飞行按翼周期和重心，不套脚底模板 | 起步/停步/反向、巡航→俯冲→返回分别检查；按角色实际短板加帧 |
| P2 驻守与远程 | spore_bellmaker、pipe_thrower、index_scribe选代表 | 只做idle/蓄力/施放/回手；不同投射机制需要时拆身体手势 | 不新增走路；8种stationary现有walk不作为交付目标 |
| P2 受击/死亡 | 上述先行角色与一Boss | 受力→回稳、失衡→倒伏关键姿态；保留当前伤害逻辑与溶解方案作为独立基线 | 先选最有辨识的材质/体型代表，不要求所有怪死亡长度相同 |
| P3 NPC交流 | 织线学徒、管渠童子、老园丁弦伯先行 | 保留角色轮廓的轻微idle；抬手→talk循环→收手，足底/持物固定 | 只覆盖现有idle与talk；greet/rest保持库存，不强行接入新状态 |
| 另案 库存/灰盒身份 | GeneratedMain共享36 NPC、旧20Boss | 清楚标注共享身份和未使用资产 | 未在World出现的库存不列入本轮优先补帧或地图接入范围 |

每份候选登记：角色身份参考、不可变比例、脚底/翼根/重心锚点、画布与缩放、武器握点、帧来源和内容哈希、预期动作段与实际命令ID、相邻/首尾检查、已接受/拒绝及原因。透明背景、手绘墨线/材质/配色保持现有角色标准；不得以平移、缩放、旋转或复制PNG冒充新身体原画。
验收顺序：源图完整性→同角色注册与逐相邻/首尾→实际动作所需段落完整→独立素材播放→由单一集成 owner 完成产品接入与实录。当前阶段只完成第一步之前的审计与计划，新增已接受关键帧=0。

## 12. 交付与复核
- 建议纳入源码：本Markdown与 `enemy-npc-animation-coverage.compact.json`（237,231字节，≤250KB）。compact有71个正式角色、104个默认命令与14条出生点命令覆盖、774次当前身体帧引用、状态选择边界、逐帧裁区与来源hash；旧库存不计完成度。
- 完整离线证据：`enemy-npc-animation-coverage.json`（8,003,056字节，未打包入源码），SHA256：`9bea2a9851a02882cb580a892ab607ff8a7479a60346f8f4d7715f1c2c7bee41`。compact保存同一SHA256、大小和完整统计，原文件保留未删。完整证据还含generated出生记录、旧库存逐帧重复关系、每帧像素hash、裁区边界明细与2186文件来源核验。
- 5张 `evidence-*.png` 是现有素材派生的离线预览；不是新原画，未打包入源码。`build_audit.py`、`enrich_audit.py`、`build_report.py`、`build_compact.py` 复算脚本同样离线保留；报告不依赖这些路径在仓库内存在。
- 已验证：compact JSON解析与≤250KB、71正式角色、104默认命令、14条正式出生点覆盖、774身体帧引用、完整证据SHA256不变、源文件匹配基线、缺失文件与越界矩形检查、选择器/配置合并和调用追踪。未运行：Godot、功能回归、性能测试、动画录像、动态视觉验收。

## 13. 小批完整性修复可行性：两例只读复核

结论：以下两例的前伸武器像素仍完整保存在原PNG里；被当前4列网格裁到邻格，不等于源图已经丢失武器。两个人物的轴对齐包围矩形重叠，因此仅扩大/移动AtlasTexture区域不能同时“保全武器”和“排除邻格角色”。margin/padding只能改变画布尺寸与注册位置，不能擦除矩形内部的另一姿态。这里需要区分“矩形重叠”和“原画像素真正互相遮挡”：前者不必立即重绘，可先做隔离候选中的逐姿态蒙版提取；本次没有执行。

坐标约定：`region=[x,y,width,height]`；连通体/检查矩形写作 `[x0,y0,x1,y1)`，右下边界不包含；源图均1536×1024。计数为源alpha>128的四邻域连通体，用于几何事实，不是新的通过验收阈值。

| 具体实例 | 当前region | 原PNG保留的内容 | 单矩形修复为何不足 |
| --- | --- | --- | --- |
| `gear_sentinel` attack[0]/attack[1] | [32,709,352,273] / [384,722,384,258] | attack[0]身体与完整前伸枪的主要连通体为[32,710,499,981)，37,756像素；下一姿态为[454,722,832,980)，34,472像素。第一把枪跨过x=384仍在PNG内，也没有碰到源图外边。 | 扩第一帧到[32,709,500,982)会连同1,583个下一姿态像素一起裁入；第二帧改取[453,721,833,981)仍会带入581个第一帧武器像素。两矩形重叠x=454…499，margin无法删除这些内部残片。 |
| `page_duelist` attack[0]/attack[1] | [18,715,366,251] / [384,707,384,257] | attack[0]主要持械姿态为[20,716,542,965)，28,577像素；下一姿态为[466,708,855,966)，23,892像素。前一把剑跨过x=384，完整剑尖仍在源图内；不是已被图像边缘切掉。 | 扩第一帧到[18,715,544,967)会带入1,966个下一姿态像素；第二帧改取[464,706,858,968)仍带入208个第一姿态像素。单一AtlasTexture矩形仍不能排除外来内容。 |

建议第一个小批先选gear_sentinel的两张攻击姿态：在独立素材目录保存完整现有原画，只分离属于各自姿态的像素，再按当前身体/脚底注册对应画布。无需改变enemy_actor或动作映射来验证候选。低alpha抗锯齿、披风边、枪尖和独立小部件应人工归属核查；不能直接把alpha>128的最大连通体当成最终抠图，避免损失半透明边缘。gear在alpha>0时两大姿态仍分别为[27,705,502,988)与[449,719,835,990)；低alpha边缘比核心更宽，需保留。

只有在逐像素复核发现原始笔画已被另一姿态覆盖、角色部件实质连成无法分开的共享图形、武器/手脚被PNG外边截掉，或分离后显示原画本身缺失时，才把该局部列为imagegen补绘候选。这两例目前没有证据要求全角色重绘；“无损蒙版可行”也尚未变成已产出/已验收素材。实际产品接入与实录由单一集成owner完成，本次分工保持只读。
