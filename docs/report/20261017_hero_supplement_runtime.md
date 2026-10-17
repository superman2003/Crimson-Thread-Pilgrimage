# 主角补帧接入：跑攻与三个独立技能/战具动作

## 范围

基于 #102 `87149e4f` 的源素材，本批接入其中已通过审查的 4 张图、共 18 帧：

| 动画 | 帧 | 原来 | 现在 |
| --- | ---: | --- | --- |
| `run_attack` | 6 | 不存在；奔跑中出刀播放站姿 `attack_1`，双腿突然停住 | 新动画：前摇 2、斩击 2、收招 2，双腿保持奔跑步幅 |
| `skill_melee` | 4 | 借用 `attack_2` 原图 | 独立重斩 |
| `skill_wave` | 4 | 借用 `skill_control` 原图 | 独立剑波 |
| `item_use` | 4 | 借用 `skill_projectile` 原图 | 独立战具取用/投出 |

待机披风过渡（A）与空中循环（D）未接入：A 的三张披风插入后轮廓跳变反而从 11%–13% 增至 33%–47%，D 两帧之间腿部姿势不同、两帧循环会来回拍动，均待重绘。

## 素材打包

`tools/build_hero_supplement_motion.py` 只做裁切、缩放与留白，不插值、不重绘。

- **比例**：以头部大小对齐 v4 跑步图（`run_sheet.png`），各图相对比例 B 1.08、重斩 0.92、剑波 0.91、战具 0.86，再乘跑步共享比例 0.405660377。
- **注册**：v4 跑步各帧躯干中位列为 x≈200（±2）、alpha>24 脚底在第 287 行；新帧按同一躯干列与脚底行放入 384×384 画布。跑攻两张腾空帧抬高 4px，与跑步的腾空帧一致。
- **去除重复特效**：每格只保留最大的 8 连通轮廓及其 3px 抗锯齿边缘。剑波图里的青色剑气（10917/5807px）与战具图里飞出的瓶子（1742/1732px）被去掉；游戏本身会生成剑波和投射物，且主角特效使用红金配色。剑波第 2 帧剑身上贴着轮廓的少量青色光痕保留。
- 源图哈希与 `generation_manifest.json` 不一致时拒绝打包；`--check` 逐像素核对已提交的运行帧、`registration.json` 与 manifest 接线。

## 运行时

- 地面水平出刀（`attack_1`、上下方向分量 ≤0.5）且起手时水平速度 ≥ 最高速度的一半，本次攻击锁定为 `run_attack`；中途不切换画稿。站立出刀、下劈、空中攻击、钩索与钟印流派的 `attack_2` 保持原样。
- `run_attack` 的 6 帧按攻击阶段三等分：前摇、有效、收招各自线性推进两帧；攻击判定、时长和移动减速都没有改。
- 三个技能/战具动画只替换帧，选择逻辑与相位映射不变。

## 验证

- `npm test`、`npm run test:character-motion`（含新打包 `--check`）、`tools/validate_hero_v3.py` 通过。
- Godot 4.6.1 两轮资源导入通过（退出码 0；MetroidvaniaSystem 编辑器插件退出时的既有报错与 RID 泄漏保留在日志中）。导入自动重写的 `default_bus_layout.tres` 已恢复原字节。
- 无头模式回归：`hero_animation` 48 项、`player_motion_continuity` 1150 项（新增：奔跑出刀全程为 `run_attack`、6 帧按序推进、站立出刀仍为 `attack_1`），以及 `player_action_buffer`、`player_melee_feedback`、`player_state_cleanup`、`player_upgrade_regression`、`melee_recovery`、`build_slots`、`character_art_prewarm`、`expanded_character_motion`（3291 项）全部 0 失败。
- `player_layered_idle` 要求真实 GL；本机没有 Xvfb，无头运行 187 项 0 失败但按套件规则不计通过，需由 CI 的真实 GL 环境复核。
- 真实渲染的 World 实机截图：`artifacts/hero_supplement_runtime/world_capture.webp`。第 1 行为跑步 4 帧与跑攻 6 帧，第 2 行为待机、重斩、剑波，第 3 行为战具及一次真实输入奔跑出刀的实录 3 帧。本机实际帧率约 20 FPS，实录只采到 3 帧，其余为同一位置逐帧摆姿势截取。

## 仍待处理

- 披风过渡与空中循环待重绘后接入。
- 现有待机（分层披风）与 v3 攻击帧的画风、线条粗细仍与 v4 系列不同，跨动作视觉一致性继续 OPEN。
- 战具图的腰包第 1、3 帧没有、第 2、4 帧有，播放时会闪；如重绘可直接替换源图后重新打包。
