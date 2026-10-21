extends SceneTree
const HISTORY := preload("res://scripts/scene_history.gd")
const STATE := preload("res://scripts/world_state.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const SAVE := "user://scene_history_validation.json"
var failures := 0
var checks := 0
var scene: Node
var capture_dir := OS.get_environment("SCENE_HISTORY_CAPTURE_DIR")
var initial_orphans := 0

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error("SCENE_HISTORY: "+label)

func frames(count: int=2) -> void:
    for unused in count:await process_frame

func freeze_actors() -> void:
    scene.set_process(false)
    scene.player.set_physics_process(false)
    scene.player.collision_layer=0
    scene.player.debug_invulnerable=true
    for child in scene.get_children():
        if child is Area2D and String(child.name).begins_with("col_"):child.monitoring=false
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)

func focus(prop: Area2D) -> void:
    scene._close_overlays()
    scene.player.global_position=prop.global_position
    scene.player.velocity=Vector2.ZERO
    scene.set_process(true)
    await frames(6)
    scene.set_process(false)
    check(prop.visible,"entered artifact room reveals its physical object")
    check(scene.interaction_target()==prop,"real interaction selector chooses the reached artifact")

func read(prop: Area2D) -> void:
    var inventory_before: Dictionary=scene.inventory_counts.duplicate(true)
    var wallet_before: int=scene.currency_count
    scene._try_interact()
    check(scene.active_overlay=="dialogue" and scene.ui_shell.dialogue_area==prop,"F opens the artifact in the real readable overlay")
    check(scene.ui_shell.dialogue_continue_button.text=="记入旅记" and not scene.ui_shell.dialogue_route_button.visible and not scene.ui_shell.dialogue_quest_button.visible,"inanimate object offers reading rather than NPC topics")
    scene.ui_shell.dialogue_continue_button.grab_focus()
    check(scene.ui_shell.dialogue_continue_button.has_focus(),"observation confirm is a real focusable control")
    scene._try_interact()
    scene._try_interact()
    check(scene.active_overlay.is_empty() and HISTORY.discovered(scene.story_flags,String(prop.entry.id)),"complete reading and explicit confirmation records the observation")
    check(scene.inventory_counts==inventory_before and scene.currency_count==wallet_before,"the actual observation transaction grants no items or money")

func photograph(prop: Area2D) -> void:
    if capture_dir.is_empty() or DisplayServer.get_name()=="headless":return
    var camera: Camera2D=scene.player.get_node("Camera2D")
    camera.limit_left=-1000000;camera.limit_top=-1000000;camera.limit_right=1000000;camera.limit_bottom=1000000
    camera.position_smoothing_enabled=false
    camera.position=Vector2.ZERO
    camera.offset=Vector2.ZERO
    camera.force_update_scroll()
    scene.ui_shell.visible=false
    scene.player.visible=false
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    var center := prop.get_global_transform_with_canvas().origin
    var rect := Rect2i(int(center.x)-130,int(center.y)-108,260,180).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
    image.get_region(rect).save_png(capture_dir+"/"+String(prop.entry.id)+".png")
    scene.ui_shell.visible=true
    scene.player.visible=true

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
    if not capture_dir.is_empty():DirAccess.make_dir_recursive_absolute(capture_dir)
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    var entries := HISTORY.all_entries()
    check(entries.size()==12,"authored twelve distinct facility and witness objects")
    check(HISTORY.records({}).is_empty(),"unknown observation titles and region names are absent from journal")
    check(HISTORY.records({"scene_history_fake":true,HISTORY.FLAG_PREFIX+String(entries[0].id):1}).is_empty(),"unknown and non-boolean flags cannot reveal notes")
    var changed := HISTORY.all_entries()
    changed[0]["text"]="spoof"
    check(String(HISTORY.all_entries()[0].text)!="spoof","catalog callers cannot mutate future observations")
    initial_orphans=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_save_path=SAVE
    scene.world_resume=false
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    freeze_actors()
    var regions: Array=[]
    for entry in entries:
        if not regions.has(entry.region_id):regions.append(entry.region_id)
    var before_progress: Dictionary=scene.world_narrative.evaluate_progress(scene.inventory_counts,scene.story_flags)
    for region in regions:
        var path := "res://data/"+String(region)+".json"
        var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
        scene._travel_world(path,Vector2(config.player_start[0],config.player_start[1]))
        await frames()
        freeze_actors()
        for entry in HISTORY.region_entries(String(region)):
            var prop: Area2D=scene.get_node_or_null(NodePath("History_"+String(entry.id)))
            check(prop!=null,"production region jobs create the authored artifact")
            if prop==null:continue
            check(not prop.has_meta("object_id") and prop.collision_layer==0,"observation is absent from map pins and does not block movement")
            var floor: Dictionary={}
            for platform in scene.config.platforms:
                if String(platform.id)==String(entry.floor_id):floor=platform
            check(not floor.is_empty() and is_equal_approx(prop.position.y+32,float(floor.rect[1])),"physical artwork reaches its authored floor")
            if entry.role=="witness":
                check(prop.visible==(String(scene.current_room_id)==String(entry.room_id)),"witness visibility follows the entered room rather than unseen neighboring rooms")
            await focus(prop)
            if entry.role=="witness":
                var proof: Area2D=scene.get_node_or_null(NodePath("col_"+String(entry.evidence_id)))
                check(proof!=null,"linked original testimony still exists as its own pickup")
                if proof!=null:
                    scene.player.global_position=proof.global_position
                    check(scene.interaction_target()==proof,"new observation never replaces the original testimony pickup at its standing point")
                    scene.player.global_position=prop.global_position
            await photograph(prop)
            if String(entry.id)==String(entries[0].id):
                var first_inventory: Dictionary=scene.inventory_counts.duplicate(true)
                var first_wallet: int=scene.currency_count
                scene._try_interact()
                scene.dialogue_text_label.visible_characters=9
                scene._close_overlays()
                check(not HISTORY.discovered(scene.story_flags,String(entry.id)),"Esc during incomplete reading does not record a note")
                scene._try_interact()
                check(scene.dialogue_text_label.visible_characters==9,"reopening restores the observation's reading bookmark")
                scene._close_overlays()
                scene._try_interact()
                scene._try_interact()
                scene.world_save_failure_injected_for_validation=true
                var saved_before := FileAccess.get_file_as_bytes(SAVE)
                scene._try_interact()
                check(scene.active_overlay=="dialogue" and not prop.seen and not HISTORY.discovered(scene.story_flags,String(entry.id)),"save failure keeps the reader open and rolls back observation state")
                check(FileAccess.get_file_as_bytes(SAVE)==saved_before,"failed observation leaves the disk save unchanged")
                scene.world_save_failure_injected_for_validation=false
                scene._try_interact()
                check(scene.active_overlay.is_empty() and prop.seen,"the same confirmation can retry and commit after write recovery")
                check(scene.inventory_counts==first_inventory and scene.currency_count==first_wallet,"failed and retried observation grants no inventory or currency")
                scene.player.global_position=prop.global_position+Vector2(35,0)
                check(scene.interaction_target()==prop,"unobstructed observation is selectable before wall counterexample")
                var wall := StaticBody2D.new()
                wall.collision_layer=1
                wall.position=prop.position+Vector2(17,0)
                var shape := CollisionShape2D.new()
                var rect := RectangleShape2D.new();rect.size=Vector2(8,80);shape.shape=rect;wall.add_child(shape)
                scene.add_child(wall)
                await physics_frame
                await frames()
                check(not prop.accessible_from(scene.player) and scene.interaction_target()!=prop,"terrain blocks observation across an intervening wall")
                wall.free()
                await frames()
                scene.player.global_position=prop.global_position
            else:
                await read(prop)
            var loaded := STATE.new()
            check(loaded.read(SAVE) and HISTORY.discovered(loaded.data.story_flags,String(entry.id)),"confirmed observation persists through the actual World save")
            scene._toggle_backpack()
            scene.ui_shell.bag_category="旅记"
            scene.ui_shell.refresh_inventory()
            var present := false
            for button in scene.ui_shell.bag_grid.get_children():
                if String(button.text).begins_with(String(entry.title)):
                    button.pressed.emit();present=true;break
            check(present and scene.ui_shell.bag_category_label.text=="环境见闻 · 已观察" and scene.ui_shell.bag_description.text.contains(String(entry.text)),"production journal shows only the observed physical history")
            scene._close_overlays()
    var after: Dictionary=scene.world_narrative.evaluate_progress(scene.inventory_counts,scene.story_flags)
    check(int(after.evidence_count)==int(before_progress.evidence_count) and not after.evidence_complete,"physical observations do not replace any original testimony or ending requirement")
    check(HISTORY.records(scene.story_flags).size()==12,"all twelve observations remain unique across region visits")
    var first: Dictionary=entries[0]
    var first_config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+String(first.region_id)+".json"))
    scene._travel_world("res://data/"+String(first.region_id)+".json",Vector2(first_config.player_start[0],first_config.player_start[1]))
    await frames();freeze_actors()
    var returned: Area2D=scene.get_node("History_"+String(first.id))
    check(returned.seen,"revisiting rebuilds the recorded object's visible notch from saved flags")
    await focus(returned)
    await read(returned)
    check(HISTORY.records(scene.story_flags).size()==12,"rereading cannot duplicate journal entries")
    # Capture owned playback before bottom-up tree exit detaches child players.
    scene._toggle_backpack()
    scene.ui_shell.bag_category="旅记"
    scene.ui_shell.refresh_inventory()
    check(String(scene.ui_shell.bag_grid.get_child(0).text).contains("主线"),"main progress stays first even after all environment notes are recorded")
    var filters: Variant=scene.ui_shell.get("journal_filter_buttons")
    if filters is Dictionary and filters.has("enemy"):
        var history_keys: Array[String]=[]
        for entry in entries:history_keys.append("evidence:"+HISTORY.FLAG_PREFIX+String(entry.id))
        var displayed_keys: Array[String]=[]
        for button in scene.ui_shell.bag_grid.get_children():displayed_keys.append(String(button.get_meta("journal_key","")))
        check(history_keys.all(func(key):return displayed_keys.has(key)),"all filter preserves all twelve environment records under evidence identities")
        filters.enemy.pressed.emit()
        check(scene.ui_shell.bag_grid.get_child_count()==0,"enemy filter does not include environment notes")
        filters.evidence.pressed.emit()
        var note_found := false
        for button in scene.ui_shell.bag_grid.get_children():
            if String(button.text).begins_with(String(first.title)):note_found=true
        check(note_found,"evidence filter includes reached physical observations")
        for filter_id in ["main","quest","ending"]:
            filters[filter_id].pressed.emit()
            var history_visible := false
            for button in scene.ui_shell.bag_grid.get_children():
                if history_keys.has(String(button.get_meta("journal_key",""))):history_visible=true
            check(not history_visible,"%s filter excludes environment evidence notes" % filter_id)
        filters.evidence.pressed.emit()
        await frames(1)
        var remembered: Dictionary=entries.back()
        var remembered_key := "evidence:"+HISTORY.FLAG_PREFIX+String(remembered.id)
        for button in scene.ui_shell.bag_grid.get_children():
            if String(button.get_meta("journal_key",""))==remembered_key:button.grab_focus()
        check(scene.ui_shell.bag_name.text==String(remembered.title) and scene.ui_shell.journal_memory.get("evidence","")==remembered_key,"observation selection stores record_kind:id rather than its title or row")
        filters.main.pressed.emit()
        filters.evidence.pressed.emit()
        await frames(1)
        check(scene.ui_shell.bag_name.text==String(remembered.title) and String(scene.ui_shell.bag_grid.get_child(scene.ui_shell.journal_selection).get_meta("journal_key",""))==remembered_key,"returning to evidence restores the selected environment note by identity")
        scene._close_overlays()
        scene._toggle_backpack()
        scene.ui_shell.bag_category="旅记"
        scene.ui_shell.refresh_inventory()
        check(scene.ui_shell.bag_name.text==String(remembered.title),"closing and reopening the journal preserves the evidence observation selection")
        filters.all.pressed.emit()
        print("SCENE_HISTORY_FILTER_INTEGRATION checks=9")
    scene._close_overlays()
    scene._release_region_audio()
    scene.queue_free()
    for node in root.get_children():
        if node is AudioStreamPlayer and String(node.name).begins_with("PersistentSfx_"):RETIRE.retire_tree(node);node.queue_free()
    await frames()
    check(await RETIRE.drain(self,3000),"history fixture releases scene audio playback")
    check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))<=initial_orphans,"rapid close-and-travel leaves no unattached audio nodes")
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("SCENE_HISTORY_VALIDATION checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
