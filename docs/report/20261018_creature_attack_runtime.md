# 小怪专属攻击动作接入运行时（82 张源图、760 格）

## 背景

#107 把引擎改成按招式 id 查找专属动画（`<id>_windup`、`<id>`、`<id>_recover`，以及 `_charge` 蓄力循环和 `_travel` 突进循环），并为 40 种小怪写了出图说明。随后 82 张源图（760 格）陆续上传到 `art_requests/creature_attacks_v1/incoming/`，其中 8 张在 2026-10-18 按要求重画。但 incoming 的 README 写明源图“尚未接入运行时”，所以游戏里所有小怪仍在共用原来那一套攻击动作。本批把这些源图接进游戏。

## 接入方式

新工具 `tools/build_creature_attack_motion.py` 只计算登记信息，然后写入每种小怪的 `motion_generation.json`。像素仍由原有的 `tools/build_expanded_character_motion.py` 打包。源图字节不改，也不生成任何中间帧。

- **格到动画**：沿用写说明时的同一份格子规划（`design.py` + `build_docs.py` 的 `cel_plan`/`loops_section`）。82 张源图的格数全部与规划一致：
  - 新招和精英招的源图 `<id>.png` 拆成 `<id>_windup`、`<id>`（连击 6 格）、`<id>_recover`，按需再拆出 `<id>_charge`、`<id>_travel`。
  - 沿用招式的补循环 `<keep>_loops.png` 拆成该物种通用的 `charge`、`travel`。沿用招式本来就播通用的 `windup`/`attack`，引擎因此会接这两个循环。
- **分离**：每格用源图记录的 region 与 component seed，取出 alpha>24 的 8 连通块，并保留旁边的抗锯齿像素；相邻格画框重叠的部分不会带进来。
- **比例**：每张源图算一个打包比例，按“配对姿势的 alpha 面积平方根之比”计算。只看包围盒的话，武器、举手、下蹲都会让体型漂移。
  - 招式源图：用第 1 格前摇和最后 1 格收招（说明里画的都是“回到待机姿态”）对比现有待机第 1 帧。两者相差超过 12% 时只用收招那格。
  - 循环源图：对比它接续的那一格现有姿势，蓄力接最后一格前摇，突进接第 2 格出招。
- **水平锚点**：每格取 alpha 质量的列中位数（细长武器几乎不影响它），再加上配对现有姿势的“中位数到骨架原点”偏移。会位移的招式本身就由角色移动表现，所以身体留在骨架原点上，不在画布里再漂一次。
- **脚底**：沿用打包器的统一规则，轮廓底边对齐基线。

### 打包器改动（`build_expanded_character_motion.py`）

- 条目可以用 `source` 指向 `art_requests/*/incoming/` 下的源图。这类姿势一律打进 `motion_runtime.png`，运行时不会加载源图。
- `charge`、`travel`、`*_charge`、`*_travel` 标为循环。
- 运行时图集从“每格一个统一画布的网格”改为按姿势顺序的紧凑货架排列（最宽 4096），画布上的位置由 margin 决定。
  - 46 种怪物的运行时图集合计从约 577 MB 降到 473 MB（未压缩 RGBA），姿势数从 1628 增加到 2388。
  - 6 个 Boss 的画布、比例、偏移和每帧像素与改动前**完全相同**，只是图集位置变了。
  - 小怪因为新姿势更高，画布可能变高，偏移会同步补偿，现有帧在世界中的脚底位置不变。

## 结果

- 40 种小怪的 40 个新招、10 个精英专属招都有了自己的前摇、出招、收招。
- 有蓄力或突进循环的新招和沿用招式，按说明接上 `_charge`/`_travel` 或通用 `charge`/`travel`。
- 每种小怪仍有一招沿用原有动作，这是设计如此。
- 真实 GL 实拍：`artifacts/creature_attack_motion/` 下有 24 张截图，由 `tools/capture_creature_attack_motion.gd` 生成。截图用正式的敌人节点和 `_pose_sprite`，拍摄 40 种普通个体和 10 个精英在前摇、出招、收招中的画面。`capture.json` 记录了每张截图里每只怪当时播放的动画名和帧号，所有截图都没有退回通用动作。

## 验证

- `npm run test:character-motion`：新增登记 `--check`，71 个角色的打包重现检查全部通过。登记和打包反复重跑后结果不变。
- `expanded_character_motion`：4845 项全部通过，71 个角色、2788 帧。
  - 新增对 40 种小怪的逐招检查：除沿用招外，每招的前摇、出招、收招都选到自己的动画，共 40 个新招、10 个精英招。
  - 原有循环测试改用探针 id，并把沿用招式会接通用 `charge` 的行为写进断言。
- 通过的套件：`character_art_prewarm`、`enemy_ai_behavior`、`all_chapters_demo`、`boss_trial`、`ch02_demo`、`combat`、`enemy_effect_lifetime`、`enemy_encounter_roles`、`enemy_lifecycle_regression`、`enemy_visibility`、`first_court_experience`、`rain_foundry_experience`、`salt_archive_experience`、`greenhouse_experience`、`obsidian_experience`、`world_enemy_residency`、`world_neighbor_entities`、`melee_recovery`、`combat_resource_cycle`、`seal_combat`、`seal_acceptance`、`audio_retirement`。
- `enemy_atlas_integrity`：本机用 x11 + llvmpipe 真实显示直接运行，3325 项全部通过。运行器本身要求 Xvfb，本机没有安装。
- `npm test`、`npm run test:boss-assets` 通过。recovery-mode 双导入通过，与 CI 参数一致。
- 本机未通过但与本批无关：
  - 非 recovery 模式的冷导入在编辑器退出时报 RID 泄漏，与此前记录相同。
  - `npm run test:enemy-runtime` 要求“小怪只有一招”，自 #107 起每种小怪有两招，在 main 上同样失败，CI 没有运行它。

## 仍需目检（OPEN）

- **pilgrim_chariot**：新源图的车轮比例比原图大约 15%，布幔也更红。按身体面积对齐后，车轮看起来偏大。这是源图比例问题，修正需要重画，不应扭曲比例。
- **部分循环接续**：有些循环没有严格接上它所接续的现有姿势。例如 wax_lancer 现有前摇最后一格是举枪过顶，而蓄力循环画成平端枪。这属于源图层面，需要在实机里看是否需要重画。
- 本批只做登记、比例和锚点，播放时序沿用引擎原规则。连续播放的手感和逐角色比例最终以实机目检为准。
