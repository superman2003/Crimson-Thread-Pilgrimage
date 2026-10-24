extends "res://scripts/player_dash_art_validation.gd"
## Positioned real Player/EnemyActor fixture; all casts use Input. No natural-route claim.
const HOOK:=preload("res://scripts/player_hook_art.gd")
func hookwork(kind:String="") -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_hook_art") and not n.is_queued_for_deletion() and (kind.is_empty() or n.kind==kind))
func hook_setup(crest:String="crimson",direction:int=1) -> void:
    Input.action_release("hook");Input.action_release("aim_up");await setup(crest,direction);player.thread_grapple_unlocked=true
func pulse_hook() -> void:
    Input.action_press("hook");await frames();Input.action_release("hook")
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540);stage=Node2D.new();root.add_child(stage)
    var bg:=Polygon2D.new();bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]);bg.color=Color("18242b");stage.add_child(bg)
    var floor_body:=StaticBody2D.new();floor_body.position=Vector2(480,380);var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(2000,40);shape.shape=box;floor_body.add_child(shape);stage.add_child(floor_body)
    player=load("res://scenes/Player.tscn").instantiate()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dash-player-script="):player.set_script(load(arg.trim_prefix("--dash-player-script=")))
    stage.add_child(player);player.feel=null
    for child in player.get_children():
        if child is Camera2D:child.enabled=false
    build=BUILD.new();build.state.unlocked_crests=build.catalog.crests.keys();player.build_system=build;await frames(4)
    check(HOOK.ATLAS.get_size()==Vector2(1152,576),"one bounded atlas with6/4/6 source cels")
    for row in 3:
        var distinct:={}
        for i in (4 if row==1 else 6):
            var im:=HOOK.ATLAS.get_image().get_region(Rect2i(i*192,row*192,192,192));check(not im.is_invisible(),"real authored hook cel");distinct[im.get_data().hex_encode().sha256_text()]=true
        check(distinct.size()==(4 if row==1 else 6),"distinct real family frames")
    var anchor:=Node2D.new();anchor.add_to_group("grapple_anchor");stage.add_child(anchor)
    for crest in ["crimson","bell","salt"]:
        for direction in [-1,1]:
            await hook_setup(crest,direction);anchor.position=Vector2(480+direction*240,250);anchor.visible=true;anchor.set_meta("grapple_enabled",true)
            var hp:int=player.hp;var energy:int=player.energy
            Input.action_press("aim_up");await pulse_hook();Input.action_release("aim_up")
            check(player.grapple_timer>0 and player.grapple_anchor==anchor and is_instance_valid(player.grapple_line),crest+" actual Input acquires real anchor and retains original connection")
            check(hookwork("traversal").size()==1 and hookwork("latch").size()==1,crest+" only valid acquisition creates head/cord and latch")
            if not hookwork("traversal").is_empty():
                check(hookwork("traversal")[0].z_index==59 and hookwork("traversal")[0].get_meta("secondary_units")==1,crest+" original59 layer and one bounded composite motion unit")
            await frames(2);await capture(crest+("_hook_left" if direction<0 else "_hook_right"))
            var timer:float=player.grapple_timer;var pos:Vector2=player.position;paused=true;await frames(3);check(player.grapple_timer==timer and player.position==pos,crest+" pause freezes actual anchor pull");paused=false
            for i in 60:
                if player.grapple_timer<=0:break
                await frames()
            check(player.grapple_recovery_timer>0 and not is_instance_valid(player.grapple_line) and hookwork("traversal").is_empty(),crest+" normal recovery releases active head and cord")
            check(not hookwork("latch").is_empty(),crest+" normal recovery burst belongs to actual reached anchor")
            check(player.hp==hp and player.energy==energy,crest+" hook preserves original resource rules")
            await frames(22);check(hookwork().is_empty(),crest+" hook recovery naturally retires")
    for reason in ["locked","disabled","hidden","behind","far","occluded"]:
        await hook_setup();anchor.position=Vector2(720,250);anchor.visible=reason!="hidden";anchor.set_meta("grapple_enabled",reason!="disabled")
        if reason=="locked":player.thread_grapple_unlocked=false
        if reason=="behind":anchor.position=Vector2(240,318)
        if reason=="far":anchor.position=Vector2(1100,250)
        var wall:StaticBody2D
        if reason=="occluded":
            wall=StaticBody2D.new();wall.position=Vector2(610,250);var s:=CollisionShape2D.new();var b:=RectangleShape2D.new();b.size=Vector2(20,220);s.shape=b;wall.add_child(s);stage.add_child(wall);await frames(3)
        await pulse_hook();await frames(6)
        check(player.grapple_timer<=0 and hookwork("traversal").is_empty() and hookwork("latch").is_empty(),reason+" cannot pretend to acquire/latch; original combat fallback remains valid")
        if wall!=null:wall.queue_free()
    await hook_setup();anchor.visible=false
    var enemy:Area2D=load("res://scripts/enemy_actor.gd").new();enemy.configure({"id":"hook_material_target","hp":20,"kind":"moss_larva"},"",false,{});enemy.position=Vector2(555,320);stage.add_child(enemy);enemy.set_physics_process(false);enemy.contact_timer=1000;await frames(4)
    var before:int=enemy.hp;await pulse_hook()
    for i in 20:
        if enemy.hp<before:break
        await frames()
    check(enemy.hp<before and player.hook_latch_played,"actual hook Input gets production EnemyActor accepted hit")
    check(hookwork("combat").size()==1 and not hookwork("latch").is_empty(),"combat active head/cord and latch require actual accepted hit")
    await capture("actual_hook_accepted_hit");enemy.queue_free();await frames(30)
    await hook_setup();anchor.visible=true;anchor.position=Vector2(720,250);player.set_meta("accessibility",{"flash_enabled":false});await pulse_hook()
    check(hookwork().size()==2 and hookwork().all(func(n):return n.frame==3 and n.opacity<=.35),"low-flash active and latch bounded from creation")
    await capture("reduced_hook_first");player._reset_traversal_state();check(hookwork().is_empty(),"reset removes anchored latch and body cosmetics without replay")
    for reason in ["damage","death","jump","anchor_exit","dash"]:
        await hook_setup();anchor.position=Vector2(720,250);await pulse_hook()
        if reason=="damage" or reason=="death":player.take_damage(player.max_hp+5 if reason=="death" else 1,player.position+Vector2(80,0),false)
        elif reason=="jump":Input.action_press("jump");await frames();Input.action_release("jump")
        elif reason=="dash":await dash()
        else:anchor.visible=false;anchor.queue_free();await frames();anchor=Node2D.new();stage.add_child(anchor);anchor.add_to_group("grapple_anchor")
        await frames(2);check(player.grapple_timer<=0 and hookwork("traversal").is_empty(),reason+" retires active material without changing stop rules")
    await hook_setup();anchor.visible=true;anchor.position=Vector2(890,250);player.grapple_timeout=.05
    await pulse_hook();await frames(15)
    check(player.grapple_timer<=0 and hookwork("traversal").is_empty(),"real short-timeout fixture retires active cable")
    await frames(12);check(hookwork().is_empty(),"timeout cannot leave or repeat an arrival latch")
    player.grapple_timeout=.60
    await hook_setup();anchor.visible=true;anchor.position=Vector2(720,250);var fillers:Array[Node2D]=[]
    for i in 12:
        var node:=Node2D.new()
        if POLICY.attach_secondary(stage,node,&"motion",stage):fillers.append(node)
    await pulse_hook();check(player.grapple_timer>0 and is_instance_valid(player.grapple_line) and hookwork().is_empty(),"full cosmetic budget cannot reject actual grapple or hide original line")
    for node in fillers:node.queue_free()
    RETIREMENT.retire_tree(stage);stage.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear();check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"exit releases all motion material");check(await RETIREMENT.drain(self),"observable audio retirement")
    print("PLAYER_HOOK_ART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
