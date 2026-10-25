# S03：地形挡住时敌人声音变闷，危险提示仍清晰

本批从台账 S03“遮挡距离、响度与危险优先”继续，起点为 main `2d849bfa`。所有 46 个任务包的最终验收仍开放。

## 改动前

敌人音效用 `AudioStreamPlayer2D` 在敌人位置播放，最远 900px 按距离衰减，但不考虑中间的地形：隔着一整面岩壁的敌人出招、受击、死亡声和同屋的一样响。之前只有“首次进战的警觉声”（`spatial_enemy_alert`）做了遮挡判断。声部预算已经让前摇等危险提示（声部优先级 0）在满载时抢占普通声音，这部分保持不变。

## 现在

- 敌人播放音效时，从敌人到最近玩家沿 AI 的同一条视线射线检查地形（含岩体射线与流式碰撞段）。被挡住时：
  - 普通音效（出招、受击材质、报警、支援、死亡等）降 10 dB；
  - 危险与确认提示（声部优先级 0：前摇、Boss 吼声与转阶段、击杀确认）只降 4 dB，隔墙仍能听出“要出招了”。
- 距离衰减、总线（SFXEnemy）、声部准入与抢占规则不变；没有玩家时不做遮挡。
- 播放器保留 `authored_volume_db` 元数据，方便核对原始音量与遮挡后的实际音量。

## 验证

- `enemy_tactical_roles` 新增 7 项，走真实 `_play_sfx` 播放路径（测试用子类只让 headless 下允许发声）：无遮挡时保持原音量；地形挡住时视线射线判定为遮挡、普通出招声降 10 dB 并记录原音量、前摇只降 4 dB；危险衰减小于普通衰减；没有玩家时不衰减；移除墙后恢复。合计 293 项通过。
- 反向检查：遮挡不生效 2 项失败；不区分危险优先级 1 项失败。
- 相关套件：runner 引擎错误门禁（含 SCRIPT ERROR）下 `enemy_tactical_roles`、`enemy_ai_behavior`（含警觉声空间遮挡）、`enemy_encounter_roles`、`enemy_lifecycle_regression`、`minor_enemy_skill_art`、`world_enemy_residency`、`audio_retirement`（内含声部预算、总线拓扑与玩家音频退役三组检查）、`world_route_walk`、`optional_challenges` 通过；真实 GL 下 `combat_visual_budget`、`enemy_effect_lifetime`、`enemy_visibility` 通过，零错误。
- 合约测试、`npm test`、`npm run test:campaign` 通过。

## 边界

10 dB／4 dB 是首版取值，没有做人工听感与混音验收；没有加低通等音色上的“闷”处理（需要按声源动态挂总线效果）。只处理敌人发出的一次性音效；环境声、玩家自身声音与 Boss 场地持续音不在本批范围。
