# 终局后果：结局改变六区钟龛，主线条件进旅记（N05）

修订方案 N05 要求“不同结局关联证据与明确选择；主线条件可追溯，隐藏终局可选，人物/环境后果可靠保存”。台账待验收项是“条件可追溯、存档与后果”。

## 之前的状态

结局本身已经完整：

- 无声王冠身后三道结局门。
- 「绯线改写」要集齐六份证词。
- 选择写进存档，带回滚。
- 25 位人物每人都有三种结局后的对话。
- 旅记里能看到结局条件和后果文字。

缺的有两处：

- **环境后果不存在**。结局数据里的后果标记（`world_bells_restored`、`world_crown_severed`、`world_contract_rewritten` 等）只写进存档，游戏世界没有任何地方读取它们。选完结局后，六个区域看起来和之前一模一样。
- **主线进度看不到**。旅记里的结局记录要等打倒无声王冠才出现。在那之前，玩家在旅记里看不到主线走到哪一步、还差什么。

## 改动

### 结局改变六区钟龛

每个区域选一处玩家常经过、不隐藏的钟龛：

| 区域 | 钟龛 |
|---|---|
| 苔钟庭 | 初鸣苔灯 |
| 铸雨渠 | 立管苔灯 |
| 盐白书库 | 天顶盐灯 |
| 断弦温室 | 树心暖灯 |
| 黑曜巡礼道 | 营地灯影 |
| 无声王冠 | 六印前廊灯，就在结局门旁 |

选定结局后，这些钟龛旁出现对应的变化，颜色与三道结局门一致：

- **重鸣**：钟架上的小钟摆动，声波一圈圈散开（金色）。
- **断冠**：一排挡潮板，脚下是起伏的水线（红色）。
- **绯线改写**：一块轮值牌，名字一行行轮流亮起（青色）。

每区每个结局都有一句提示和一段说明，共 18 段，写的是这个结局在那里留下了什么。例如断冠时铸雨渠的工人“拆下誓牌，钉成一排挡潮板，翻面刻着各自的名字”；改写时黑曜巡礼道点名，“有人应‘在’，也有人应‘这一轮我不守’”。文字与 `world_narrative.json` 里各结局的后果和人物结局后对话一致。

- 在结局门做出选择的同一刻，六印前廊就出现变化。
- 走近时，剧情横幅显示一次“区域 · 提示”，记录写进存档。用剧情横幅而不用普通提示，是因为场景紧挨钟龛，钟龛自己的“按 F 休息”会立刻盖掉普通提示。
- 场景画在路标后面，不挡路线指示。
- 所有变化都由存档里的结局选择推出，读档后自动重现，不需要额外保存。

### 旅记：主线进度与各地变化

- 旅记第一条是「失声契约 · 主线」，显示：
  - 五区守门者已击败几位（只显示数量，不列出还没到过的区域名）
  - 无声王冠是否已击败
  - 证词已取得几份，并说明集齐后第三扇结局门可以打开
  - 结局是否已选
  - 下一步指引
- 已选结局的记录新增“各地变化”：去看过的区域写出具体变化，没去过的写“回到那里的钟龛看看”。

### 数据校验

`validate_world_narrative.py`（`test:campaign`）新增检查：六个区域各有一处；锚点钟龛真实存在且不隐藏；三个结局都有样子、提示和说明。

## 验证

- 新增 `ending_aftermath` 套件（正式 World，31 项、0 失败，加入默认 CI）：
  - 选择前：旅记第一条是主线，守门者和证词计数正确，不列出未到达的区域名，没有任何钟龛变化。
  - 在无声王冠身后用真实结局门选择「断冠」：六印前廊当场出现挡潮板；主线记录写明已选「断冠」。
  - 走近时剧情横幅显示变化，钟龛提示盖不住它，不会重复显示。
  - 逐一前往其他五区：每区钟龛都是断冠的样子。把玩家放在场景正上方，能落在可站立的地面上，六区全部通过。
  - 旅记列出全部六区，看过的写出变化，没看过的提示去哪里看。
  - 重启后苔钟庭仍显示断冠的样子，看过的记录保留。
  - 重鸣、改写在同一钟龛各有不同的样子和文字。
- 受影响的回归通过：`narrative_outcomes`、四套叙事测试（`verify_world_narrative`、`verify_narrative_ui`、`verify_narrative_progression`、`verify_narrative_runtime`）、`world_resume_regression`、`world_integration`、`ui_world_integration`、`ui_redesign`、`chinese_story`、`story_guidance`、`silent_crown_experience`、`save_product`、`inventory_map`、`demo`、`all_chapters_demo`、`pilgrimage_overhaul`、`hidden_routes`、`cartography`、`world_map`、`world_interaction_safety`；`build_slots_ui` 在真实 GL 下通过。
- `ui_world_integration` 原先断言旅记恰好 2 条记录，现在多了主线这一条，改为 3 条并检查第一条是主线。
- `npm test`、`test:campaign`、`test:runner` 通过。

真实 GL 截图（`capture_ending_aftermath.gd`）：

![重鸣](../../artifacts/ending_aftermath/court_shrine_ending_a.webp)
![断冠](../../artifacts/ending_aftermath/court_shrine_ending_b.webp)
![绯线改写](../../artifacts/ending_aftermath/court_shrine_ending_c.webp)
![旅记：各地变化](../../artifacts/ending_aftermath/journal_aftermath_rows.webp)

## 文件范围

本批只动叙事相关文件：`world_narrative.gd`、`world_narrative.json`（新增 `aftermath_scenes`）、新的 `ending_aftermath_scene.gd`，`main_level.gd` 里新增的生成与提示函数，以及 `pilgrimage_interface.gd` 的旅记部分。没有动敌人、特效、构筑和存档代码。

## 仍待验收

- 实机：场景是否够醒目、文字是否合适（T04）。
- 目前只画在钟龛旁。更大范围的变化（例如断冠后的水位、改写后的居民）需要美术素材。
