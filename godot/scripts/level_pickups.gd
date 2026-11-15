extends RefCounted
## Hazards, picking up collectibles and capacity fragments, and the ability gates those pickups open.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const WORLD_STATE_SCRIPT := preload("res://scripts/world_state.gd")

static func on_hazard_body_entered(level: Node, _body: Node, _area: Area2D) -> void:
    pass


static func forget_world_pickup(level: Node, instance_id: int) -> void:
    level.world_pickup_leases.erase(instance_id)


static func pickup_retry(level: Node, area: Area2D, item_id: String, reason: String) -> void:
    area.set_meta("manual_pickup",true)
    area.set_meta("interaction_label","重试收取 · "+("碎钱" if item_id=="currency" else level._item_display_name(item_id)))
    if not area.is_in_group("interactable"):area.add_to_group("interactable")
    level._toast(reason)


static func on_collectible_body_entered(level: Node, body: Node, area: Area2D) -> void:
    if not is_instance_valid(area) or area.is_queued_for_deletion() or level.world_loading or body!=level.player:return
    if not level.world_mode:level._on_collectible_body_entered_legacy(body,area);return
    if String(area.get_meta("kind",""))=="death_cache":level._recover_death_cache(area);return
    if level.player==null or level.player.hp<=0 or level.chapter_transitioning or not area.is_inside_tree():return
    var source: Dictionary=level.world_pickup_leases.get(area.get_instance_id(),{})
    if source.is_empty() or source.node.get_ref()!=area or source.region!=String(level.config.get("id","")):return
    if area.get_parent()!=level or String(area.name)!=String(source.id) or area.position.distance_to(source.point)>1.0:return
    if area.global_position.distance_to(level.player.global_position)>level.INTERACTION_REACH:return
    if bool(level.world_collected_ids.get(String(source.id),false)):area.queue_free();return
    if not WORLD_STATE_SCRIPT._whole(source.amount) or int(source.amount)<=0:
        level._pickup_retry(area,String(source.item),"这份物品记录无效，尚未收取。")
        return
    var currency_pickup: bool=String(source.kind)=="currency"
    var flags = level.story_flags.duplicate(true)
    var whisper_lines: Array[String]=[]
    if not currency_pickup:
        for value in level.config.get("whispers",[]):
            if not value is Dictionary:continue
            var id:=String(value.get("id",""))
            if id.is_empty() or String(value.get("trigger","enter_room"))!="pickup_item" or String(value.get("item_id",""))!=String(source.item) or bool(flags.get("whisper_"+id,false)):continue
            flags["whisper_"+id]=true;whisper_lines.append(String(value.get("line","")))
    var items: Dictionary={}
    if not currency_pickup:items[String(source.item)]=int(source.amount)
    var plan: Dictionary = level._prepare_inventory_progress(items,flags,level.currency_count+(int(source.amount) if currency_pickup else 0))
    if not plan.ok:level._pickup_retry(area,String(source.item),"物品记录尚未写入，留在原地可重试收取。");return
    # Story/whisper completion used to settle the wish board through nested
    # _set_story_flag saves. Include any earned claim in this same candidate.
    for wish in level._wish_board_entries():
        var target:=String(wish.get("target_flag",""))
        var claim: String = level._wish_claim_flag(wish)
        if not target.is_empty() and bool(plan.flags.get(target,false)) and not bool(plan.flags.get(claim,false)):
            plan.flags[claim]=true;plan.currency=int(plan.currency)+maxi(0,int(wish.get("reward_currency",0)))
    var testimony_completed = not bool(level.story_flags.get("true_ending_testimony_complete",false)) and bool(plan.flags.get("true_ending_testimony_complete",false))
    var collected = level.world_collected_ids.duplicate(true);collected[String(source.id)]=true
    var next_bells = level.bell_count+(0 if currency_pickup else 1)
    var result = level._persist_world_change({"inventory_counts":plan.counts,"story_flags":plan.flags,"currency":plan.currency,"build_state":plan.build},
        {"collected_ids":collected,"bell_count":next_bells})
    if not result.ok:level._pickup_retry(area,String(source.item),"拾取记录未写入；物件、能力与资源保持原状，按交互键重试。");return
    level._publish_inventory_progress(plan,result.candidate)
    level.world_collected_ids=collected;level.bell_count=next_bells
    if testimony_completed:level._play_sfx("ui_testimony_complete",-4.0)
    if currency_pickup:level._play_sfx_random(["pickup_coins_1","pickup_coins_2"],-10.0)
    else:
        if String(source.kind)=="item":
            level.unlocked_abilities[String(source.item)]=String(source.ability_name) if not String(source.ability_name).is_empty() else String(source.item)
            level._play_sfx("ui_ability_unlock",-4.0);level._refresh_ability_gates(true)
        for line in whisper_lines:level._toast(line)
        level._announce_lore_pickup(String(source.item));level._play_sfx("pickup_cloth",-12.0)
    level._play_sfx("pickup")
    if level.metsys_bridge!=null:level.metsys_bridge.store_object(area)
    level._toast(level._capacity_fragment_message(String(source.item),String(source.message)));level._spawn_pickup_effect(area.global_position)
    area.queue_free();level._refresh_hud();level._refresh_wish_board_overlay()
    if level.active_overlay=="backpack":level._refresh_backpack_overlay()


static func capacity_fragment_message(level: Node, item_id: String, fallback: String) -> String:
    var upgrade: Variant = level.build_system.catalog.get("permanent_upgrades", {}).get(item_id) if level.build_system != null else null
    if not upgrade is Dictionary or int(upgrade.get("per", 1)) <= 1:
        return fallback
    var per := int(upgrade.per)
    var count := int(level.inventory_counts.get(item_id, 0))
    if count > 0 and count % per == 0:
        var gain := "最大生命 +%d" if String(upgrade.stat) == "max_hp" else "绯线上限 +%d"
        return "%s编成 · %s" % [level._item_display_name(item_id.trim_suffix("_fragment")), gain % int(upgrade.amount)]
    return "%s %d / %d" % [level._item_display_name(item_id), count % per, per]


static func on_collectible_body_entered_legacy(level: Node, body: Node, area: Area2D) -> void:
    if level.world_loading:
        return
    if body != level.player or area.is_queued_for_deletion():
        return
    if String(area.get_meta("kind", "")) == "death_cache":
        level._recover_death_cache(area)
        return
    var collectible_kind := String(area.get_meta("kind", "bell_key"))
    var item_id := String(area.get_meta("item_id", collectible_kind))
    var amount := int(area.get_meta("amount", 1))
    var ability_name := String(area.get_meta("ability_name", ""))
    if collectible_kind == "currency":
        level._add_currency(amount)
        # 松脂碎钱质感层（音频规格 §4.5 ui_pickup_resin，Kenney RPG handleCoins ×2 随机）。
        level._play_sfx_random(["pickup_coins_1", "pickup_coins_2"], -10.0)
    else:
        level.bell_count += 1
        level._add_inventory_item(item_id, amount, false)
        if collectible_kind == "item":
            level.unlocked_abilities[item_id] = ability_name if not ability_name.is_empty() else item_id
            # 能力解锁 jingle（音频规格 §4.5 ui_ability_unlock）：与 pickup 基础音叠播。
            level._play_sfx("ui_ability_unlock", -4.0)
            level._refresh_ability_gates(true)
        level._trigger_whispers("pickup_item", item_id)
        level._announce_lore_pickup(item_id)
        # 收进布包质感层（Kenney RPG cloth1，与 pickup.ogg 叠放）。
        level._play_sfx("pickup_cloth", -12.0)
    level._play_sfx("pickup")
    if level.metsys_bridge != null:
        level.metsys_bridge.store_object(area)
    level._toast(String(area.get_meta("message", "已拾取。")))
    level._spawn_pickup_effect(area.global_position)
    if level.world_mode:
        level.world_collected_ids[String(area.name)] = true
        level._save_world()
    area.queue_free()
    level._refresh_hud()


static func refresh_ability_gates(level: Node, play_unlock_sfx: bool = false) -> void:
    for gate in level.config.get("locked_gates", []):
        if not (gate is Dictionary):
            continue
        var gate_data: Dictionary = gate
        var gate_id := String(gate_data.get("id", ""))
        var required_ability := String(gate_data.get("required_ability", ""))
        if gate_id.is_empty() or required_ability.is_empty():
            continue
        var action := String(gate_data.get("requires_action", ""))
        if not action.is_empty():
            var unlock_id := String(gate_data.get("permanent_action_unlock_id", gate_id))
            if bool(level.story_flags.get("action_gate_" + unlock_id, false)):
                level._unlock_ability_gate(gate_id)
            continue
        if level._owns_permanent_item(required_ability):
            var unlock_sfx := String(level.GATE_UNLOCK_SFX.get(required_ability, "gate_dash")) if play_unlock_sfx else ""
            level._unlock_ability_gate(gate_id, unlock_sfx)
    level._sync_player_abilities()
    level._refresh_world_portals()


static func owns_permanent_item(level: Node, item_id: String) -> bool:
    var count: Variant=level.inventory_counts.get(item_id,0)
    return WORLD_STATE_SCRIPT._whole(count) and int(count)>0


static func sync_player_abilities(level: Node) -> void:
    if level.player == null:
        return
    var gated_start := bool(level.config.get("ability_gated_start", false))
    level.player.wall_grip_unlocked = (not gated_start and not level.world_mode) or level._owns_permanent_item("silk_wall_grip")
    level.player.dash_unlocked = (not gated_start and not level.world_mode) or level._owns_permanent_item("thread_dash")
    level.player.double_jump_unlocked = level._owns_permanent_item("double_thread_jump")
    level.player.thread_grapple_unlocked = level._owns_permanent_item("echo_hook")
    level.player.bell_guard_unlocked = level._owns_permanent_item("bell_guard")
    level.player.thorn_downstrike_unlocked = level._owns_permanent_item("thorn_downstrike")
    level.player.lantern_phase_unlocked = level._owns_permanent_item("lantern_phase")
    level.player.crown_resonance_unlocked = level._owns_permanent_item("crown_resonance")
    level._sync_player_build()
    if level.world_mode:
        for anchor in level.get_tree().get_nodes_in_group("grapple_anchor"):
            if anchor.get_parent() != level:
                continue
            var enabled := int(level.inventory_counts.get(String(anchor.get_meta("required_ability", "echo_hook")), 0)) > 0
            anchor.set_meta("grapple_enabled", enabled)
            anchor.modulate = Color.WHITE if enabled else Color(0.50, 0.50, 0.50)


static func unlock_ability_gate(level: Node, gate_id: String, unlock_sfx_key: String = "") -> void:
    if not level.locked_gate_bodies.has(gate_id):
        return
    var body = level.locked_gate_bodies[gate_id] as StaticBody2D
    if body != null and is_instance_valid(body):
        body.queue_free()
    level.locked_gate_bodies.erase(gate_id)
    # 能力门开启音（音频规格 §4.5 ui_gate_unlock）：按门族播对应家族音。
    if not unlock_sfx_key.is_empty():
        level._play_sfx(unlock_sfx_key, -7.0)
        if unlock_sfx_key == "gate_downstrike" and level._art_theme_id() == "string_greenhouse":
            level._play_sfx("ch04_beat_string_break", -9.0)
