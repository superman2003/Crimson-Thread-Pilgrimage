# G02：归途结只落在永久地面

台账 G02 剩余“遗留物可达、二次死亡与 Boss 重试”。死亡时一半碎钱留在“归途结”，位置取最后一次站立的安全地面（`last_safe_ground`）。此前只要站在地上、未死亡且不在危险区附近就会更新，不区分脚下是什么：

- 六个区域各有一台升降笼。站在笼里也会记下竖井中的位置，笼子开走后在别处死亡，归途结悬在半空，只有笼子恰好停回该高度才能拿到。
- 下劈可破的脆地、灯影相位门和其它能力门在开启后会消失，站在上面记录的点之后也可能无处可站。

本批把更新逻辑提成 `_update_safe_ground()`：只有脚下的地面碰撞是永久的 `StaticBody2D` 时才更新。升降笼的 `AnimatableBody2D`（它是 `StaticBody2D` 的子类）、`fragile_terrain`、`phase_gate` 与 `locked_gate_bodies` 中的门都不算；原有的危险区排除保留。Boss 战死亡仍把归途结放在场外检查点，二次死亡仍替换旧结。

新增默认套件 `death_cache_placement`（9 项），使用生产 `Player`、`cave_lift.gd` 生成的真实升降笼和 `MainLevel._region_gate` 生成的三类能力门：站着不动也会记录永久地面；乘升降笼、站在脆地、能力门与相位门上都不改变记录点；地刺旁的地面仍按危险区规则不记录；回到永久地面后恢复记录。退回原逻辑会失败 5 项。`world_death_cache_flush`、`save_recovery`、苔钟庭/铸雨渠/黑曜巡礼道体验套件及 `world_neighbor_gameplay_live` 通过。

不在本批：伤害开启下的真实死亡—找回—再次死亡流程（T04 续跑）、Boss 重试成本的实机记录。
