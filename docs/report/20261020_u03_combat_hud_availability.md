# U03 补充台账：HUD 真实可用状态

对应升级台账 U03。技能卡现在查询玩家实际动作门，显示受击／攻击／治疗等动作锁、上一技能收势与钟鸣震波落地要求；不会在这些状态下继续显示可施放按键。既有独立冷却、绯线差额与休眠条件保留。

战具卡显示耗尽、地雷布满和免费练习状态；提示中保留实际次数与容量。战具 HUD 和 `perform_build_action("use_tool")` 共用只读查询，免费练习仍遵守动作门和两枚地雷上限。查询不消费资源、不启动冷却。

验证：`ui_world_integration` 接入 12 项真实 World／玩家／地雷组／练习房查询检查；同时运行 `ui_build_accessibility`、`seal_ui`、`tool_practice`。原始 GL 日志及机器结果在 `artifacts/u03_combat_hud_availability`。

本批没有重新安排 HUD 的屏幕位置；真实混战遮挡仍待 T04。已有验证夹具的 ObjectDB 退出警告记在日志中，未当作新的通过证据，也未忽略引擎 ERROR。

## 2026-10-20：按 #161 复查意见恢复失败提示

同步最新 main（`896b127e`）后，把战具可用性预检放到一般构筑状态检查之前。次数用尽、空槽、死亡、转场和加载中都会显式显示原因；动作中和两枚地雷已布满沿用静默拒绝。空槽在进入免费练习逻辑之前拒绝，不生成空 id 的次数条目。

真实 World 回归增加 8 项检查，覆盖上述提示、拒绝时不扣次数、两种静默分支和练习房空槽。临时换回修复前生产源码（`8f3bed3f`）时，6 项明确复现失败；恢复修复后 `ui_world_integration`、`ui_build_accessibility`、`seal_ui`、`tool_practice` 四套 Godot 4.6.1 原生 GL 回归全部通过。`npm test` 与 `npm run test:campaign` 通过；Windows 下既有 42 项 POSIX runner 夹具按原规则跳过。UI World 和战具练习各有一条既有 ObjectDB 退出警告，保留在日志中，未将本次修复当作 T03 完成证据。

本轮原始日志、修复前失败和机器结果见 `artifacts/u03_combat_hud_availability/review_followup/`。
