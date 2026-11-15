extends RefCounted
## The build system bridge: workstations and artisans, wallet transactions, quotes, build actions and ability actions.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func get_build_system(level: Node) -> RefCounted:
    return level.build_system


static func sync_player_build(level: Node) -> void:
    if not level.world_mode or level.build_system == null:
        return
    level.build_system.sync_progress(level.inventory_counts, String(level.config.get("id", "")), level.story_flags)
    if level.player != null and is_instance_valid(level.player):
        var profile: Dictionary = level.build_system.profile()
        if profile != level.applied_build_profile:
            level.player.apply_build_stats(profile)
            level.applied_build_profile = profile.duplicate(true)
            level._sync_hazard_trigger_sizes()


static func sync_hazard_trigger_sizes(level: Node) -> void:
    pass


static func bind_build_inputs(level: Node) -> void:
    var bindings := {"skill_cycle": [KEY_C, JOY_AXIS_TRIGGER_LEFT],
        "tool_cast": [KEY_T, JOY_BUTTON_DPAD_DOWN], "tool_cycle": [KEY_G, JOY_AXIS_TRIGGER_RIGHT]}
    for action in bindings:
        if InputMap.has_action(action):
            continue
        InputMap.add_action(action)
        var key := InputEventKey.new()
        key.physical_keycode = int(bindings[action][0])
        InputMap.action_add_event(action, key)
        if action == "tool_cast":
            var joy := InputEventJoypadButton.new()
            joy.button_index = int(bindings[action][1])
            InputMap.action_add_event(action, joy)
        else:
            var trigger := InputEventJoypadMotion.new()
            trigger.axis = int(bindings[action][1])
            trigger.axis_value = 1.0
            InputMap.action_add_event(action, trigger)


static func near_workstation(level: Node, crafting: bool = false) -> bool:
    if level.player == null or level.player.hp <= 0 or level.player.death_timer > 0.0 or (level.boss_arena_lock_body != null and is_instance_valid(level.boss_arena_lock_body)):
        return false
    for child in level.get_children():
        if not child is Area2D or level.player.global_position.distance_to(child.global_position) > 120.0:
            continue
        var kind := String(child.get_meta("kind", ""))
        if kind == "save_point" and not crafting:
            return true
        if crafting and kind == "npc":
            var id := String(child.get_meta("npc_id", child.name))
            if id in level.ARTISAN_NPCS:
                return true
    return false


static func is_near_shrine(level: Node) -> bool:
    return level._near_workstation(false)


static func is_near_artisan(level: Node) -> bool:
    return level._near_workstation(true)


static func near_artisan_id(level: Node) -> String:
    if not level._near_workstation(true):
        return ""
    var best := ""
    var best_distance := INF
    for child in level.get_children():
        if not child is Area2D or String(child.get_meta("kind", "")) != "npc":
            continue
        var id := String(child.get_meta("npc_id", child.name))
        var distance = level.player.global_position.distance_to(child.global_position)
        if id in level.ARTISAN_NPCS and distance <= 120.0 and distance < best_distance:
            best = id
            best_distance = distance
    return best


static func artisan_craft_block(level: Node, recipe: Dictionary) -> String:
    for prerequisite in recipe.get("requires_crafted", []):
        if not level.build_system.state.crafted.has(prerequisite):return "请先完成前阶改制，再制作二阶方案"
    var artisan := String(recipe.get("artisan", ""))
    if not artisan.is_empty() and level.near_artisan_id() != artisan:
        return "「%s」要找%s制作" % [String(recipe.get("name", "")), String(recipe.get("artisan_name", "工匠"))]
    var flag := String(recipe.get("requires_flag", ""))
    if not flag.is_empty() and not bool(level.story_flags.get(flag, false)):
        return String(recipe.get("requires_flag_hint", "工匠还不会这门手艺"))
    for item in recipe.get("requires_items", []):
        if int(level.inventory_counts.get(item, 0)) <= 0:
            return "需要「%s」作图样（不会被收走）" % level._item_display_name(String(item))
    return ""


static func build_wallet_snapshot(level: Node) -> Dictionary:
    return {"currency": level.currency_count, "inventory_counts": level.inventory_counts.duplicate(true)}


static func set_build_wallet(level: Node, wallet: Dictionary) -> void:
    level.currency_count = int(wallet.get("currency", level.currency_count))
    level.inventory_counts = wallet.get("inventory_counts", level.inventory_counts).duplicate(true)
    level.inventory_materials.clear()
    for item_id in level.inventory_counts:
        if String(level._item_data(String(item_id)).get("category", "Materials")) == "Materials":
            level.inventory_materials[item_id] = int(level.inventory_counts[item_id])


static func rollback_build_transaction(level: Node, build_before: Dictionary, wallet_before: Dictionary, materials_before: Dictionary) -> void:
    if level.build_system != null:
        level.build_system.restore(build_before)
    level.currency_count = int(wallet_before.get("currency", level.currency_count))
    level.inventory_counts = wallet_before.get("inventory_counts", level.inventory_counts).duplicate(true)
    level.inventory_materials = materials_before.duplicate(true)


static func finish_build_transaction(level: Node, result: Dictionary, build_before: Dictionary, wallet_before: Dictionary, materials_before: Dictionary) -> Dictionary:
    if not level._save_world():
        level._rollback_build_transaction(build_before, wallet_before, materials_before)
        result.ok = false
        result.reason = "归途记录未能写入；本次购买或制作已回滚。"
        level._toast(String(result.reason))
        level._refresh_hud()
        return result
    # Apply derived player stats only after the save transaction commits. A
    # failed disk write therefore cannot disturb HP, thread or action cooldowns.
    level._sync_player_build()
    level._refresh_hud()
    return result


static func get_tool_readiness(level: Node, id: String) -> Dictionary:
    if not is_instance_valid(level.player) or level.player.hp <= 0 or level.chapter_transitioning or level.world_loading:
        return {"available":false,"text":"暂不可用","detail":"等待当前旅途状态结束。"}
    if not level.active_overlay.is_empty() or not level.player._can_start_action():
        return {"available":false,"text":"动作中","detail":"请在动作结束后使用战具"}
    if id == "mine":
        var owned_traps := 0
        for effect in level.get_tree().get_nodes_in_group("player_trap"):
            if effect.get("owner_player") == level.player:owned_traps += 1
        if owned_traps >= 2:
            return {"available":false,"text":"已布满","detail":"场上已有两枚布置中的地雷"}
    if id.is_empty():
        return {"available":false,"text":"空槽","detail":"此战具槽位为空"}
    if level._in_tool_practice_room():
        return {"available":true,"text":"练习","detail":"练习房免费使用，不消耗携带次数。"}
    if level.build_system == null or int(level.build_system.state.tool_counts.get(id,0)) <= 0:
        return {"available":false,"text":"已用尽","detail":"战具已用尽，请在钟龛补给"}
    return {"available":true,"text":"","detail":"使用消耗一次。"}


static func quote_loadout_restore(level: Node, name: String) -> Dictionary:
    return preload("res://scripts/loadout_restore_review.gd").quote(level,name)


static func apply_reviewed_loadout(level: Node, name: String, fingerprint: String) -> Dictionary:
    return preload("res://scripts/loadout_restore_review.gd").apply(level,name,fingerprint)


static func quote_craft_cart(level: Node, request: Variant) -> Dictionary:
    var failure := {"ok":false,"reason":"请与制作这份清单的工匠面对面交谈。"}
    if not level.world_mode or level.world_loading or level.chapter_transitioning or level.player==null or level.player.hp<=0 or level.build_system==null or level.world_save_blocked:return failure
    if not level._near_workstation(true) or level.near_artisan_id().is_empty():return failure
    if not request is Array:return failure
    for id in request:
        if not id is String or not level.build_system.catalog.recipes.has(id):return failure
        var recipe: Dictionary=level.build_system.catalog.recipes[id]
        if String(recipe.get("kind",""))=="skill_branch" and not bool(level.story_flags.get("skill_practiced_"+String(recipe.target),false)):
            return {"ok":false,"reason":"先在练针架练熟技能，再选校习方向。"}
        var blocked: String = level.artisan_craft_block(recipe)
        if not blocked.is_empty():return {"ok":false,"reason":blocked}
    var quote: Dictionary=level.build_system.quote_craft_batch(request,level._build_wallet_snapshot())
    if quote.get("ok",false):quote["fingerprint"]=var_to_str([request,level.build_system.serialize(),level._build_wallet_snapshot(),quote.rows,quote.materials,quote.currency_spent,level.near_artisan_id(),level.story_flags]).sha256_text()
    return quote


static func perform_build_action(level: Node, action: String, id: String = "", extra: Variant = null) -> Dictionary:
    if level.build_system == null or not level.world_mode:
        return {"ok": false, "reason": "构筑系统在互联世界旅途中开放"}
    if action == "use_tool":
        var selected_tool_id := String(level.build_system.state.tools[int(level.build_system.state.active_tool_slot)])
        var readiness: Dictionary = level.get_tool_readiness(selected_tool_id)
        if not bool(readiness.available):
            # Recovery and mine-cap rejections were always silent; the other
            # unavailable states must still explain why the input did nothing.
            if String(readiness.text) not in ["动作中", "已布满"]:
                level._toast(String(readiness.detail))
            return {"ok":false,"reason":String(readiness.detail)}
    if level.player == null or level.player.hp <= 0 or level.chapter_transitioning or level.world_loading:
        return {"ok": false, "reason": "当前无法更换构筑"}
    if action == "quote_craft_batch":return level.quote_craft_cart(extra)
    if action == "quote_resupply":
        if not level._near_workstation():
            return {"ok": false, "reason": "请在钟龛查看战具补给报价"}
        return level.build_system.quote_resupply(level._build_wallet_snapshot(), {} if extra == null else extra)
    if action == "quote_loadout_management":
        if not extra is Dictionary or not extra.get("copy",false) is bool:return {"ok":false,"reason":"方案操作无效"}
        return level.build_system.preview_loadout_management(id,extra.get("name"),bool(extra.get("copy",false)),level._near_workstation())
    if action in ["resupply_tools", "paid_resupply"] and not level._near_workstation():
        return {"ok": false, "reason": "请在钟龛补给战具"}
    if level.world_save_blocked:
        return {"ok": false, "reason": "构筑存档不兼容，当前不能保存交易"}
    var build_before: Dictionary = level.build_system.serialize()
    var wallet_before: Dictionary = level._build_wallet_snapshot()
    var materials_before: Dictionary = level.inventory_materials.duplicate(true)
    var result: Dictionary = {"ok": false, "reason": "未知构筑操作"}
    match action:
        "switch_crest", "crest":
            result = level.build_system.switch_crest(id, level._near_workstation())
        "select_skill", "skill":
            result = level.build_system.select_skill(id, int(extra) if extra is int or extra is float else -1) if level._near_workstation() else {"ok": false, "reason": "请在钟龛调整技能位置"}
        "select_tool", "tool":
            result = level.build_system.select_tool(id, int(extra) if extra is int or extra is float else -1) if level._near_workstation() else {"ok": false, "reason": "请在钟龛调整战具位置"}
        "equip_family_slot":
            var family := String(extra.get("family", "")) if extra is Dictionary else ""
            var slot := int(extra.get("slot", -1)) if extra is Dictionary else -1
            result = level.build_system.equip_family_slot(id, family, slot, level._near_workstation())
        "cycle_skill":
            result = level.build_system.cycle_skill()
        "cycle_tool":
            result = level.build_system.cycle_tool()
        "equip_passive", "passive":
            result = level.build_system.equip_passive(id) if level._near_workstation() else {"ok": false, "reason": "请在钟龛调整铭饰"}
        "save_loadout":
            result = level.build_system.save_loadout(id, level._near_workstation())
        "delete_loadout":
            result = level.build_system.delete_loadout(id, level._near_workstation())
        "rename_loadout":
            result = level.build_system.rename_loadout(id,extra,level._near_workstation())
        "copy_loadout":
            result = level.build_system.copy_loadout(id,extra,level._near_workstation())
        "restore_loadout", "load_loadout":
            result = level.build_system.restore_loadout(id) if level._near_workstation() else {"ok": false, "reason": "请在钟龛恢复构筑方案"}
        "resupply_tools", "paid_resupply":
            result = level.build_system.resupply_tools(level._build_wallet_snapshot(), level._near_workstation(), {} if extra == null else extra)
            if result.get("ok", false):
                level._set_build_wallet(result.wallet)
        "craft_batch":
            result=level.quote_craft_cart(extra)
            if result.get("ok",false):
                if not level.build_system.restore(result.build).ok:result={"ok":false,"reason":"制作清单构筑无法恢复"}
                else:level._set_build_wallet(result.wallet)
        "transact", "craft":
            var recipe: Dictionary = level.build_system.catalog.recipes.get(id, {})
            var practice_target := String(recipe.get("target", ""))
            if String(recipe.get("kind", "")) == "skill_branch" and not bool(level.story_flags.get("skill_practiced_" + practice_target, false)):
                result = {"ok": false, "reason": "先在练针架上练熟「%s」，再选校习方向" % String(level.build_system.catalog.skills.get(practice_target, {}).get("name", practice_target))}
            elif not level._near_workstation(true):
                result = {"ok": false, "reason": "请与雨铸匠、织线学徒或蜂蜡商人面对面校习"}
            elif String(recipe.get("kind", "")) in ["tool_capacity", "slot_part", "passive"] and not level.artisan_craft_block(recipe).is_empty():
                result = {"ok": false, "reason": level.artisan_craft_block(recipe)}
            else:
                result = level.build_system.transact(id, level._build_wallet_snapshot())
                if result.get("ok", false):
                    level._set_build_wallet(result.wallet)
        "use_tool":
            var selected_tool_id := String(level.build_system.state.tools[int(level.build_system.state.active_tool_slot)])
            # E02: tools used in a practice room cost nothing and give nothing:
            # the stock is put back to what it was, even when it was empty.
            var practice: bool = level._in_tool_practice_room()
            var practice_count := int(level.build_system.state.tool_counts.get(selected_tool_id, 0))
            if practice and practice_count <= 0:
                level.build_system.state.tool_counts[selected_tool_id] = 1
            result = level.build_system.use_tool()
            if practice:
                level.build_system.state.tool_counts[selected_tool_id] = practice_count
    if result.get("ok", false):
        result = level._finish_build_transaction(result, build_before, wallet_before, materials_before)
        if result.get("ok", false) and action == "use_tool" and not level.player.cast_tool(result):
            # Stock is durable before effects exist. If the effect cannot start,
            # persist a refund; if that write fails, retain the spent state so
            # memory and disk still agree and no free effect can be created.
            var spent_build: Dictionary = level.build_system.serialize()
            level.build_system.restore(build_before)
            if level._save_world():
                level._sync_player_build()
                result = {"ok": false, "reason": "当前无法使用战具；已退还次数"}
            else:
                level.build_system.restore(spent_build)
                level._sync_player_build()
                result = {"ok": false, "reason": "战具未能启动且退款暂未写入；本次次数已消耗"}
    elif not String(result.get("reason", "")).is_empty():
        level._toast(String(result.reason))
    return result


static func toggle_build(level: Node) -> void:
    if level.ui_shell == null or not is_instance_valid(level.ui_shell.get("build_panel")):
        return
    if level.active_overlay == "build":
        level._close_overlays()
        return
    level._close_overlays()
    level.active_overlay = "build"
    level.ui_shell.build_panel.visible = true
    level.ui_shell.refresh_build()
    level._sync_ui_input_lock()


static func on_gate_struck(level: Node, gate: Node, _point: Vector2) -> void:
    if not is_instance_valid(gate) or not gate.is_inside_tree():
        return
    gate.set_meta("crack_count", int(gate.get_meta("crack_count", 0)) + 1)
    for child in gate.get_children():
        # Only the drawing shudders; the collision the player stands on stays put.
        if not child is Node2D or child is CollisionShape2D or child is CollisionPolygon2D:
            continue
        if not child.has_meta("shudder_base"):
            child.set_meta("shudder_base", child.position)
        var base: Vector2 = child.get_meta("shudder_base")
        var tween := child.create_tween()
        tween.tween_property(child, "position", base + Vector2(3, 1), 0.04)
        tween.tween_property(child, "position", base + Vector2(-2, 0), 0.04)
        tween.tween_property(child, "position", base, 0.05)


static func on_ability_action(level: Node, ability_id: String, origin: Vector2, direction: Vector2) -> void:
    if level._walking_world_passage():
        return
    if not level.world_mode or int(level.inventory_counts.get(ability_id, 0)) <= 0 or level.player == null or level.player.hp <= 0:
        return
    var changed := false
    for gate in level.config.get("locked_gates", []):
        if String(gate.get("requires_action", "")) != ability_id:
            continue
        var id := String(gate.get("id", ""))
        if not level.locked_gate_bodies.has(id):
            continue
        var rect: Rect2 = level._rect2(gate.get("rect", []))
        var closest := Vector2(clampf(origin.x, rect.position.x, rect.end.x), clampf(origin.y - 42.0, rect.position.y, rect.end.y))
        if closest.distance_to(origin - Vector2(0, 42)) > float(gate.get("action_range", 150.0)):
            continue
        # A downward break only acts on ground below the player, never a side wall.
        if ability_id == "thorn_downstrike" and (direction.y < 0.5 or origin.y > rect.end.y):
            continue
        var unlock_id := String(gate.get("permanent_action_unlock_id", id))
        changed = true
        level.story_flags["action_gate_" + unlock_id] = true
        var shortcut := String(gate.get("unlock_shortcut_id", ""))
        if not shortcut.is_empty():
            level.story_flags["world_shortcut_" + shortcut] = true
        var record := String(gate.get("unlock_item_id", ""))
        if not record.is_empty():
            level._add_inventory_item(record, 1, false)
        level._spawn_route_open_effect(rect.get_center())
        level._unlock_ability_gate(id, String(level.GATE_UNLOCK_SFX.get(ability_id, "gate_dash")))
        level._toast(String(gate.get("open_message", "动作唤醒旧机关，回访通路永久接通。")))
    if changed:
        level._refresh_world_portals()
        level._save_world()
