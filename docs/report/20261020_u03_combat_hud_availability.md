# U03 补充台账：HUD 真实可用状态

对应升级台账 U03。技能卡现在查询玩家实际动作门，显示受击／攻击／治疗等动作锁、上一技能收势与钟鸣震波落地要求；不会在这些状态下继续显示可施放按键。既有独立冷却、绯线差额与休眠条件保留。

战具卡显示耗尽、地雷布满和免费练习状态；提示中保留实际次数与容量。战具 HUD 和 `perform_build_action("use_tool")` 共用只读查询，免费练习仍遵守动作门和两枚地雷上限。查询不消费资源、不启动冷却。

验证：`ui_world_integration` 接入 12 项真实 World／玩家／地雷组／练习房查询检查；同时运行 `ui_build_accessibility`、`seal_ui`、`tool_practice`。原始 GL 日志及机器结果在 `artifacts/u03_combat_hud_availability`。

本批没有重新安排 HUD 的屏幕位置；真实混战遮挡仍待 T04。已有验证夹具的 ObjectDB 退出警告记在日志中，未当作新的通过证据，也未忽略引擎 ERROR。
