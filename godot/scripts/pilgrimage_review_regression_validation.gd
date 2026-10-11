extends SceneTree

const ART := preload("res://scripts/hand_drawn_assets.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
const GENERATED := preload("res://scripts/generated_runtime_validation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("REVIEW_REGRESSION_FAIL " + message)

func _run() -> void:
    var scene: Node = load("res://scenes/Main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    scene.player.set_physics_process(false)
    scene.set_process(false)
    scene.set_physics_process(false)
    for actor in get_nodes_in_group("enemy"):
        actor.set_physics_process(false)
    _validate_bag(scene)
    _validate_settings(scene)
    await _validate_hazards(scene)
    await _validate_generated_art(scene)
    scene.queue_free()
    await process_frame
    print("PILGRIMAGE_REVIEW_REGRESSION checks=%d failures=%d" % [checks,failures])
    quit(1 if failures > 0 else 0)

func _validate_bag(scene: Node) -> void:
    scene.inventory_counts={"heart_knot":1,"moss_chitin":2,"crown_splinter":1}
    scene._refresh_backpack_overlay()
    var ui: Control=scene.ui_shell
    scene.backpack_selection=scene.backpack_entry_ids.find("heart_knot")
    ui.bag_category="材料"
    ui.refresh_inventory()
    _check(ui._reconcile_inventory_selection()=="moss_chitin", "category switch chooses visible material")
    for button in ui.bag_grid.get_children():
        _check(String(button.get_meta("item_id"))=="moss_chitin", "material grid excludes currency and other categories")
    scene._move_backpack_selection(1)
    _check(ui._reconcile_inventory_selection()=="moss_chitin", "keyboard wraps inside active category")
    ui._pin_item()
    _check(bool(scene.story_flags.get("ui_pin_moss_chitin",false)), "pin follows visible selection")
    _check(not bool(scene.story_flags.get("ui_pin_heart_knot",false)), "hidden upgrade is not pinned")
    ui.bag_category="遗物"
    ui.refresh_inventory()
    _check(ui.bag_pin.disabled and ui.bag_icon.texture==null, "empty category disables pin and clears detail")
    ui._pin_item()
    _check(not scene.story_flags.has("ui_pin_"), "empty category cannot pin an empty id")
    ui.bag_category="全部"
    ui.refresh_inventory()
    _check(ui._visible_inventory_ids().has("currency"), "all tab retains currency")

func _validate_settings(scene: Node) -> void:
    var ui: Control=scene.ui_shell
    scene.settings_selection=0
    scene._refresh_settings_overlay()
    var first_key:=String(scene.AUDIO_SETTINGS_ROWS[0][0])
    var second_key:=String(scene.AUDIO_SETTINGS_ROWS[1][0])
    _check(String(ui.settings_labels[first_key].text).begins_with("▶ "), "first settings row is visibly selected")
    scene._move_settings_selection(1)
    _check(String(ui.settings_labels[second_key].text).begins_with("▶ ") and not String(ui.settings_labels[first_key].text).begins_with("▶ "), "keyboard selection moves visible marker")
    ui.settings_sliders[second_key].value=70
    var before: float=scene.audio_director.get_user_volume(second_key)
    scene._adjust_settings_volume(-5)
    _check(is_equal_approx(scene.audio_director.get_user_volume(second_key),before-5), "keyboard adjusts selected channel")
    ui.settings_sliders[first_key].value=65
    _check(scene.settings_selection==0 and String(ui.settings_labels[first_key].text).begins_with("▶ "), "mouse slider selection updates keyboard target")

func _validate_hazards(scene: Node) -> void:
    var actor: Area2D=ENEMY.new()
    actor.is_boss=true
    actor.max_hp=100
    actor.hp=100
    scene.add_child(actor)
    actor.set_physics_process(false)
    for kind in ["beam","pool","rootline"]:
        actor.battle_phase=1
        actor.phase_pause=0
        actor.hp=100
        actor._begin_attack({"id":"regression_"+kind,"type":kind,"windup":0.4,"active":0.3,"hazard_life":1.0})
        var pending: Array=actor.owned_attack_effects.duplicate()
        _check(not pending.is_empty(), kind+" starts real windup effects")
        actor.hp=40
        actor._physics_process(0.01)
        _check(actor.phase_pause>0 and actor.active_attack.is_empty(), kind+" interrupts at phase threshold")
        for effect in pending:
            _check(effect.cancelled and not effect.is_in_group("hostile_attack"), kind+" interrupted hazard is immediately disarmed")
            var age_before: float=effect.age
            effect._physics_process(2.0)
            _check(effect.age==age_before, kind+" cancelled effect cannot advance or hit")
        await process_frame
    actor.is_boss=false
    actor.hp=10
    actor.phase_pause=0
    actor._begin_attack({"id":"hurt_pool","type":"pool","windup":0.4})
    var hurt_effects: Array=actor.owned_attack_effects.duplicate()
    actor.take_hit(1,1)
    _check(actor.active_attack.is_empty(), "hurt interrupt clears nonboss command")
    for effect in hurt_effects:
        _check(effect.cancelled, "hurt interrupt cancels pending effect")
    await process_frame
    var normal: Node2D=actor._effect("beam",Vector2.ZERO,Vector2.ZERO,{},0.4,1.0)
    _check(not normal.cancelled, "normal attack effect remains alive without interruption")
    actor._begin_death_dissolve()
    _check(normal.cancelled, "actor death cancels sibling effects")
    await process_frame
    var reset_actor: Area2D=ENEMY.new()
    scene.add_child(reset_actor)
    reset_actor.set_physics_process(false)
    var reset_effect: Node2D=reset_actor._effect("pool",Vector2.ZERO,Vector2.ZERO,{},0.4,1.0)
    scene._reset_encounters_after_player_death()
    _check(reset_effect.cancelled, "encounter reset immediately cancels hazards")
    await process_frame

func _validate_generated_art(scene: Node) -> void:
    var npc_count:=0
    var ability_count:=0
    var currency: AtlasTexture=ART.item("currency")
    for path in GENERATED.CONFIG_PATHS:
        var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
        for data in config.get("npcs",[]):
            var id:=String(data.get("id",""))
            scene._npc(data)
            var area: Area2D=scene.get_node(id)
            var sprite:=area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
            _check(sprite!=null and sprite.sprite_frames.get_frame_count("idle")>0, "generated NPC visible: "+id)
            _check(ART.portrait(id)!=null and String(area.get_meta("npc_id"))==id, "generated portrait preserves dialogue id: "+id)
            npc_count+=1
        for data in config.get("collectibles",[]):
            var id:=String(data.get("item_id",""))
            if not id.contains("_ability_"):continue
            var icon:=ART.item(id) as AtlasTexture
            _check(icon!=null and (icon.atlas!=currency.atlas or icon.region!=currency.region), "generated ability has a noncurrency icon: "+id)
            ability_count+=1
    _check(npc_count==36, "all 36 generated NPCs covered")
    _check(ability_count==18, "all 18 generated ability icons covered")
