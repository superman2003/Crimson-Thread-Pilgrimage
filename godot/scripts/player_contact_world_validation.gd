extends SceneTree
## Exact public camp, normal Input whiff then paid cleave versus the real bellwheel.
## No player/enemy position, HP, ability, damage suppression or cooldown writes.
const SAVE:="user://test_v04_contact_world_20261024.json"
const SEED:="res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
const RETIREMENT:=preload("res://scripts/audio_retirement.gd")
const AUDIO:=preload("res://scripts/audio_director.gd")
var scene:Node2D
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
    if not ok:failures+=1;push_error("CONTACT_WORLD: "+label)
func frames(n:int=1) -> void:
    for i in n:await physics_frame;await process_frame
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native capture")
func blades() -> Array:return get_nodes_in_group(POLICY.ACTION_TRACE_GROUP).filter(func(n):return n.has_meta("delivered_blade_art") and not n.is_queued_for_deletion())
func slashes() -> Array:return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("delivered_skill_art") and not n.is_queued_for_deletion())
func marks(receiver:Node) -> Array:return get_nodes_in_group(POLICY.CONTACT_GROUP).filter(func(n):return n.has_meta("delivered_contact_art") and not n.is_queued_for_deletion() and int(n.get_meta("receiver_id",0))==receiver.get_instance_id())
func axis(direction:float) -> void:
    Input.action_release("move_left");Input.action_release("move_right")
    if direction!=0:Input.action_press("move_right" if direction>0 else "move_left")
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    var bytes:=FileAccess.get_file_as_bytes(SEED);var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
    check(hash.finish().hex_encode()=="91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b","public exact earned camp bytes")
    var file:=FileAccess.open(SAVE,FileAccess.WRITE);file.store_buffer(bytes);file.close();scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=SAVE;root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene);current_scene=scene;await frames(15)
    check(scene.player.hp==5 and scene.player.max_hp==6 and scene.player.energy==100 and scene.currency_count==287 and not scene.player.dash_unlocked and not scene.player.debug_invulnerable,"original stockHP5/max6, energy100/wallet287 and real damage")
    axis(1);await frames(45);axis(-1);await frames(2);axis(0)
    Input.action_press("attack");await frames(3);Input.action_release("attack")
    for i in 20:
        if not blades().is_empty():break
        await frames()
    check(blades().size()==1,"normal World J whiff owns measured-weapon material")
    print("CONTACT_WORLD_BLADE pos=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy," wallet=",scene.currency_count)
    await capture("world_measured_blade");await frames(35)
    var enemy:Node2D
    for node in get_nodes_in_group("enemy"):
        if node.get_parent()==scene and node.spawn_id=="E07":enemy=node;break
    check(enemy!=null,"actual authored bellwheel is resident")
    if enemy==null:await finish();return
    var hp_before:int=enemy.hp;var paid:=false;var hit:=false
    for i in 650:
        var dx:float=enemy.position.x-scene.player.position.x
        var dy:float=enemy.position.y-(scene.player.position.y-42)
        axis(signf(dx) if absf(dx)>80 else 0)
        if not paid and absf(dx)<115 and absf(dy)<65 and scene.player.attack_timer<=0 and scene.player.hurt_timer<=0 and scene.player.get_cast_readiness().get("available",false):
            var energy:int=scene.player.energy;var cost:int=scene.build_system.selected_skill().energy_cost
            Input.action_press("skill_1");await frames(3);Input.action_release("skill_1");paid=String(scene.player.active_skill.get("id",""))=="cleave"
            check(paid and scene.player.energy==energy-cost,"actual paid World cleave preserves production cost before hit")
            print("CONTACT_WORLD_PAID pos=",scene.player.position," energy=",scene.player.energy," cost=",cost," target=",enemy.position)
        await frames()
        if i%60==0:print("CONTACT_WORLD_APPROACH pos=",scene.player.position," hp=",scene.player.hp," foe=",enemy.position," foe_hp=",enemy.hp)
        if enemy.hp<hp_before:
            hit=true;axis(0)
            check(paid and slashes().size()==1 and marks(enemy).size()==1 and marks(enemy)[0].refined,"real accepted World cleave has specific slash and one exact correlated hit")
            print("CONTACT_WORLD_ACCEPTED pos=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy," foe_hp=",enemy.hp," wallet=",scene.currency_count," mark_count=",marks(enemy).size())
            await capture("world_paid_cleave_contact");await frames(2);await capture("world_contact_followthrough");break
        if scene.player.hp<=0:break
    axis(0);check(hit,"normal Input reaches actual accepted bellwheel hit")
    await frames(35);check(blades().is_empty() and slashes().is_empty(),"World action traces naturally retire")
    await finish()
func finish() -> void:
    axis(0);Input.action_release("attack");Input.action_release("skill_1");RETIREMENT.retire_tree(scene);scene.queue_free();scene=null
    for i in 8:await process_frame
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear();check(await RETIREMENT.drain(self),"observable World audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("PLAYER_CONTACT_WORLD failures=%d input_only=true direct_damage=false"%failures);quit(1 if failures else 0)
