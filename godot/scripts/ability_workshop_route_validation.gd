extends RefCounted
## Production Player controls on the authored route; no in-room relocation.
var world: Node
var tree: SceneTree
var check: Callable
var observed: Dictionary = {}
func release() -> void:
    for action in ["move_left","move_right","jump","hook","aim_up","aim_down"]:
        Input.action_release(action)
func axis(value: float) -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    if value!=0: Input.action_press("move_right" if value>0 else "move_left")
func tick(count: int = 1) -> void:
    for frame in count:
        for enemy in tree.get_nodes_in_group("enemy"): enemy.queue_free()
        await tree.physics_frame
        await tree.process_frame
func record(ability: String, _point: Vector2, _direction: Vector2) -> void:
    observed[ability]=int(observed.get(ability,0))+1
func walk(point: Vector2) -> bool:
    release()
    for frame in 180:
        var dx: float=point.x-world.player.global_position.x
        axis(signf(dx) if absf(dx)>4 else 0)
        await tick()
        if absf(dx)<=4 and world.player.is_on_floor() and absf(world.player.global_position.y-point.y)<5:
            release()
            await tick(3)
            return true
    release()
    return false
func jump(point: Vector2, action: String) -> bool:
    release()
    await tick(4)
    if not world.player.is_on_floor(): return false
    Input.action_press("jump")
    var wall_jumps := 0
    var release_at := 24 if action=="wall_jump" else 12 if action=="double_jump" else 18
    for frame in 200:
        var dx: float=point.x-world.player.global_position.x
        axis(1.0 if action=="wall_jump" and wall_jumps==0 else signf(dx) if absf(dx)>4 else 0)
        if frame==release_at: Input.action_release("jump")
        if action=="double_jump" and frame==15:
            Input.action_press("jump")
            release_at=38
        if action=="wall_jump" and world.player.wall_sliding and frame>release_at and not Input.is_action_pressed("jump") and wall_jumps<4:
            Input.action_press("jump")
            wall_jumps+=1
            release_at=frame+22
        await tick()
        if frame>5 and world.player.is_on_floor() and absf(world.player.global_position.x-point.x)<18 and absf(world.player.global_position.y-point.y)<5:
            release()
            await tick(3)
            return true
    release()
    return false
func hook(point: Vector2) -> bool:
    release()
    axis(1.0)
    await tick(1)
    axis(0)
    Input.action_press("aim_up")
    Input.action_press("hook")
    await tick(2)
    Input.action_release("hook")
    Input.action_release("aim_up")
    for frame in 120:
        if world.player.grapple_timer<=0:
            var dx: float=point.x-world.player.global_position.x
            axis(signf(dx) if absf(dx)>4 else 0)
        await tick()
        if world.player.is_on_floor() and absf(world.player.global_position.x-point.x)<22 and absf(world.player.global_position.y-point.y)<5:
            release()
            return true
    release()
    return false
func run(host: Node, scene_tree: SceneTree, room: Dictionary, callback: Callable) -> bool:
    world=host
    tree=scene_tree
    check=callback
    observed.clear()
    var listener := Callable(self,"record")
    world.player.ability_action.connect(listener)
    check.call(not world.player.double_jump_unlocked or String(room.id).contains("double_thread_jump"),String(room.id)+": no unrelated double-jump assistance")
    check.call(room.get("route_steps",[]).size()>=2,String(room.id)+": route has multiple authored movement goals")
    var ok: bool = room.get("route_steps",[]).size()>=2
    for step in room.get("route_steps",[]):
        var point := Vector2(step.position[0],step.position[1])
        var reached := false
        match String(step.action):
            "walk": reached=await walk(point)
            "jump","double_jump","wall_jump": reached=await jump(point,String(step.action))
            "hook": reached=await hook(point)
        check.call(reached,String(room.id)+": actual "+String(step.action)+" reaches "+str(point))
        if not reached:
            print("WORKSHOP_ROUTE_FAIL room=",room.id," step=",step," position=",world.player.global_position," velocity=",world.player.velocity," floor=",world.player.is_on_floor()," wall=",world.player.is_on_wall()," observed=",observed)
            ok=false
            break
    var ability := "silk_wall_grip" if String(room.id).contains("silk_wall_grip") else "double_thread_jump" if String(room.id).contains("double_thread_jump") else "echo_hook" if String(room.id).contains("echo_hook") else ""
    if not ability.is_empty():
        check.call(int(observed.get(ability,0))>0,String(room.id)+": route uses its actual ability after gate operation")
    world.player.ability_action.disconnect(listener)
    release()
    if ok and DisplayServer.get_name()!="headless":
        # Batch suite disables automatic rendering; force one real frame per room.
        RenderingServer.force_draw()
        var image: Image=tree.root.get_texture().get_image()
        var output := ProjectSettings.globalize_path("res://../artifacts/"+("workshop_group_two" if room.get("layout_group","")=="movement_group_two" else "workshop_group_one"))
        DirAccess.make_dir_recursive_absolute(output)
        check.call(image.save_webp(output.path_join(String(room.id)+"_"+String(world.config.id)+".webp"))==OK,String(room.id)+": actual route arrival capture saved")
    print("WORKSHOP_ROUTE room=",room.id," region=",world.config.id," passed=",ok," actions=",observed)
    return ok
