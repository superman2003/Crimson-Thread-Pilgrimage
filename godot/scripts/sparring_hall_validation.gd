extends SceneTree
const POLICY := preload("res://scripts/sparring_policy.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func run() -> void:
    var bouts:=POLICY.bouts()
    check(bouts.size()==12,"six regional wave bouts and six boss rematches")
    for bout in bouts:
        var source:=POLICY.sources(bout)
        for wave in bout.waves:
            check(wave.size() in [1,2],"bounded wave actor budget")
            for id in wave:check(source.actors.has(id),"every opponent resolves to actual production data")
    var main: Node=load("res://scenes/World.tscn").instantiate();main.world_resume=false;main.world_save_path="user://sparring_hall_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    check(POLICY.available(main).is_empty(),"unmet enemies and bosses are hidden")
    var bout: Dictionary=bouts[0];var source:=POLICY.sources(bout)
    for wave in bout.waves:
        for id in wave:main.story_flags["journal_enemy_"+String(source.actors[id].kind)]=true
    for child in main.get_children():
        if child is Area2D and child.get_meta("kind","")=="save_point":main.player.global_position=child.global_position;break
    await physics_frame;await physics_frame;await process_frame
    main._toggle_build();await process_frame
    var desk: Node=main.ui_shell.get_node("SparringDesk")
    main.ui_shell.build_panel.get_node("SparringButton").pressed.emit();await process_frame
    check(desk.window.visible and desk.rows.size()==1,"real selector exposes only a known regional bout")
    desk.ask();check(not desk.pending.is_empty() and desk.confirm.visible,"native confirmation prepares an explicit bout")
    var counts: Dictionary=main.inventory_counts.duplicate(true);var flags: Dictionary=main.story_flags.duplicate(true);var build: Dictionary=main.build_system.serialize();var disk:=FileAccess.get_file_as_bytes(main.world_save_path)
    var hp: int=main.player.hp;var energy: int=main.player.energy;var live: CharacterBody2D=main.player
    desk.start();await process_frame
    var arena: Node=desk.arena
    check(is_instance_valid(arena) and arena.wave==1 and arena.alive.size()==1,"actual arena starts a live configured enemy")
    check(main.process_mode==Node.PROCESS_MODE_DISABLED and not main.visible and not live.is_in_group("player"),"journey is suspended and its actor excluded from practice combat")
    check(arena.player!=live and arena.player.build_system!=main.build_system,"practice fighter and build share no mutable journey model")
    check(arena.alive[0].get_script()==preload("res://scripts/enemy_actor.gd") and arena.alive[0].ai_commands.size()>0,"opponent uses real production AI and move data")
    var first: Area2D=arena.alive[0]
    arena.player.debug_invulnerable=true;arena.player.global_position=arena.ORIGIN+Vector2(50,0)
    var attack_seen:=false
    for tick in range(150):
        await physics_frame
        if first.state in ["windup","active"]:attack_seen=true
    check(attack_seen,"production AI actually begins attacks against the cloned fighter")
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/f03-arena.png")
    first.take_hit(999,1);await process_frame;await process_frame
    check(arena.wave==2 and arena.alive.size()==2,"real death signal advances from single to double enemy wave")
    for actor in arena.alive.duplicate():actor.take_hit(999,1)
    await process_frame;await process_frame
    check(arena.finished and arena.record.complete,"last real death finishes the bout")
    check(FileAccess.get_file_as_bytes(main.world_save_path)==disk and main.story_flags==flags,"active practice writes no checkpoint or objective")
    arena.close();await process_frame
    check(main.process_mode!=Node.PROCESS_MODE_DISABLED and main.visible and live.is_in_group("player"),"return restores processing visibility and player membership")
    check(main.inventory_counts==counts and main.story_flags==flags and main.build_system.serialize()==build and live.hp==hp and live.energy==energy,"success unchanged counts=%s flags=%s build=%s hp=%d/%d energy=%d/%d" % [main.inventory_counts==counts,main.story_flags==flags,main.build_system.serialize()==build,live.hp,hp,live.energy,energy])
    check(FileAccess.get_file_as_bytes(main.world_save_path)==disk,"practice disk exact before=%d after=%d" % [disk.size(),FileAccess.get_file_as_bytes(main.world_save_path).size()])
    check(desk.history[0].complete,"separate bounded review history records the result")
    main._toggle_build();await process_frame;desk.open();desk.ask();desk.start();await process_frame
    arena=desk.arena;arena.player.hp=0;arena._process(0.1)
    check(arena.finished and not arena.record.complete,"defeat ends practice without a real-world death")
    arena.close();await process_frame
    check(live.hp==hp and main.story_flags==flags and main.inventory_counts==counts,"failed practice preserves original resources and objectives")
    main._close_overlays();var audio:=preload("res://scripts/audio_retirement.gd");audio.retire_tree(main);main.free();await process_frame
    check(await audio.drain(self),"all arena and journey audio retires")
    for failure in failures:push_error(failure)
    print("SPARRING_HALL checks=%d failures=%d" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
