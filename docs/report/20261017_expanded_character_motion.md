# 正式角色动作关键帧扩充

范围：默认 World 六区使用的40种普通怪、6位Boss、25名命名NPC，以及主角跑步循环。旧 Bestiary 和旧20Boss目录不计入覆盖。

| 范围 | 角色 | 原运行帧引用 | 现运行帧引用 |
| --- | ---: | ---: | ---: |
| 普通怪 | 40 | 480 | 1288 |
| Boss | 6 | 144 | 340 |
| NPC | 25 | 150 | 400 |
| 主角跑步 | 1 | 4 | 8 |

敌方/NPC共2028帧引用。帧数口径见下方，不把保留原姿态、跨状态复用算成全部新绘原画。

## 行为变化

- 正式敌人与NPC优先使用各目录 `motion_manifest.json`，保留原 `manifest.json`、原图集和肖像。旧资源仍有兼容入口和独立完整性回归。
- 普通怪从 idle2 / walk4 / windup2 / attack2 / hurt1 / death1，扩充至至少 idle4 / walk8 / windup4 / attack4 / recover4 / hurt2 / death3。
- Boss基础动作同样扩充；原有heavy/cast/phase及各自windup均保留，并逐项至少4帧。变化阶段、受击、攻击重新进入时从首帧重播。
- 收招选择独立recover，不再直接切回idle。前摇、有效、收招、非致命受击、死亡和Boss相变表现按原战斗时长播放，不扩大伤害窗口或改变冷却。
- NPC待机至少4帧、交谈至少6帧，另有greet/rest各2帧。正式对话仍使用talk；greet/rest是已备妥的素材，不据此新增行走或战斗状态。
- 主角跑步从4帧扩为8帧，继续按实际移动距离选帧。待机与其他能力动作保留既有序列。

## 首次加载

区域进入前及邻区预制角色创建前，按实际motion manifest枚举纹理并异步预热；NPC的原肖像图集也包含在内。角色共享最多两个后台纹理请求，取消区域任务不等待尚未结束的请求。未就绪时延后创建，避免在2ms主线程预算内触发不可抢占的首次PNG同步解码。正式区域还会预热全部角色，覆盖邻区落点top-k之外的远处NPC。

新增character_art_prewarm验收，在冷进程中确认预热后正式NPC、敌人及肖像创建sync_loads=0；区域准备/邻区预制回归同时覆盖。

## 素材与打包口径

使用内置image_gen，以各角色当前原画为参考分别补绘；每个 `motion_generation.json` 保存最终prompt、源参考、真实裁区、必要的component_seeds、scale、anchor_x和目检记录。数量、动作语义与网格以实际可用姿态为准，不按生成请求中的格数机械认定完成。

原源文件不覆盖。少量原有、完整且适合衔接的有效姿态继续保留，并在生成记录中标明；因此运行帧总数不等于全部新绘、互不重复的独立原画数量。没有用平移、重复单帧或跨姿态混合伪造动画中间帧。

`build_expanded_character_motion.py`复现裁区注册、统一比例及图集包装；可交错但不相连的姿态通过明确种子选取alpha>24的完整8连通轮廓，保留最近3个源像素范围的低alpha抗锯齿原RGBA；断开的真实道具使用额外种子。真实连体、截断、畸变或动作语义不符的姿态剔除或补绘。需要缩放/分离的帧放入 `motion_runtime.png`，原补绘sheet继续作为可复查输入。

锚点按实际行列的固定身体原点或经审查的脚底支点登记；长武器、伸手、大翼展开不再被紧包围盒的中心牵动。所有帧使用统一画布、注册尺度和脚底高度；待机/步态保留原循环周期。

## 验证与复查

- `npm run test:character-motion`：全71个正式敌方/NPC覆盖、逐动画最小帧数、完整裁区、透明边缘、重复像素、打包重现，以及主角8帧跑步接入。
- `expanded_character_motion` Godot回归：通过真实敌人configure、NPC factory及SpriteFrames检查所有角色；实际播放前摇/攻击/收招/连续受击/死亡，验证重播和完整序列呈现。
- 原画完整性、主角移动、敌人生命周期/可见性、Boss战斗等集中回归，详见本次验收记录。
- 新增 `expanded-character-motion.yml`，持续检查素材与生产链路。

[覆盖清单](../../artifacts/expanded_character_motion/coverage.json)、[角色总览](../../artifacts/expanded_character_motion/roster.png)、[前后对比](../../artifacts/expanded_character_motion/before-after.webp)。预览由真实manifest离线合成，非GPU录像；运行验收以Godot日志为准。

本次处理的是角色动画的姿态密度、切片完整性与播放衔接。素材检查与状态回归不能等同全部场景的帧时间基准；手绘帧之间仍有细微形变，最终审美观感可在对比预览及游戏中复查。

验收：严格双导入通过；全覆盖检查71角色/2028帧通过；主角8帧复现通过；npm test通过；8项角色/战斗集中回归与3项区域准备/邻区回归通过。[本次验收摘要](../../artifacts/expanded_character_motion/verification.json)。
