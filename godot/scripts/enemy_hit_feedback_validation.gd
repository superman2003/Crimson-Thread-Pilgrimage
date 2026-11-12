extends SceneTree
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0

class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error("ENEMY_HIT_FEEDBACK "+label)

func draw_frame() -> void:
    await process_frame
    await RenderingServer.frame_post_draw

func run() -> void:
    check(DisplayServer.get_name()!="headless","real rendered pixels required")
    if failures:quit(1);return
    root.size=Vector2i(800,600)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color(.04,.05,.06))
    var stage:=Stage.new();root.add_child(stage)
    var roster:=ART.manifest("res://data/original_creature_designs.json")
    var kinds:=0
    for design: Dictionary in roster.designs:
        var actor:=ENEMY.new()
        actor.configure({"id":"feedback_"+String(design.kind),"kind":design.kind,"hp":100},"",bool(design.boss))
        stage.add_child(actor)
        actor.position=Vector2(400,360)
        actor.reset_physics_interpolation()
        actor.set_physics_process(false)
        var before_scale: Vector2=actor.sprite.scale
        var before_position: Vector2=actor.sprite.position
        var before_texture: Texture2D=actor.animated_sprite.sprite_frames.get_frame_texture(actor.animated_sprite.animation,actor.animated_sprite.frame)
        actor.take_hit(1,1)
        actor.animated_sprite.pause()
        check(actor.sprite.scale==before_scale and actor.sprite.position==before_position,String(design.kind)+" hit never resizes or offsets the body")
        check(actor.animated_sprite.sprite_frames.get_frame_texture(actor.animated_sprite.animation,actor.animated_sprite.frame)==before_texture,String(design.kind)+" flash overlays the exact receiving pose")
        actor._update_animation_motion(.03,actor.global_position,"active")
        check(actor.sprite.scale==before_scale and actor.sprite.position==before_position,String(design.kind)+" recovery has no squash or stretch")
        check(actor.hp==99 and actor.flash_timer>0 and actor.knockback_velocity>0,String(design.kind)+" actual damage starts flash and recoil")
        # A stalled physics update before presentation must not swallow the hit.
        actor.knockback_velocity=0
        actor._tick_timers(.25)
        check(actor.flash_timer==actor.FLASH_TOTAL_TIME,String(design.kind)+" flash survives physics catch-up before first draw")
        # The sampling below expects every pixel where it was drawn; a beating wing
        # is elsewhere by design (its own flash is covered by enemy_wing_flap).
        if actor.wing_flap_active:actor.flash_materials[0].set_shader_parameter("wing_swing",0.0)
        await draw_frame()
        await draw_frame()
        var sprite: AnimatedSprite2D=actor.animated_sprite
        var texture: AtlasTexture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
        var ink:=texture.atlas.get_image().get_region(Rect2i(texture.region))
        var image:=root.get_texture().get_image()
        var sampled:=0
        var white:=0
        for y in range(3,ink.get_height()-3,5):
            for x in range(3,ink.get_width()-3,5):
                if ink.get_pixel(x,y).a<.99 or ink.get_pixel(x-2,y).a<.99 or ink.get_pixel(x+2,y).a<.99 or ink.get_pixel(x,y-2).a<.99 or ink.get_pixel(x,y+2).a<.99:continue
                var local:=texture.margin.position+Vector2(x+.5,y+.5)-texture.get_size()*.5+sprite.offset
                if sprite.flip_h:local.x=-local.x
                var point:=Vector2i(sprite.to_global(local).round())
                if point.x<0 or point.y<0 or point.x>=image.get_width() or point.y>=image.get_height():continue
                var pixel:=image.get_pixelv(point)
                sampled+=1
                if minf(pixel.r,minf(pixel.g,pixel.b))>.93:white+=1
        check(sampled>=10 and float(white)/maxi(1,sampled)>.9,String(design.kind)+" complete opaque body is visibly white (%d/%d)" % [white,sampled])
        actor._tick_timers(.06)
        var amount:=float(actor.flash_materials[0].get_shader_parameter("flash_amount"))
        check(amount>0 and amount<1,String(design.kind)+" white flash fades rather than staying on")
        actor._tick_timers(.08)
        check(actor.flash_timer==0 and float(actor.flash_materials[0].get_shader_parameter("flash_amount"))==0,String(design.kind)+" original body color restores")
        check(actor.sprite.scale==before_scale,String(design.kind)+" fading flash never changes body size")
        if bool(design.boss):
            actor.take_hit(1,1)
            actor.phase_pause=.3
            await draw_frame();await draw_frame()
            actor._step_enemy(.2)
            check(actor.phase_pause>0 and actor.flash_timer==0,String(design.kind)+" phase pause does not freeze a white silhouette")
        actor.take_hit(99999,1)
        for tick in 4:
            await draw_frame()
            check(is_instance_valid(actor) and actor.sprite.scale==before_scale,String(design.kind)+" fatal hit never shrinks the body")
        RETIRE.retire_tree(stage);actor.queue_free()
        await process_frame;await process_frame
        ART.frame_cache.clear();ART.textures.clear()
        kinds+=1
    for direction in [-1,1]:
        var actor:=ENEMY.new()
        actor.configure({"id":"recoil","kind":"moss_larva","hp":100},"",false)
        actor.leash_radius=0
        stage.add_child(actor);actor.set_physics_process(false);actor.position=Vector2(400,360)
        actor.take_hit(1,direction)
        var origin:=actor.position.x
        actor._tick_timers(.1)
        var distance: float=(actor.position.x-origin)*direction
        check(distance>18 and distance<35,"clear directional recoil without frame-sized teleport")
        var wall:=StaticBody2D.new();wall.collision_layer=1
        var collision:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(20,240);collision.shape=box;wall.add_child(collision)
        wall.position=Vector2(400+direction*45,360);stage.add_child(wall)
        actor.position=Vector2(400,360)
        await physics_frame;await physics_frame
        actor.take_hit(1,direction);actor._tick_timers(.5)
        var motion: Rect2=actor.get_motion_rect()
        check(motion.end.x<=wall.position.x-10+.6 if direction>0 else motion.position.x>=wall.position.x+10-.6,"recoil sweep stops at terrain in both directions")
        RETIRE.retire_tree(actor);actor.queue_free();wall.queue_free()
        await process_frame;await process_frame
    check(kinds==46,"all production characters rendered")
    RETIRE.retire_tree(root)
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    RETIRE.retire_tree(stage);stage.queue_free()
    await process_frame;await process_frame
    check(await RETIRE.drain(self),"feedback retires audio")
    print("ENEMY_HIT_FEEDBACK checks=%d failures=%d characters=%d" % [checks,failures,kinds])
    quit(0 if failures==0 else 1)
