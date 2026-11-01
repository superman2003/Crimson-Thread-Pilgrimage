# Boss 生效特效补漏与逐招接入

此前“52 张全部完成”只代表 v2 清单的源图交付，不能代表 Boss 全技能完成。v2 包含主角 22 张、Boss 24 招预警和 6 张蓄势，漏掉了近战／位移生效特效；预警源图也未连接到战斗，因此游戏仍显示通用线和圈。

本次补绘 **12 张／72 格生效特效**，通过内置 `image_gen.imagegen` 生成；同时接入已有 **24 张／144 格逐招预警**与 **6 张／36 格 Boss 蓄势**。共 42 张来源、252 格进入六份运行时图集。其余 12 招的弹体、地面陷阱、地波／根刺和光束沿用已接入的 v1 素材。范围是当前六章实际启用的 **6 个 Boss、24 招**；登记库中其余 14 套人物资源未在六章启用。

`incoming/` 保留选定的原始透明 PNG、实际生成提示词 `.txt` 和逐格测量／目检记录 `.json`。`prompts/` 与 [requests.json](requests.json) 是出图任务。7 张首轮源图因越过切格边缘被淘汰，重画后全部通过透明通道、独立帧留白与六格检查；没有用裁去溢出内容的方式伪装通过。

## 逐招覆盖

所有 24 招均使用 v2 的同名 `FX_T_<招式>.png` 预警；下面列出生效材质，不以预警素材冒充出招素材。

- **苔钟守母**：`moss_scythe` 苔镰横扫 → 新 `FX_X_moss_scythe`；`moss_stamp` 钟冠重压 → v1 `FX_W_quake`；`moss_spores` 守庭孢子 → `FX_P_spore`；`moss_roots` 根冠苏醒 → `FX_R_roots`。
- **绯线执剪者**：`shears_close` 合剪夹击 → 新 `FX_X_shears_close`；`shears_thread` 绯线封路 → v1 `FX_B_thread`；`shears_knots` 断线结阵 → `FX_A_snare`；`shears_turn` 跃转双剪 → 新 `FX_X_shears_turn`。
- **灰冠螳将**：`mantis_guard` 交刃反击、`mantis_lunge` 灰冠长突、`mantis_overhead` 冠刃下劈、`mantis_flurry` 左右三连斩 → 四张各自的 `FX_X_*`，分别表现交刃反切、低位突刺、高低下劈和三拍不同刀势。
- **铜根主教**：`bishop_staff` 根杖敲击 → 新 `FX_X_bishop_staff`；`bishop_seeds` 藤种布道 → v1 `FX_P_seed`；`bishop_roots` 循地根刺 → `FX_R_roots`；`bishop_cage` 交错根笼 → `FX_A_snare`。
- **镜池新娘**：`bride_crescent` 镜杖弧扫 → 新 `FX_X_bride_crescent`；`bride_mirror` 镜像侧刺 → 新 `FX_X_bride_mirror` 在离开与出现处表现镜片裂隙，再发射 v1 `FX_P_blade`（修正了原来的通用绿刺映射）；`bride_pools` 镜池迟影 → `FX_A_shadow`；`bride_dash` 月镜掠袭 → 新 `FX_X_bride_dash`。
- **百钥看门人**：`key_cleave` 百钥重劈 → 新 `FX_X_key_cleave`；`key_return` 回旋钥阵 → v1 `FX_P_key`；`key_gate` 冠门封线 → `FX_B_gate`；`key_rings` 钥环震地 → `FX_W_chime`。

运行时完整 ID 均带 `boss_` 前缀。每个 Boss 的相变使用对应 `FX_C_<kind>`，旧内部 `kind` 与正式人物名的对应关系继续沿用 v2 审计结果。

## 接入与边界

- `godot/assets/vfx/boss_skills/manifest.json` 登记源图哈希、实际切格、每帧锚点与缩放。`tools/build_boss_skill_art.py --check` 重建对照六份图集；只机械切格、对齐和采样，不改原始图或合成替代素材。
- `boss_skill_art.gd` 读取既有战斗计时。刀势／护刃跟随已承诺的朝向和碰撞尺寸；地面预警跟随逐个落点和各自延迟；光束使用实际遮挡截断后的长度、方向和半径。远程／跃击的局部蓄势不宣称预测整个飞行轨迹或落点。
- 生效、前摇、伤害、移动、反弹、根刺逐点延迟和取消规则继续由原攻击逻辑驱动。普通敌人与未知招式保留原有回退路径。
- 取消、死亡、切区和重置沿用原清理入口；随身素材随状态退出，已生成的独立危险物沿用原所有者生命周期。UI 暂停时素材读取的战斗时钟停止。
- 光束和圆形陷阱保留细边界辅助精确读范围，主体已是绘制材质。常规挥砍等不会再生成通用 `OriginalAttackWarning`／`Line2D`。
- v2 的源图交付状态与运行时登记已拆分：36 张已登记（Boss 30 张 + 主角格挡 3 张 + 主角缝补 3 张），另外 16 张主角源图仍待接入；本次不再将“源图齐”描述成“整个游戏特效齐”。

## 验证与画面

使用 Godot 4.6、NVIDIA OpenGL 3.3 Compatibility 运行；六个 Boss 均从正式 `configure` 路径创建，画面直接由生产脚本渲染。54 张原生截图覆盖全部 24 招、两种朝向、明暗背景、前摇开始／中段／末段、四个生效时刻、特效清理后与六套相变蓄势；这些是逐招检查画廊，不冒充整场玩家实战录像。弹体／地波按其独立寿命展示到释放后 0.6 秒，近战和其他危险物取各自的生效时间。

- [原生 GPU 画面与验证记录](../../artifacts/boss_skill_art/README.md)
- `boss_skill_art`：核对全部 24 招预警、12 张独立生效图、其余招式的实际材质映射、暂停、位移、墙体裁切和清理。
- 原有 `enemy_effect_lifetime`、`combat_visual_budget`、`enemy_visibility` 在原生 GL 上验证；普通敌生命周期、Boss 试炼、战斗、启动预算和资源预热回归另行运行。
- 仓库 `npm test`、v2 清单／交付记录校验、图集重建对照与双次资源导入均为本次检查项。确切通过结果见画面目录记录。

重新生成命令：`python -X utf8 art_requests/boss_execution_v3/build_list.py`。检查新源图：`python -X utf8 tools/build_boss_skill_art.py --inspect-sources`；该操作只更新记录，目检结论需人工确认。运行时检查：`python -X utf8 tools/build_boss_skill_art.py --check`。
