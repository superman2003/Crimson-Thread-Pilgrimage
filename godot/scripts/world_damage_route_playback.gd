extends SceneTree
## Damage-enabled input playback: earned map/quill, shrine charting and returns.
## No grants, position writes, damage suppression or state repair. Not a human playtest.
const SAVE := "user://test_world_damage_route.json"
var scene: Node
var failures := 0
var frames := 0
var jump_hold := 0
var jump_rearm := 0
var steps := 0
var last_hp := -1
var last_region := ""
var deaths := 0
var last_wallet := -1
var attack_pressed_frame := -100
var last_inventory: Dictionary = {}
var combat_enabled := false
var damage_events := 0
var heals := 0
var purchases := 0
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const SHOP_RUNTIME := preload("res://scripts/cartography_runtime.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if String(arg).begins_with("--damage-restart-proof="):
            var restart_proof: Variant = JSON.parse_string(String(arg).trim_prefix("--damage-restart-proof="))
            if not restart_proof is Dictionary:
                _check(false,"restart proof must be a JSON object")
                quit(1)
                return
            await _verify_process_restart(restart_proof)
            return
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists(SAVE + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _tick(15)
    _check(scene.currency_count==0,"fresh route starts without currency")
    _check(not scene.inventory_counts.has("silk_wall_grip"),"fresh route starts without wall grip")
    _check(not SHOP_RUNTIME.owns_tool(scene,"quill") and not SHOP_RUNTIME.owns_tool(scene,"compass"),"fresh route has neither paid survey tool")
    _check(not SHOP_RUNTIME.shows_position(scene),"route uses no compass or navigation-assist position")
    _check(not scene.inventory_counts.has("double_thread_jump"), "fresh start lacks double jump")
    await _walk(Vector2(410,3400), "initial lift")
    await _interact("moss_salt_lift_lower", "demo_ch01_moss_bell_court", Vector2(4850,610))
    await _walk(Vector2(5240,560), "first salt obstruction", true)
    _check(scene.player.position.x < 5080, "salt gate blocks unupgraded player")
    _check(not scene.inventory_counts.has("testimony_returned_name"), "salt reward cannot be collected before ability")
    await _walk(Vector2(4850,650), "return from obstruction")
    await _interact("moss_salt_lift_upper", "demo_ch01_moss_bell_court", Vector2(410,3360))
    for p in [Vector2(640,3452),Vector2(870,3532),Vector2(1130,3612),Vector2(1420,3692),Vector2(1790,3752)]:
        await _walk(p,"moss drainage")
    await _interact("moss_rain_pipe", "demo_ch02_rain_foundry_canal", Vector2(330,720))
    for p in [Vector2(620,812),Vector2(960,880),Vector2(1350,836),Vector2(1700,920)]:
        await _walk(p,"rain repair route")
    _check(scene.inventory_counts.has("silk_wall_grip"), "wall grip obtained by walking into pickup")
    await _walk(Vector2(1350,836), "rain riser return")
    await _interact("rain_archive_riser", "demo_ch03_saltwhite_archive", Vector2(430,2580))
    for p in [Vector2(700,2570),Vector2(1050,2620),Vector2(1430,2556),Vector2(1760,2612),Vector2(2090,2548),Vector2(1930,2442),Vector2(1740,2350),Vector2(1640,2240),Vector2(1440,2240)]:
        await _walk(p,"archive candle route",false,p.x in [1640.0,1440.0])
    _check(scene.inventory_counts.has("double_thread_jump"), "double jump obtained in archive")
    await _walk(Vector2(1640,2240),"archive return line",false,true)
    await _interact("archive_moss_return", "demo_ch01_moss_bell_court", Vector2(280,3360))
    await _walk(Vector2(410,3400), "old lift revisited")
    await _interact("moss_salt_lift_lower", "demo_ch01_moss_bell_court", Vector2(4850,610))
    await _walk(Vector2(5240,560), "salt testimony revisited")
    await _tick(3)
    Input.action_press("interact")
    # The host polls F during _process; hold through a render tick rather
    # than assuming one physics signal includes a render tick on every runner.
    await process_frame
    await _tick()
    Input.action_release("interact")
    await _tick(4)
    _check(scene.inventory_counts.has("testimony_returned_name"), "return unlocks testimony reward through F pickup")
    await _walk(Vector2(5340,560), "permanent shortcut upper")
    await _interact("moss_salt_shortcut_upper", "demo_ch01_moss_bell_court", Vector2(200,3360))
    _check(bool(scene.story_flags.get("world_shortcut_salt_return", false)), "salt return shortcut persists after regional lift")
    await _interact("moss_salt_shortcut_lower", "demo_ch01_moss_bell_court", Vector2(5340,520))
    _check(scene.inventory_counts.has("double_thread_jump") and scene.inventory_counts.has("testimony_returned_name"), "ability and reward retained on shortcut return")
    await _interact("moss_salt_shortcut_upper", "demo_ch01_moss_bell_court", Vector2(200,3360))
    for p in [Vector2(640,3452),Vector2(870,3532),Vector2(1130,3612),Vector2(1420,3692),Vector2(1790,3752)]:
        await _walk(p,"return to canal without a purchased map")
    await _interact("moss_rain_pipe", "demo_ch02_rain_foundry_canal", Vector2(330,720))
    for p in [Vector2(620,812),Vector2(960,880),Vector2(1270,836),Vector2(1420,836),Vector2(1700,920),Vector2(1640,920)]:
        await _walk(p,"canal cartographer return",false,p.x in [1420.0,1700.0])
    await _buy_map_and_quill()
    for p in [Vector2(2040,1000),Vector2(2320,1080),Vector2(2540,1160),Vector2(2730,1160),Vector2(2990,1240)]:
        await _walk(p,"first mapped canal shrine",false,p.x==2730.0)
    var pending_before: int=preload("res://scripts/pilgrimage_cartography.gd").pending_count(scene.story_flags)
    _check(pending_before>0,"natural travel has pending notes before resting")
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch02_aqueduct","F rests at the authored aqueduct shrine")
    _check(preload("res://scripts/pilgrimage_cartography.gd").pending_count(scene.story_flags)==0,"purchased quill charts actual travel notes at rest")
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal shrine restores health and energy")
    await _inspect_map_without_position()
    var saved_wallet: int=scene.currency_count
    var earned_inventory: Dictionary=scene.inventory_counts.duplicate(true)
    var charted: Dictionary=JOURNAL.region(scene.story_flags,"demo_ch02_rain_foundry_canal").charted.duplicate(true)
    _check(not charted.is_empty(),"actual travel produced charted canal notes")
    var proof := {"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":saved_wallet,"inventory":earned_inventory,"charted":charted}
    _release()
    scene.queue_free()
    await process_frame
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_save_path = SAVE
    scene.world_resume = true
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _tick(15)
    _check(scene.inventory_counts.has("testimony_returned_name") and scene.inventory_counts.has("double_thread_jump"), "restart restores earned ability and unique testimony")
    _check(bool(scene.story_flags.get("world_shortcut_salt_return", false)), "restart restores permanent salt shortcut")
    _check(str(scene.config.id) == "demo_ch02_rain_foundry_canal" and scene.player.position.distance_to(Vector2(2990,1200))<90, "restart restores canal at the actual rested shrine")
    _check(preload("res://scripts/pilgrimage_cartography.gd").owned(scene.story_flags,String(scene.config.id)) and preload("res://scripts/pilgrimage_cartography.gd").has_quill(scene.story_flags),"restart retains paid map and quill")
    _check(scene.currency_count==saved_wallet,"restart retains the earned wallet after actual purchases")
    _check(scene.inventory_counts==earned_inventory,"World recreation retains all earned item counts")
    _check(damage_events>0 and heals>0,"journey includes actual damage and energy-paid healing")
    _check(purchases==2,"both paid purchases were confirmed by inventory and price changes")
    _check(deaths==0,"damage-enabled return completes without death or state repair")
    _release()
    scene.queue_free()
    scene=null
    for unused in 10: await process_frame
    print("DAMAGE_ROUTE_RESTART_PROOF "+JSON.stringify(proof))
    print("WORLD_DAMAGE_ROUTE_PLAYBACK steps=%d physics_frames=%d damage_events=%d heals=%d deaths=%d purchases=%d charted=true failures=%d damage_suppression=false" % [steps,frames,damage_events,heals,deaths,purchases,failures])
    quit(0 if failures == 0 else 1)

func _tick(count: int = 1) -> void:
    for unused in range(count):
        _battle_inputs()
        await physics_frame
        frames += 1
        if is_instance_valid(scene) and is_instance_valid(scene.player):
            assert(not scene.player.debug_invulnerable)
            if not scene.world_loading and String(scene.config.id)==last_region and scene.player.hp<last_hp:
                damage_events+=1
            if scene.player.hp != last_hp or String(scene.config.id) != last_region or scene.currency_count != last_wallet or scene.inventory_counts != last_inventory:
                print("DAMAGE_ROUTE_STATE ",JSON.stringify({"frame":frames,"region":String(scene.config.id),"position":[scene.player.position.x,scene.player.position.y],"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"passage":scene.world_passage.active,"loading":scene.world_loading,"phase":scene.world_loader.phase,"inventory":scene.inventory_counts}))
                if scene.player.hp==0:deaths+=1
                last_inventory=scene.inventory_counts.duplicate(true)
                last_wallet=scene.currency_count
                last_hp=scene.player.hp
                last_region=String(scene.config.id)
        for child in root.get_children():
            if child.get("world_mode") == true and not child.is_queued_for_deletion():
                scene = child

func _walk(target: Vector2, label: String, obstruction: bool = false, immediate_jump: bool = false) -> void:
    steps += 1
    print("DAMAGE_ROUTE_STEP ",label," target=",target)
    _release()
    await _tick(2)
    jump_hold = 0
    jump_rearm = 0
    if immediate_jump:
        Input.action_press("jump")
        jump_hold = 45
    for frame in range(700):
        if scene.world_passage.active:
            if target.distance_to(scene.world_passage.source_point)<90:
                _release()
                print("WALK %s deliberately entered its authored mouth" % label)
                return
            _check(false,"unexpected automatic passage during local walk: " + String(scene.world_passage.route.get("id","")))
            quit(1)
            await process_frame
            return
        var player: CharacterBody2D = scene.player
        var dx: float = target.x - player.global_position.x
        var rise: float = player.global_position.y - target.y
        if absf(dx) < 16 and absf(rise) < 50 and player.is_on_floor():
            _release()
            print("WALK %s reached %s" % [label,str(player.global_position)])
            return
        var foe := _near_foe()
        if foe != null and player.is_on_floor() and not Input.is_action_pressed("jump"):
            jump_hold=0
            jump_rearm=0
            var enemy_dx: float = foe.global_position.x-player.global_position.x
            _axis(signf(enemy_dx) if absf(enemy_dx)>100 or player.facing!=signi(enemy_dx) else 0.0)
            combat_enabled=true
            await _tick()
            combat_enabled=false
            continue
        if foe == null and player.is_on_floor() and not Input.is_action_pressed("jump") and player.hp < player.max_hp and player.energy >= player.heal_energy_cost and frame % 60 == 0:
            await _recover()
        _axis(signf(dx) if absf(dx) > 8 else 0)
        if jump_hold > 0:
            jump_hold -= 1
            if jump_hold == 0:
                Input.action_release("jump")
                jump_rearm = 4
        elif jump_rearm > 0:
            jump_rearm -= 1
        elif player.is_on_floor():
            var ahead := player.global_position + Vector2(signf(dx)*52,-3)
            var query := PhysicsRayQueryParameters2D.create(ahead,ahead+Vector2(0,90),1,[player.get_rid()])
            var gap: bool = player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
            if (rise > 25 and absf(dx)<165) or (gap and absf(dx)>50) or (player.is_on_wall() and absf(dx)>30):
                Input.action_press("jump")
                jump_hold = 45
        elif player.wall_grip_unlocked and player.is_on_wall() and absf(dx)>30 and player.hurt_timer<=0:
            Input.action_press("jump")
            jump_hold=30
            print("DAMAGE_ROUTE_WALL_JUMP ",player.global_position)
        elif player.double_jump_unlocked and rise > 50 and player.velocity.y > -100 and player.air_jump_available and jump_hold == 0 and jump_rearm == 0:
            Input.action_press("jump")
            jump_hold = 35
        await _tick()
        if obstruction and frame > 90 and player.global_position.x > 5035:
            _release()
            print("WALK %s observed blocked at %s" % [label,str(player.global_position)])
            return
        if frame % 150 == 149:
            print("WALK pending %s target=%s position=%s velocity=%s floor=%s" % [label,str(target),str(player.global_position),str(player.velocity),str(player.is_on_floor())])
    _release()
    print("DAMAGE_ROUTE_BLOCKED overlay=%s floor=%s wall=%s velocity=%s jump=%s heal=%s attack=%s" % [scene.active_overlay,scene.player.is_on_floor(),scene.player.is_on_wall(),scene.player.velocity,Input.is_action_pressed("jump"),scene.player.heal_timer,scene.player.attack_timer])
    _check(false,"route failed: %s target=%s actual=%s" % [label,str(target),str(scene.player.global_position)])
    quit(1)
    await process_frame

func _interact(portal_id: String, target_region: String, spawn: Vector2) -> void:
    _release()
    await _tick(3)
    Input.action_press("interact")
    await process_frame
    await _tick()
    Input.action_release("interact")
    await process_frame
    if scene.world_passage.active:
        _axis(signf(scene.world_passage.destination_point.x - scene.world_passage.source_point.x))
        for frame in range(3600):
            await _tick()
            if not scene.world_passage.active:
                break
        _release()
        _check(not scene.world_passage.active, "full pipe walked with collision and input")
    for frame in range(2000):
        if not _transition_busy():
            break
        await process_frame
    _check(not _transition_busy(), "budgeted physical portal settles including deferred request and preflight")
    if _transition_busy():
        _release()
        quit(1)
        await process_frame
        return
    await _tick(15)
    _check(str(scene.config.id) == target_region and scene.player.global_position.distance_to(spawn) < 90, "physical portal %s arrives at destination" % portal_id)
    if failures > 0:
        print("WORLD_ROUTE_WALK_VALIDATION aborted actual=%s %s" % [str(scene.config.id),str(scene.player.global_position)])
        quit(1)
        await process_frame

func _transition_busy() -> bool:
    if not is_instance_valid(scene):
        return false
    var loader: Variant = scene.world_loader
    return scene.world_portal_request_pending or scene.chapter_transitioning or scene.world_loading or (is_instance_valid(loader) and loader.phase != "idle")

func _axis(direction: float) -> void:
    if direction > 0:
        Input.action_release("move_left"); Input.action_press("move_right")
    elif direction < 0:
        Input.action_release("move_right"); Input.action_press("move_left")
    else:
        Input.action_release("move_left"); Input.action_release("move_right")

func _release() -> void:
    for action in ["move_left","move_right","jump","interact","attack","heal"]:
        Input.action_release(action)

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error(label)
    else:
        print("PASS "+label)

func _near_foe() -> Node2D:
    if not is_instance_valid(scene) or not is_instance_valid(scene.player): return null
    var closest: Node2D
    var distance := 180.0
    for enemy in get_nodes_in_group("enemy"):
        if not is_instance_valid(enemy) or not enemy is Node2D or enemy.get("hp") == null or int(enemy.get("hp")) <= 0: continue
        var delta: Vector2 = enemy.global_position-scene.player.global_position
        if absf(delta.y)<100 and absf(delta.x)<distance:
            closest=enemy
            distance=absf(delta.x)
    return closest

func _battle_inputs() -> void:
    if frames-attack_pressed_frame>=3: Input.action_release("attack")
    if not combat_enabled or not is_instance_valid(scene) or not is_instance_valid(scene.player) or _transition_busy() or not String(scene.active_overlay).is_empty(): return
    var player: CharacterBody2D = scene.player
    if player.hp<=0 or player.death_timer>0: return
    var target := _near_foe()
    if target != null and frames % 24 == 0 and not Input.is_action_pressed("jump"):
        print("DAMAGE_ROUTE_ATTACK ",JSON.stringify({"frame":frames,"position":[player.position.x,player.position.y],"facing":player.facing,"hp":player.hp,"hurt":player.hurt_timer,"attack_timer":player.attack_timer,"enemy_position":[target.position.x,target.position.y],"enemy_hp":target.get("hp")}))
        Input.action_press("attack")
        attack_pressed_frame=frames

func _recover() -> void:
    _release()
    jump_hold=0
    jump_rearm=0
    await _tick(3)
    if not bool(scene.player.get_heal_readiness().available): return
    var before_hp: int=scene.player.hp
    var before_energy: int=scene.player.energy
    Input.action_press("heal")
    await process_frame
    await _tick(3)
    Input.action_release("heal")
    for frame in 90:
        if scene.player.heal_timer<=0:break
        await _tick()
    if scene.player.hp>before_hp and scene.player.energy<before_energy:heals+=1
    print("DAMAGE_ROUTE_HEAL_COMPLETED ",JSON.stringify({"frame":frames,"before_hp":before_hp,"after_hp":scene.player.hp,"before_energy":before_energy,"after_energy":scene.player.energy}))

func _world_interact() -> void:
    _release()
    await _tick(3)
    Input.action_press("interact")
    await process_frame
    await _tick(3)
    Input.action_release("interact")
    await process_frame
    await _tick(4)

func _key(code: int, dialog: Window) -> void:
    var event:=InputEventKey.new()
    event.keycode=code
    event.physical_keycode=code
    event.window_id=dialog.get_window_id() if dialog.visible and not dialog.is_embedded() else root.get_window_id()
    event.pressed=true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await process_frame
    await process_frame
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await process_frame
    await process_frame

func _buy_map_and_quill() -> void:
    const CARTOGRAPHY=preload("res://scripts/pilgrimage_cartography.gd")
    const SHOP=preload("res://scripts/cartography_runtime.gd")
    var before: int=scene.currency_count
    _check(before>=40 and not CARTOGRAPHY.owned(scene.story_flags,String(scene.config.id)) and not CARTOGRAPHY.has_quill(scene.story_flags),"earned route income funds the previously missed map and quill")
    await _world_interact()
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    _check(dialog.visible and dialog.get_ok_button().has_focus(),"F opens seller with an affordable map selected")
    await _key(KEY_ENTER,dialog)
    await _tick(4)
    _check(CARTOGRAPHY.owned(scene.story_flags,String(scene.config.id)) and scene.currency_count==before-30,"Enter buys the canal map at its real price")
    if CARTOGRAPHY.owned(scene.story_flags,String(scene.config.id)) and scene.currency_count==before-30:purchases+=1
    await _world_interact()
    var quill: Button=dialog.find_child("MapSellerQuill",true,false)
    for attempt in 12:
        if quill.has_focus():break
        await _key(KEY_TAB,dialog)
    _check(quill.has_focus(),"Tab navigation reaches the affordable quill button")
    await _key(KEY_ENTER,dialog)
    await _tick(4)
    _check(CARTOGRAPHY.has_quill(scene.story_flags) and scene.currency_count==before-40,"Enter buys the quill with earned currency")
    if CARTOGRAPHY.has_quill(scene.story_flags) and scene.currency_count==before-40:purchases+=1
    _check(not SHOP.owns_tool(scene,"compass"),"route has not granted or bought a compass")
    print("DAMAGE_ROUTE_PURCHASE wallet_before=%d wallet_after=%d navigation_assist=%s" % [before,scene.currency_count,str(scene.ui_shell.get_accessibility("navigation_assist",false))])
    await _key(KEY_ESCAPE,dialog)
    await _tick(6)
    _check(String(scene.active_overlay).is_empty(),"Escape returns from seller to normal exploration")
    if failures>0:
        quit(1)
        await process_frame

func _inspect_map_without_position() -> void:
    _release()
    Input.action_press("map")
    await process_frame
    await _tick(3)
    Input.action_release("map")
    await process_frame
    _check(scene.active_overlay=="map" and scene.map_panel.visible,"normal map input opens the purchased region")
    _check(scene.map_draw_root.get_node_or_null("SurveyPlayerMarker")==null and scene.map_text.text.contains("无罗盘"),"purchased map renders without a position marker")
    Input.action_press("close_overlay")
    await process_frame
    await _tick(3)
    Input.action_release("close_overlay")
    await process_frame
    _check(scene.active_overlay.is_empty() and not scene.player.ui_input_locked,"normal close input returns to exploration")

func _verify_process_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(OS.get_process_id()!=int(proof.get("pid",-1)),"restart uses a different engine process")
    _check(String(scene.config.id)==String(proof.region) and String(scene.active_save_point_id)==String(proof.checkpoint),"fresh engine process restores the actual rested region and checkpoint")
    _check(scene.player.position.distance_to(Vector2(2990,1200))<90,"fresh process resumes at the rested aqueduct shrine")
    _check(scene.currency_count==int(proof.wallet),"fresh process restores the exact earned wallet after payment")
    _check(_inventory_matches(scene.inventory_counts,proof.inventory),"fresh process restores every earned item count")
    _check(JOURNAL.owned(scene.story_flags,String(proof.region)) and JOURNAL.has_quill(scene.story_flags),"fresh process restores the paid canal map and quill")
    var charted: Dictionary=JOURNAL.region(scene.story_flags,String(proof.region)).charted
    var retained: bool=not proof.charted.is_empty()
    for key in proof.charted:
        retained=retained and bool(charted.get(key,false))
    _check(retained,"fresh process retains all charted travel notes")
    _check(bool(scene.story_flags.get("world_shortcut_salt_return",false)),"fresh process restores the unlocked salt return shortcut")
    _check(not SHOP_RUNTIME.owns_tool(scene,"compass") and not SHOP_RUNTIME.shows_position(scene),"fresh process has no unearned compass or position assist")
    await _inspect_map_without_position()
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    print("WORLD_DAMAGE_ROUTE_PROCESS_RESTART failures=%d pid=%d" % [failures,OS.get_process_id()])
    quit(0 if failures==0 else 1)

func _inventory_matches(actual: Dictionary, serialized: Dictionary) -> bool:
    # JSON decodes numeric counts as floats. Compare every key and exact value
    # without weakening the check through truncation or adding missing items.
    if actual.size()!=serialized.size():return false
    for key in actual:
        if not serialized.has(key) or typeof(serialized[key]) not in [TYPE_INT,TYPE_FLOAT]:return false
        if actual[key]!=serialized[key]:return false
    return true
