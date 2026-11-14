extends RefCounted
## Optional challenges: shrines, hunt tracks, the locked arena, and first-clear rewards.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func optional_challenge(level: Node, challenge_id: String) -> Dictionary:
    for entry in level.config.get("optional_challenges", []):
        if entry is Dictionary and String(entry.get("id", "")) == challenge_id:
            return entry
    return {}


static func challenge_shrine_from_interactive(level: Node, data: Dictionary) -> void:
    # Allow authored interactives of kind challenge_shrine to reuse the same path.
    var challenge := optional_challenge(level, String(data.get("challenge_id", "")))
    if challenge.is_empty():
        challenge = {"id": String(data.get("challenge_id", data.get("id", ""))), "shrine": data, "clear_flag": String(data.get("clear_flag", "")), "name": String(data.get("label", "可选挑战"))}
    challenge_shrine(level, challenge)


static func challenge_shrine(level: Node, challenge: Dictionary) -> void:
    var shrine: Dictionary = challenge.get("shrine", {})
    if shrine.is_empty():
        return
    var area := Area2D.new()
    var shrine_id := String(shrine.get("id", "challenge_shrine_%s" % String(challenge.get("id", "trial"))))
    area.name = shrine_id
    area.position = level._vec2(shrine.get("position", [0, 0]))
    area.set_meta("kind", "challenge_shrine")
    area.set_meta("challenge_id", String(challenge.get("id", "")))
    area.set_meta("object_id", "interactable/" + shrine_id)
    var cleared := bool(level.story_flags.get(String(challenge.get("clear_flag", "")), false))
    var label := String(shrine.get("label", String(challenge.get("name", "可选挑战"))))
    var claim_pending:=bool(level.story_flags.get(challenge_pending_flag(level, challenge),false)) and not cleared
    if claim_pending:label="%s · 胜利待记录" % String(challenge.get("name","可选挑战"))
    if cleared:
        label = "%s · 已清" % String(challenge.get("name", "可选挑战"))
    area.set_meta("label", label)
    area.set_meta("interaction_label", label + (" · 回访" if cleared else " · 领取首清" if claim_pending else " · F 敲响"))
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(54, 78)
    shape.shape = rectangle
    area.add_child(shape)
    var sprite := Sprite2D.new()
    sprite.texture = load(level.SPRITES["lever"])
    sprite.scale = Vector2(0.48, 0.48)
    sprite.name = "ChallengeShrineSprite"
    level._apply_original_prop(sprite, "lever_closed" if not cleared else "lever_open", 78 if not cleared else 52)
    area.add_child(sprite)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func challenge_kind_label(level: Node, challenge: Dictionary) -> String:
    var kind := String(challenge.get("kind", ""))
    if kind == "optional_boss":
        return "可选首领"
    if kind == "tracking_hunt":
        return "追踪狩猎"
    return "挑战房"


static func challenge_tracks_ready(level: Node, challenge: Dictionary) -> bool:
    var tracks = challenge.get("tracks", [])
    if not (tracks is Array) or tracks.is_empty():
        return true
    for track in tracks:
        if not (track is Dictionary):
            continue
        var flag := String(track.get("flag", ""))
        if flag.is_empty() or not bool(level.story_flags.get(flag, false)):
            return false
    return true


static func hunt_track(level: Node, challenge: Dictionary, track: Dictionary) -> void:
    if track.is_empty():
        return
    var track_id := String(track.get("id", ""))
    if track_id.is_empty():
        return
    var area := Area2D.new()
    area.name = track_id
    area.position = level._vec2(track.get("position", [0, 0]))
    area.set_meta("kind", "hunt_track")
    area.set_meta("challenge_id", String(challenge.get("id", "")))
    area.set_meta("track_flag", String(track.get("flag", "")))
    area.set_meta("track_hint", String(track.get("hint", "")))
    area.set_meta("object_id", "interactable/" + track_id)
    var found := bool(level.story_flags.get(String(track.get("flag", "")), false))
    var label := String(track.get("label", "渠影残迹"))
    if found:
        label = "%s · 已循" % label
    area.set_meta("label", label)
    area.set_meta("interaction_label", label + (" · 回看" if found else " · F 辨认"))
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(48, 56)
    shape.shape = rectangle
    area.add_child(shape)
    var sprite := Sprite2D.new()
    sprite.texture = load(level.SPRITES["lever"])
    sprite.scale = Vector2(0.36, 0.36)
    sprite.name = "HuntTrackSprite"
    level._apply_original_prop(sprite, "lever_open" if found else "lever_closed", 52 if found else 64)
    area.add_child(sprite)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func activate_hunt_track(level: Node, area: Area2D) -> void:
    if area == null or not is_instance_valid(area):
        return
    var flag := String(area.get_meta("track_flag", ""))
    var hint := String(area.get_meta("track_hint", ""))
    var challenge_id := String(area.get_meta("challenge_id", ""))
    var challenge := optional_challenge(level, challenge_id)
    if flag.is_empty():
        level._toast("这道残迹已经模糊了。")
        return
    var already := bool(level.story_flags.get(flag, false))
    if not already:
        level.story_flags[flag] = true
        level._save_world()
    var base_label := String(area.get_meta("label", "渠影残迹")).replace(" · 已循", "")
    area.set_meta("label", "%s · 已循" % base_label)
    area.set_meta("interaction_label", String(area.get_meta("label")) + " · 回看")
    var sprite := area.get_node_or_null("HuntTrackSprite") as Sprite2D
    if sprite != null:
        level._apply_original_prop(sprite, "lever_open", 52)
    if already:
        level._toast(hint if not hint.is_empty() else "残迹已循过。")
    else:
        var ready := challenge_tracks_ready(level, challenge)
        if ready and not challenge.is_empty():
            level._toast("%s · 残迹已齐 · 去敲余响钟" % String(challenge.get("name", "追踪狩猎")))
        elif not hint.is_empty():
            level._toast(hint)
        else:
            level._toast("循着残迹，猎物还在前方。")


static func activate_challenge_shrine(level: Node, area: Area2D) -> void:
    if area == null or not is_instance_valid(area):
        return
    var challenge_id := String(area.get_meta("challenge_id", ""))
    var challenge := optional_challenge(level, challenge_id)
    if challenge.is_empty():
        level._toast("这座余响钟已经哑了。")
        return
    var clear_flag := String(challenge.get("clear_flag", ""))
    if not clear_flag.is_empty() and bool(level.story_flags.get(clear_flag, false)):
        level._toast("%s已清·可回访，奖励不会再发。" % String(challenge.get("name", "可选挑战")))
        return
    if bool(level.story_flags.get(challenge_pending_flag(level, challenge),false)):
        grant_optional_challenge_reward(level, challenge)
        return
    if String(challenge.get("kind", "")) == "tracking_hunt" and not challenge_tracks_ready(level, challenge):
        level._toast("%s · 猎物未显形 · 先找残迹" % String(challenge.get("name", "追踪狩猎")))
        return
    if not level.active_challenge_id.is_empty():
        level._toast("先了结当前的可选挑战。")
        return
    start_optional_challenge(level, challenge)


static func challenge_lock_inside_x(level: Node, challenge: Dictionary, lock_rect: Rect2) -> float:
    # Prefer shrine / enemy centroid so the push side matches the trial chamber,
    # not a hard-coded "always right of the wall".
    var anchor_x := lock_rect.get_center().x
    var shrine: Dictionary = challenge.get("shrine", {})
    if shrine is Dictionary and shrine.has("position"):
        anchor_x = level._vec2(shrine.get("position", [anchor_x, 0])).x
    else:
        var sum_x := 0.0
        var count := 0
        for spawn in challenge.get("enemies", []):
            if spawn is Dictionary and spawn.has("position"):
                sum_x += level._vec2(spawn.get("position", [anchor_x, 0])).x
                count += 1
        if count > 0:
            anchor_x = sum_x / float(count)
    var authored := String(challenge.get("lock_inside", "")).strip_edges().to_lower()
    if authored == "left" or authored == "right":
        if authored == "left":
            return lock_rect.position.x - 54.0
        return lock_rect.position.x + lock_rect.size.x + 54.0
    if anchor_x < lock_rect.position.x:
        return lock_rect.position.x - 54.0
    return lock_rect.position.x + lock_rect.size.x + 54.0


static func is_optional_challenge_spawn(level: Node, spawn_id: String) -> bool:
    if level.challenge_alive_ids.has(spawn_id):
        return true
    for entry in level.config.get("optional_challenges", []):
        if not (entry is Dictionary):
            continue
        for spawn in entry.get("enemies", []):
            if spawn is Dictionary and String(spawn.get("id", "")) == spawn_id:
                return true
    return false


static func start_optional_challenge(level: Node, challenge: Dictionary) -> void:
    var challenge_id := String(challenge.get("id", ""))
    if challenge_id.is_empty():
        return
    if bool(level.story_flags.get(challenge_pending_flag(level, challenge),false)):
        grant_optional_challenge_reward(level, challenge)
        return
    level.active_challenge_id = challenge_id
    level.challenge_alive_ids.clear()
    var lock_rect_value = challenge.get("lock_rect", [])
    if lock_rect_value is Array and lock_rect_value.size() >= 4:
        var lock_rect: Rect2 = level._rect2(lock_rect_value)
        set_challenge_arena_locked(level, true, lock_rect, challenge_lock_inside_x(level, challenge, lock_rect))
    var kind_label := challenge_kind_label(level, challenge)
    level._toast("%s · %s" % [kind_label, String(challenge.get("name", "余响试炼"))])
    var skipped_spawns := 0
    for spawn in challenge.get("enemies", []):
        if not (spawn is Dictionary):
            continue
        var spawn_data: Dictionary = spawn.duplicate(true)
        var spawn_id := String(spawn_data.get("id", ""))
        if spawn_id.is_empty():
            continue
        spawn_data["challenge_id"] = challenge_id
        # Register only after a live actor exists. A null / invalid spawn must
        # not stick in the alive set, or the trial can never clear by kills.
        var enemy: Area2D = null
        if not level.challenge_spawn_null_ids_for_validation.has(spawn_id):
            enemy = level._enemy(spawn_data)
        if enemy != null and is_instance_valid(enemy):
            level.challenge_alive_ids[spawn_id] = true
            enemy.set_meta("optional_challenge_id", challenge_id)
        else:
            skipped_spawns += 1
            push_warning("Optional challenge spawn failed, skipping %s" % spawn_id)
    if level.challenge_alive_ids.is_empty():
        clear_active_challenge(level, false)
        level._toast("试炼钟空响了一声。")
    elif skipped_spawns > 0:
        level._toast("有试炼之敌没有显形。")


static func set_challenge_arena_locked(level: Node, locked: bool, lock_rect: Rect2 = Rect2(), inside_x: float = NAN) -> void:
    if locked:
        if level.challenge_arena_lock_body != null and is_instance_valid(level.challenge_arena_lock_body):
            return
        if lock_rect.size == Vector2.ZERO:
            return
        level.challenge_arena_lock_body = level._platform("challenge_arena_lock_wall", lock_rect, level._color("2a1715"), level._theme_boss_material())
        level.challenge_arena_lock_body.set_meta("temporary_challenge_lock", true)
        if level.player != null and is_instance_valid(level.player):
            var safe_x := inside_x
            if is_nan(safe_x):
                safe_x = lock_rect.position.x + lock_rect.size.x + 54.0
            var wall_left := lock_rect.position.x
            var wall_right := lock_rect.position.x + lock_rect.size.x
            var near_wall := absf(level.player.global_position.x - lock_rect.get_center().x) < lock_rect.size.x + 80.0
            var inside_is_left := safe_x < wall_left
            var outside: bool = (inside_is_left and level.player.global_position.x >= wall_left - 8.0) or ((not inside_is_left) and level.player.global_position.x <= wall_right + 8.0)
            if near_wall and outside:
                level.player.global_position = Vector2(safe_x, level.player.global_position.y)
                level.player.set("velocity", Vector2.ZERO)
        return
    if level.challenge_arena_lock_body != null and is_instance_valid(level.challenge_arena_lock_body):
        level._spawn_route_open_effect(level.challenge_arena_lock_body.global_position)
        level.challenge_arena_lock_body.queue_free()
    level.challenge_arena_lock_body = null


static func clear_active_challenge(level: Node, grant_if_empty: bool) -> void:
    if grant_if_empty and not level.active_challenge_id.is_empty() and level.challenge_alive_ids.is_empty():
        grant_optional_challenge_reward(level, optional_challenge(level, level.active_challenge_id))
    set_challenge_arena_locked(level, false)
    level.active_challenge_id = ""
    level.challenge_alive_ids.clear()


static func abort_challenge_if_left_room(level: Node) -> void:
    if level.active_challenge_id.is_empty():
        return
    var room_id := String(optional_challenge(level, level.active_challenge_id).get("room_id", ""))
    if room_id.is_empty() or level.current_room_id == room_id:
        return
    for enemy_node in level.get_tree().get_nodes_in_group("enemy"):
        if String(enemy_node.get_meta("optional_challenge_id", "")) != level.active_challenge_id:
            continue
        if enemy_node.has_method("_cancel_attack_effects"):
            enemy_node._cancel_attack_effects()
        enemy_node.queue_free()
    clear_active_challenge(level, false)
    level._toast("离开试炼")


static func on_challenge_enemy_died(level: Node, spawn_id: String) -> void:
    if not level.challenge_alive_ids.has(spawn_id):
        return
    level.challenge_alive_ids.erase(spawn_id)
    if level.challenge_alive_ids.is_empty() and not level.active_challenge_id.is_empty():
        var challenge: Dictionary = optional_challenge(level, level.active_challenge_id)
        set_challenge_arena_locked(level, false)
        grant_optional_challenge_reward(level, challenge)
        level.active_challenge_id = ""


static func challenge_pending_flag(level: Node, challenge: Dictionary) -> String:
    return "challenge_reward_pending_"+String(challenge.get("id",""))


static func refresh_challenge_claim_label(level: Node, challenge: Dictionary, pending: bool) -> void:
    var shrine: Dictionary=challenge.get("shrine",{})
    var area:=level.get_node_or_null(NodePath(String(shrine.get("id",""))))
    if area==null:return
    var label:="%s · %s" % [String(challenge.get("name","可选挑战")),"胜利待记录" if pending else "已清"]
    area.set_meta("label",label);area.set_meta("interaction_label",label+(" · 领取首清" if pending else " · 回访"))
    var sprite:=area.get_node_or_null("ChallengeShrineSprite") as Sprite2D
    if sprite!=null:level._apply_original_prop(sprite,"lever_open",52)


static func grant_optional_challenge_reward(level: Node, challenge: Dictionary) -> void:
    if not level.world_mode:grant_optional_challenge_reward_legacy(level, challenge);return
    if challenge.is_empty() or level.world_loading or level.build_system==null:return
    var id:=String(challenge.get("id",""))
    if id.is_empty() or optional_challenge(level, id)!=challenge:return
    var clear_flag:=String(challenge.get("clear_flag",""))
    var pending_flag:=challenge_pending_flag(level, challenge)
    if clear_flag.is_empty() or bool(level.story_flags.get(clear_flag,false)):return
    var earned: bool=bool(level.story_flags.get(pending_flag,false)) or (level.active_challenge_id==id and level.challenge_alive_ids.is_empty())
    if not earned:return
    var reward: Dictionary=challenge.get("reward",{})
    var flags: Dictionary=level.story_flags.duplicate(true);flags.erase(pending_flag);flags[clear_flag]=true
    var event:=String(reward.get("unlock_event",""))
    if not event.is_empty():flags[event]=true
    var items: Dictionary={}
    var material:=String(level.config.get("enemy_drop_item","moss_chitin"))
    if int(reward.get("material_amount",0))>0:items[material]=int(reward.material_amount)
    var item:=String(reward.get("item_id",""))
    if not item.is_empty():items[item]=int(items.get(item,0))+int(reward.get("item_amount",1))
    var plan: Dictionary=level._prepare_inventory_progress(items,flags,level.currency_count+maxi(0,int(reward.get("currency",0))))
    var result: Dictionary={"ok":false}
    if plan.ok:result=level._persist_world_change({"inventory_counts":plan.counts,"story_flags":plan.flags,"currency":plan.currency,"build_state":plan.build})
    if not result.ok:
        # This is proof of an earned victory, not a paid reward/clear. A later
        # ordinary save carries it across restart; the shrine retries the claim.
        level.story_flags[pending_flag]=true
        refresh_challenge_claim_label(level, challenge,true)
        level._toast("已赢得这次挑战，首清奖励尚未记录；回到这座余响钟可重试领取。")
        return
    level._publish_inventory_progress(plan,result.candidate)
    refresh_challenge_claim_label(level, challenge,false)
    if not item.is_empty():level._announce_lore_pickup(item)
    level._toast(String(reward.get("toast","%s首清。" % String(challenge.get("name","可选挑战")))))
    level._refresh_hud()


static func grant_optional_challenge_reward_legacy(level: Node, challenge: Dictionary) -> void:
    if challenge.is_empty():
        return
    var clear_flag := String(challenge.get("clear_flag", ""))
    if clear_flag.is_empty():
        return
    if bool(level.story_flags.get(clear_flag, false)):
        return
    level.story_flags[clear_flag] = true
    var reward: Dictionary = challenge.get("reward", {})
    var currency := int(reward.get("currency", 0))
    if currency > 0:
        level._add_currency(currency)
    var material_amount := int(reward.get("material_amount", 0))
    if material_amount > 0:
        level._add_inventory_item(String(level.config.get("enemy_drop_item", "moss_chitin")), material_amount, false)
    var item_id := String(reward.get("item_id", ""))
    if not item_id.is_empty():
        level._add_inventory_item(item_id, int(reward.get("item_amount", 1)), false)
        level._announce_lore_pickup(item_id)
    var unlock_event := String(reward.get("unlock_event", ""))
    if not unlock_event.is_empty():
        level.story_flags[unlock_event] = true
        if level.build_system != null:
            level.build_system.unlock_event(unlock_event)
            level._sync_player_build()
    var message := String(reward.get("toast", "%s首清。" % String(challenge.get("name", "可选挑战"))))
    level._toast(message)
    var shrine: Dictionary = challenge.get("shrine", {})
    var shrine_id := String(shrine.get("id", "challenge_shrine_%s" % String(challenge.get("id", ""))))
    var area: Node = level.get_node_or_null(NodePath(shrine_id))
    if area != null and is_instance_valid(area):
        area.set_meta("label", "%s · 已清" % String(challenge.get("name", "可选挑战")))
        area.set_meta("interaction_label", String(area.get_meta("label")) + " · 回访")
        var sprite: Sprite2D = area.get_node_or_null("ChallengeShrineSprite") as Sprite2D
        if sprite != null:
            level._apply_original_prop(sprite, "lever_open", 52)
    level._save_world()
