extends SceneTree
## A real legacy seed supplies worker_badge. NPC positioning is a component
## fixture using the authored quest, not a natural rain-foundry traversal.
const BUILD = preload("res://scripts/build_system.gd")
const LEVEL = preload("res://scripts/main_level.gd")
const PLAYER = preload("res://scenes/Player.tscn")
const WORLD_STATE = preload("res://scripts/world_state.gd")
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
const POGO = preload("res://scripts/hazard_pogo.gd")
var checks := 0
var failures := 0
var level: Node2D
var player: CharacterBody2D
var output := ""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks += 1
    print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures += 1
func frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame
func retire(node: Node) -> void:
    RETIREMENT.retire_tree(node);node.queue_free();await frames(5)
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"audio ownership retires")
func open_world(path: String) -> Node2D:
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_save_path = path;world.world_resume = true
    root.add_child(world);current_scene = world
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    return world
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output = arg.trim_prefix("--output=")
    var path := "user://legacy_damp_%d.json" % OS.get_process_id()
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_buffer(FileAccess.get_file_as_bytes("res://tests/fixtures/quiet_sole_earned_return.json"));file.close()
    var world: Node2D = await open_world(path)
    check(world.initial_region_ready and int(world.inventory_counts.get("worker_badge",0)) == 1,"real World restores earned legacy worker badge")
    var rain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch02_rain_foundry_canal.json"))
    var authored: Dictionary = {}
    var npc_id := ""
    for npc in rain.npcs:
        var quest: Dictionary = npc.get("dialogue_topics",{}).get("quest",{})
        if String(quest.get("reward","")) == "damp_knot":authored = quest.duplicate(true);npc_id = String(npc.id)
    check(not authored.is_empty() and authored.get("item","") == "worker_badge" and not bool(authored.get("consume",true)),"unchanged authored rain-smith wish is the damp reward source")
    var area := Area2D.new();area.name = "DampRewardPositionedFixture"
    area.set_meta("kind","npc");area.set_meta("npc_id",npc_id);area.set_meta("dialogue_topics",{"wish":"authored wish fixture","quest":authored})
    area.set_meta("world_line_committed",true);world.add_child(area)
    # The wish is delivered through the real dialogue: beside the player, preview first, then confirm.
    area.global_position = world.player.global_position
    world._show_dialogue(area,"authored wish fixture")
    world.ui_shell.dialogue_area = area;world.ui_shell._topic("wish")
    var wish_modal = world.ui_shell.wish_confirmation
    check(is_instance_valid(wish_modal) and wish_modal.visible and int(world.inventory_counts.get("damp_knot",0)) == 0,"production UI wish preview grants nothing before confirmation")
    if is_instance_valid(wish_modal):wish_modal.confirmed.emit()
    check(int(world.inventory_counts.get("damp_knot",0)) == 1 and int(world.inventory_counts.get("worker_badge",0)) == 1,"production UI authored wish grants original damp item without consuming badge")
    check(world.build_system.state.unlocked_passives.has("damp_knot"),"real damp item unlocks its own accessory identity")
    check(is_equal_approx(float(world.player.build_profile.get("hazard_trigger_mult",1)),1),"reward ownership alone does not shrink traps")
    var disk := WORLD_STATE.new()
    check(disk.read(path) and int(disk.data.inventory_counts.get("damp_knot",0)) == 1,"reward exists in a production-valid persisted inventory")
    # Migration fixture represents the pre-mapping Build schema: actual obtained
    # inventory remains intact, while no new accessory unlock is serialized.
    disk.data.build_state.unlocked_passives.erase("damp_knot")
    check(disk.write(path),"legacy inventory fixture stores no damp Build unlock")
    if not output.is_empty():
        file = FileAccess.open(output.path_join("legacy_inventory_fixture.json"),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close()
    await retire(world)
    world = await open_world(path)
    check(world.initial_region_ready and world.build_system.state.unlocked_passives.has("damp_knot"),"new World derives damp unlock from legacy inventory after disk read")
    var counts: Dictionary = world.inventory_counts.duplicate(true)
    var build: RefCounted = world.build_system
    build.sync_progress(counts,"",{"quest_bring_names_complete":true})
    check(build.equip_family_slot("quiet_sole","travel_accessory",0).ok and build.save_loadout("旧静靴方案").ok,"old quiet-sole equipment and saved plan remain valid")
    var quiet_plan: Dictionary = build.serialize()
    check(build.equip_family_slot("damp_knot","travel_accessory",0).ok,"damp uses its own unlocked travel slot entry")
    var before: Dictionary = build.serialize()
    var conflict: Dictionary = build.equip_family_slot("quiet_sole","travel_accessory",1)
    check(not conflict.ok and build.serialize() == before and String(conflict.get("reason","")).contains("防潮线结") and String(conflict.get("reason","")).contains("静靴"),"same-effect accessories reject simultaneous equipment with both original names")
    var damp_group := String(build.catalog.passives.get("damp_knot",{}).get("group",""))
    check(not damp_group.is_empty() and damp_group == String(build.catalog.passives.quiet_sole.group),"existing group contract prevents accidental stacking")
    check(build.save_loadout("防潮结方案").ok,"damp plan saves through existing loadout model")
    check(world._save_world() and disk.read(path),"World checkpoint persists the equipped damp and both plans")
    var saved: Dictionary = disk.data.build_state.duplicate(true)
    if not output.is_empty():
        file = FileAccess.open(output.path_join("loadout_saved_world.json"),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close()
    var restarted := BUILD.new()
    check(restarted.restore(saved).ok,"full inventory-derived equipment and plans restore")
    restarted.sync_progress(counts)
    check(restarted.restore_loadout("旧静靴方案").ok and restarted.state.passives.has("quiet_sole") and not restarted.state.passives.has("damp_knot"),"old quiet plan restores original identity")
    check(restarted.restore_loadout("防潮结方案").ok and restarted.state.passives.has("damp_knot") and is_equal_approx(float(restarted.profile().get("hazard_trigger_mult",1)),0.8),"damp plan restores its own 80 percent profile")
    check(restarted.state.passives.has("damp_knot") and not restarted.state.passives.has("quiet_sole"),"physical fixture carries damp itself, with quiet sole inactive")
    quiet_plan.unlocked_passives.erase("damp_knot")
    var old_model := BUILD.new()
    check(old_model.restore(quiet_plan).ok and old_model.state.passives.has("quiet_sole"),"pre-damp quiet-only serialized equipment remains accepted")
    var slots_compatible := true
    for crest in build.catalog.crests.values():
        for slot in crest.slot_layout.travel_accessory:
            if not slot.compatible.has("damp_knot") or not slot.compatible.has("quiet_sole"):slots_compatible = false
    check(slots_compatible,"all three crests retain quiet and accept the independent damp travel entry")
    var damp_entry: Dictionary = build.catalog.passives.get("damp_knot",{}).duplicate(true)
    damp_entry["id"] = "damp_knot"
    world.ui_shell.build_category = "铭饰";world.ui_shell.build_family = "travel_accessory"
    world.ui_shell._show_build_detail(damp_entry)
    check(world.ui_shell.build_heading.text == "防潮线结" and world.ui_shell.build_detail.text.contains("与静靴互斥") and world.ui_shell.build_detail.text.contains("20%"),"production UI displays original damp name percentage and mutual exclusion")
    world.ui_shell._show_build_detail(build.catalog.passives.quiet_sole.merged({"id":"quiet_sole"}))
    check(world.ui_shell.build_heading.text == "静靴" and world.ui_shell.build_detail.text.contains("与防潮线结互斥"),"production quiet detail explains the same group conflict")
    if not output.is_empty() and DisplayServer.get_name() != "headless":
        world.ui_shell.build_selection = "damp_knot"
        world._toggle_build()
        world.ui_shell._show_build_detail(damp_entry)
        await RenderingServer.frame_post_draw
        check(world.active_overlay == "build" and world.ui_shell.build_panel.is_visible_in_tree(),"production build panel remains visible for native capture")
        check(root.get_texture().get_image().save_png(output.path_join("damp_build_detail.png")) == OK,"native production UI evidence captured")
    await retire(world)
    # Production Player and hazard factory in an isolated floor fixture.
    level = Node2D.new();root.add_child(level);level.set_script(LEVEL)
    level.set_process(false);level.set_physics_process(false);level.world_mode = true;level.world_loading = false
    level.inventory_counts = counts;level.build_system = restarted
    player = PLAYER.instantiate();root.add_child(player);player.feel = null;level.player = player
    level._sync_player_build()
    var floor_body := StaticBody2D.new();floor_body.position = Vector2(400,312);floor_body.collision_layer = 17
    var floor_shape := CollisionShape2D.new();floor_shape.shape = RectangleShape2D.new();floor_shape.shape.size = Vector2(1200,24)
    floor_body.add_child(floor_shape);root.add_child(floor_body)
    var trap := hazard("damp_trap",[200,100,200,200])
    var other := hazard("other_trap",[700,100,100,100])
    check(size_of(trap) == Vector2(160,160) and size_of(other) == Vector2(80,80),"equipped damp shrinks independent authored trap sizes")
    check(trap.get_node("TriggerShape").shape != other.get_node("TriggerShape").shape,"trap shapes cannot cross-mutate")
    check(player.get_node("CollisionShape2D").shape.size == Vector2(34,84) and POGO.surface_rect(trap) == Rect2(200,100,200,200),"Player body and spike pogo surface preserve original geometry")
    await reset_player(Vector2(170,300))
    var hp: int = player.hp
    Input.action_press("move_right")
    for i in 30:
        if player.position.x >= 190 or player.hp != hp:break
        await frames(1)
    Input.action_release("move_right");player.velocity.x = 0
    await frames(3)
    check(player.position.x >= 190 and player.position.x < 201 and player.hp == hp and not trap.overlaps_body(player),"real move input reaches original outer edge safely with damp equipped")
    Input.action_press("move_right")
    for i in 20:
        await frames(1)
        if player.hp < hp:break
    Input.action_release("move_right")
    check(player.hp == hp-1 and trap.overlaps_body(player),"continuing real input enters damp inner shape and takes unchanged damage")
    await reset_player(Vector2(190,300))
    restarted.equip_family_slot("","travel_accessory",0);level._sync_player_build();await frames(4)
    check(size_of(trap) == Vector2(200,200) and player.hp == player.max_hp-1,"stationary removal expands Area and triggers real collision damage")
    restarted.equip_family_slot("damp_knot","travel_accessory",0);level._sync_player_build();await frames(4)
    check(not trap.overlaps_body(player),"stationary reequipment removes original outer overlap")
    restarted.equip_family_slot("","travel_accessory",0)
    restarted.equip_family_slot("damp_knot","travel_accessory",1)
    restarted.state.unlocked_crests.append("bell") # Explicit known/unrepaired crest fixture.
    restarted.switch_crest("bell");level._sync_player_build();await frames(3)
    check(size_of(trap) == Vector2(200,200) and not restarted.state.passives.has("damp_knot"),"dormant expansion leaves no damp trap modifier")
    trap.free();trap = hazard("rebuilt_trap",[200,100,200,200])
    check(size_of(trap) == Vector2(200,200),"region-style rebuild uses current dormant profile")
    restarted.switch_crest("crimson");level._sync_player_build();await frames(3)
    check(size_of(trap) == Vector2(160,160),"returning active crest resynchronizes rebuilt trap")
    var projected: Dictionary = restarted.preview_loadout("旧静靴方案")
    check(projected.ok and is_equal_approx(float(projected.profile.get("hazard_trigger_mult",1)),0.8) and not projected.equipped_families.travel_accessory.has("damp_knot"),"quiet plan preview remains separate and never stacks with damp")
    Input.action_release("move_right")
    RETIREMENT.retire_tree(level);RETIREMENT.retire_tree(player)
    level.queue_free();player.queue_free();floor_body.queue_free();await frames(5)
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"fixture audio ownership retires")
    print("LEGACY_TRAVEL_REWARDS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
func hazard(id: String,rect: Array) -> Area2D:
    level._hazard({"id":id,"kind":"spikes","rect":rect,"damage":1})
    return level.get_node(id)
func size_of(area: Area2D) -> Vector2:return area.get_node("TriggerShape").shape.size
func reset_player(at: Vector2) -> void:
    player.position = at;player.velocity = Vector2.ZERO;player.hp = player.max_hp
    player.arrival_guard_timer = 0;player.hurt_timer = 0
    await frames(4)
