extends SceneTree
## Production complete-body idle: real clock, sole support, shader and GL pixels.
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _should_play_sfx() -> bool: return false

const ART := "res://assets/sprites/player/thread_doll_v1/frames/"
var checks := 0
var failures := 0
var player
var sprite: AnimatedSprite2D
var view: SubViewport
var reference: Sprite2D
var background: Polygon2D
var pixel_cases := 0
var largest_pixel_error := 0
var largest_idle_support_drift := 0.0
var largest_handoff_drift := 0.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error("IDLE_MOTION: "+label)
func frames(count: int) -> void:
    for index in count: await process_frame
func soles(image: Image) -> Vector2:
    var positions: Array[float] = []
    for limits in [[0,185],[185,384]]:
        var sum := 0.0
        var count := 0
        for y in range(276,282):
            for x in range(limits[0],limits[1]):
                if roundi(image.get_pixel(x,y).a*255)>128:
                    sum += x; count += 1
        check(count>0,"both boots have actual support pixels")
        positions.append(sum/maxi(1,count))
    return Vector2(positions[0],positions[1])

func support_world(centers: Vector2) -> Vector2:
    var sign_x := -1.0 if sprite.flip_h else 1.0
    return ((centers-Vector2.ONE*192)*sign_x+Vector2.ONE*sprite.offset.x)*sprite.scale.x

func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Real GL is required for complete body idle pixels")
        quit(1); return
    view = SubViewport.new(); view.size=Vector2i(640,360)
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
    var stage := Node2D.new(); view.add_child(stage)
    background=Polygon2D.new()
    background.polygon=PackedVector2Array([Vector2.ZERO,Vector2(640,0),Vector2(640,360),Vector2(0,360)])
    background.color=Color("19232a"); stage.add_child(background)
    var floor_body := StaticBody2D.new(); floor_body.position=Vector2(320,340)
    var collision := CollisionShape2D.new(); var box := RectangleShape2D.new()
    box.size=Vector2(640,20); collision.shape=box; floor_body.add_child(collision); stage.add_child(floor_body)
    player=load("res://scenes/Player.tscn").instantiate(); player.set_script(QuietPlayer)
    player.position=Vector2(160,330); player.get_node("Camera2D").enabled=false; stage.add_child(player)
    player.feel=null
    for index in 6: await physics_frame; await process_frame
    player.set_physics_process(false); sprite=player.sprite
    check(player.is_on_floor(),"heavy fixture has actual floor contact")
    check(not player.use_layered_idle and player.layered_idle==null and sprite.get_child_count()==0,"complete body loop has no rigid support or separate cloth overlay")
    check(sprite.sprite_frames.get_frame_count(&"idle")==8 and sprite.sprite_frames.get_animation_speed(&"idle")==5,"eight real cels form a 1.6-second idle cycle")
    var unique: Dictionary = {}
    var contacts: Array[Vector2] = []
    for index in sprite.sprite_frames.get_frame_count(&"idle"):
        var texture := sprite.sprite_frames.get_frame_texture(&"idle",index)
        check(texture.resource_path==ART+"idle_%02d.png"%index,"idle uses its own authored full body cel")
        var image := texture.get_image()
        check(image.get_used_rect().has_area(),"idle body has imported pixels")
        unique[image.get_data().hex_encode().sha256_text()]=true
        contacts.append(soles(image))
    check(unique.size()==8,"all eight complete drawings are distinct")
    for facing in [1,-1]:
        player.facing=facing; sprite.flip_h=facing<0
        player._pose_progress(&"idle",0)
        var baseline := support_world(contacts[0])
        for index in contacts.size():
            player._pose_progress(&"idle",float(index)/8)
            var actual := support_world(contacts[index])
            var drift := maxf(absf(actual.x-baseline.x),absf(actual.y-baseline.y))
            largest_idle_support_drift=maxf(largest_idle_support_drift,drift)
            check(drift<=0.75,"both idle boots stay planted in world pixels")
            check(sprite.material==player.flash_material and sprite.self_modulate.a==1,"authored body retains its original material and opacity")
    player.facing=1; sprite.flip_h=false; player._play(&"idle",true)
    var seen: Dictionary = {}; var wraps := 0; var previous := sprite.frame
    for index in 205:
        await process_frame
        seen[sprite.frame]=true
        if sprite.frame<previous: wraps+=1
        previous=sprite.frame
    check(seen.size()==8 and wraps==2,"real AnimatedSprite clock visits every cel over two full loops")
    sprite.pause(); var paused_phase := Vector2(sprite.frame,sprite.frame_progress)
    await frames(8)
    check(Vector2(sprite.frame,sprite.frame_progress).is_equal_approx(paused_phase),"Sprite pause preserves the current breathing phase")
    player._play(&"idle",true); sprite.speed_scale=0.5
    await frames(24)
    check(absf(float(sprite.frame)+sprite.frame_progress-1.0)<0.12,"speed scale changes the native idle clock without an independent cloth timer")
    paused_phase=Vector2(sprite.frame,sprite.frame_progress)
    self.paused=true; await frames(8)
    check(Vector2(sprite.frame,sprite.frame_progress).is_equal_approx(paused_phase),"SceneTree pause freezes the whole body breathing phase")
    self.paused=false; sprite.speed_scale=1
    for action in [&"run",&"attack_1",&"heal",&"hurt",&"dash",&"death",&"idle"]:
        player._play(action,true)
        check(sprite.animation==action and sprite.material==player.flash_material and sprite.self_modulate.a==1,"action transition never leaves an invisible or duplicated idle body")
    # Heavy attack consumes the existing 0.48-second controller window.
    for facing in [1,-1]:
        player._reset_traversal_state(); player.facing=facing; sprite.flip_h=facing<0
        player._pose_progress(&"idle",0); var baseline := support_world(contacts[0])
        player._start_attack(&"attack_2",false,Vector2(facing,0))
        check(is_equal_approx(player.attack_duration,0.48) and is_equal_approx(player.attack_windup,0.1) and is_equal_approx(player.attack_active_time,0.2496),"new heavy art preserves every original phase clock")
        var previous_time := 0.0
        for point in [[0.0,0],[0.075,1],[0.15,2],[0.29,3],[0.37,4],[0.45,5]]:
            player._update_attack(float(point[0])-previous_time); previous_time=float(point[0])
            player._update_animation(0)
            check(sprite.animation==&"attack_2" and sprite.frame==int(point[1]),"actual grounded heavy reaches both drawings in each existing phase")
            if sprite.frame in [0,5]:
                var actual := support_world(soles(sprite.sprite_frames.get_frame_texture(&"attack_2",sprite.frame).get_image()))
                var drift := maxf(absf(actual.x-baseline.x),absf(actual.y-baseline.y))
                largest_handoff_drift=maxf(largest_handoff_drift,drift)
                check(drift<=2.0,"drawn anticipation and settle return both boots close to idle support")
        player._reset_traversal_state()
    reference=Sprite2D.new(); stage.add_child(reference)
    var expected_material := ShaderMaterial.new(); expected_material.shader=load("res://shaders/hit_flash.gdshader")
    reference.material=expected_material; reference.scale=sprite.scale
    reference.texture_filter=sprite.texture_filter
    for light in [false,true]:
        background.color=Color("b8b09d") if light else Color("19232a")
        for facing in [1,-1]:
            player.facing=facing; sprite.flip_h=facing<0
            for state in [[0.0,1.0],[0.65,1.0],[0.0,0.35]]:
                player.flash_material.set_shader_parameter("flash_amount",state[0]); player._set_death_visibility(state[1])
                expected_material.set_shader_parameter("flash_amount",state[0]); expected_material.set_shader_parameter("presentation_alpha",state[1])
                for index in 8:
                    player._pose_progress(&"idle",float(index)/8)
                    reference.texture=load(ART+"idle_%02d.png"%index)
                    reference.position=player.position+sprite.position+Vector2(320,0)
                    reference.offset=sprite.offset; reference.flip_h=sprite.flip_h
                    await process_frame; await RenderingServer.frame_post_draw
                    var image := view.get_texture().get_image()
                    var actual := image.get_region(Rect2i(80,180,160,160))
                    var expected := image.get_region(Rect2i(400,180,160,160))
                    var a := actual.get_data(); var b := expected.get_data(); var error := 0
                    for channel in a.size(): error=maxi(error,absi(int(a[channel])-int(b[channel])))
                    largest_pixel_error=maxi(largest_pixel_error,error); pixel_cases+=1
                    check(error<=1,"every body pixel matches its independent source draw, including flash/fade and facing")
                    if float(state[0])==0.0 and float(state[1])==1.0:
                        var visible_pixels := 0
                        for y in 160:
                            for x in 160:
                                var c := actual.get_pixel(x,y)
                                if absf(c.r-background.color.r)+absf(c.g-background.color.g)+absf(c.b-background.color.b)>0.15: visible_pixels+=1
                        check(visible_pixels>800,"whole body remains visible at native game size on both backgrounds")
    var result := {"checks":checks,"failures":failures,"pixel_cases":pixel_cases,
        "maximum_pixel_error":largest_pixel_error,"maximum_idle_boot_drift_world_px":largest_idle_support_drift,
        "maximum_heavy_handoff_drift_world_px":largest_handoff_drift}
    var output := ProjectSettings.globalize_path("res://../artifacts/thread_doll_v1")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("idle-pixels.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
    view.queue_free(); await process_frame; await process_frame
    print("PLAYER_IDLE_MOTION checks=%d failures=%d pixels_complete=true"%[checks,failures])
    quit(0 if failures==0 else 1)
