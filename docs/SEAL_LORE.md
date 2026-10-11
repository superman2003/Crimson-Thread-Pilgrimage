# 契印获得与既有剧情核对

本轮保留既有失声契约、删名记录、工人遗物和人物身份。契印解释为遗物保存的技艺；主角仍使用针、线、铜器和牵引，不获得职业身份。取得配装不改变结局条件，也不替代六区主线证词。

| 内容 | 既有事件 | 持久标记与回应 |
| --- | --- | --- |
| 缝名机制、断弦回斩、工匠线轴 | 学徒“把名字带回来”支线完成 | `quest_bring_names_complete`、`skill_crosscut_learned`、`charm_reflux_found`；学徒说明重新缀合 |
| 司铸、守钟架势、钟鸣震波、绊线钉、铜背扣 | 已开始名字支线；带 `worker_badge` 完成柳的对话 | `seal_bell_repaired`、`skill_ward_learned`、`skill_shockwave_learned`、`tool_mine_found`、`charm_shell_found`；后续回应说明工人的承力办法 |
| 校录、回声针、盐印缚线、盐雾瓶、盐页书签 | 带书库证词或原件残片完成叶的核对 | `seal_salt_restored`、`skill_needle_learned`、`skill_snare_learned`、`tool_fog_found`、`charm_spur_found`；后续回应确认记录恢复 |
| 回响诱铃、静钟碎片 | 蜂蜡补灯支线完成 | `tool_lure_found`、`charm_mender_found`；赠品来自生活设施 |
| 余声针匣 | 携带旧军令完成逃兵支线 | `charm_needlecase_found`；原用途为补旗 |

基础绯线穿刺、铜铃投罐和巡礼鞋结不要求支线；初期基础针击无需修复。区域到达、Boss 击败或永久探索能力本身不能替代上述获得事件。对话读完才提交标记；中途关闭不会获得内容。旧存档完成了相关支线的玩家可重访完成态人物领取新内容。

六项技能各自使用一间既有能力工房的门外练针区。运行时位置、名称与技能来自 `world_routes.json` 的 `seal_practice_plan`；地图房间保存同一份提示。永久能力门及回访奖励保持原有条件，不改成契印或装备门。练针架应提供安全目标与明显反馈，实际动作、伤害、图标与声音验收由战斗及运行时集成套件覆盖。

未新增独立职业、材料购买门槛或契印决定结局。荆弦、黑曜、无声契印暂不定义。训练提示不是陌生玩家体验或人工视听验收的替代；本轮需明确记录尚未经过人工验证的部分。
