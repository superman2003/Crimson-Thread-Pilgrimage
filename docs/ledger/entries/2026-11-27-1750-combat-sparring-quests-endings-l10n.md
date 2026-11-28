## 2026-11-27：修复试招场首领埋地与纯手柄软锁、战斗防御/无敌帧/坠落缺陷、支线/结局门漏洞与英文译文精校

- **目标**：修复深度审计发现的试招场（`SparringArena`）6 首领埋地无法移动与纯手柄退场软锁、守钟架势（`ward`）格挡后硬直锁死、8 个挑战精英未生效、残余地面/光束特效在无敌帧被永久消耗、致命坠落双死与先写 `hp=0`、第五章逃旗手心愿永久失败、第六章愿板结局后锁死/1 像素逃课、结局窗重复按钮以及多处英文模式漏中与机翻问题。
- **改动**：
  - **试招场与战斗系统**：
    - `godot/scripts/sparring_arena.gd`：按 `-actor.ground_clearance` 修正敌人与 6 位首领出生高度（解除地板碰撞体嵌死）；保存 `leave_button` 并在战后聚焦，补充手柄 `Start`/`Back`（战后含 `B`）退场、退出抑制同帧误开暂停菜单及 `FeelKit` 相机注册与恢复；在 `sparring_policy.gd` 与 `material_exchange.gd` 缓存静态 JSON 数据。
    - `godot/scripts/player_damage.gd`、`player_controller.gd`、`player_input_buffer.gd`：`ward` 防御技能成功格挡时将 `attack_timer` 缩至恢复帧以允许反击；记录 `_last_hurt_frame` 区分真实受伤与血上限变更；抑制暂停恢复同物理帧的 `jump`/`dash` 输入泄漏。
    - `godot/scripts/enemy_lifecycle.gd`：为章节中标注 `elite: true` 但未在物种表定义 `elite` 子表的 8 名挑战敌人提供默认精英倍率（`hp_mult=1.75`、`damage_bonus=1`）。
    - `godot/scripts/enemy_attack_effect.gd`：封装 `_apply_player_contact()`，玩家仅因无敌帧免疫时不永久消耗 `hit_player` 或提前销毁投射物。
    - `godot/scripts/level_player_frame.gd`：世界模式致命坠落走标准死亡流程，避免在钟龛二次死亡与提前写入 `hp=0` 存档；非致命坠落同步更新房间访问。
    - `godot/scripts/level_boss.gd`：首领试炼开场提示改用动态首领名称，不再硬编码 `"苔钟守母已苏醒"`。
  - **支线、结局与英文精校**：
    - `godot/scripts/wish_topics.gd`：允许 `reward` 为空字符串，使第五章 `npc_deserter_flagbearer`（“逃旗手的心愿”）在世界模式可正常报价与交付。
    - `godot/data/world_narrative.json`、`level_world_travel.gd`：为 `npc_crown_tongue.tongue_pain` 补齐 `"continues_after_ending": true` 防止结局后永久错过，并在对话存盘后播报愿板碎钱到账。
    - `godot/scripts/level_rooms.gd`、`level_hud.gd`、`loader_region_state.gd`：修复第六章无伤回声室竞态、神龛换构筑误判受伤、跨区残留元数据及进门退回 1 像素逃课问题。
    - `godot/scripts/ending_story_desk.gd`、`ending_gates.gd`：隐藏尾声末页重复取消按钮、重看尾声默认聚焦“下一幕”、拆分结局结语与多条件门拒绝提示以消除英文模式漏中。
    - `godot/data/ui_en_game.json`、`ui_en_story.json`、`tools/audit_ui_translations.py`：修正全角空格/引号、`unfounded testimonies`、`continuous battle`、`Full armor`、`Rosin`、`Hidden Moss Court Echo Lamp` 等译文并加固审计守卫。
- **验证**：本地执行 `audit_ui_translations.py --self-test`、`audit_ui_translations.py`、`test_ui_text_colors.py`、`display_settings_validation.gd`、`audit_export_contents.py`、`build_ledger.py --validate`、`npm run test:campaign` 均通过。

CI 复验：区分实际伤害、旧式接触回调及免疫拒绝。格挡后的短保护窗口仍拦截同一波命中，普通免疫不提前消耗危险物；只有实际伤害才施加缠绕。 格挡保护标记也在计时到期、钟龛恢复和死亡重生时显式清理。

E06 专项复验：测试靶实际扣除生命以验证伤害回执，逐次断言投射物命中。Godot 正向 12 项通过，保留的圆形扫掠负对照仍失败 4 项；未改生产伤害规则。

尾声焦点沿用已选分支默认「下一幕」，最后一幕隐藏取消前接管焦点，保留来源与许可及中英文总结。补真实开窗、翻页与复开回归。

王冠无伤回声记录必须从已知入口穿到不同出口，房中载入后直接离开不会补记。增加无入口、原路退出、受伤和正常穿越的回归。
