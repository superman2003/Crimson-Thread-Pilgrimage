extends RefCounted
## Registered via enemy_effect_lifetime; source joins and real rotated pixels.
const ART := preload("res://scripts/beam_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
var checks := 0
var failures := 0
var manifest: Dictionary

class Target extends CharacterBody2D:
    var ui_input_locked := false
    var damage_received := 0
    var facing := 1
    func can_deflect_projectile() -> bool:return true
    func take_damage(amount: int,_point: Vector2,_blockable: bool=true) -> void:damage_received+=amount

class RockArena extends Node2D:
    var rock := {}
    func _rock_ray_hit(_start: Vector2,_end: Vector2) -> Dictionary:return rock

class Reference extends Node2D:
    var pieces: Array[Dictionary]=[]
    var angle := 0.0
    func _draw() -> void:
        draw_set_transform(Vector2.ZERO,angle,Vector2.ONE)
        for piece in pieces:draw_texture_rect_region(ART.ATLAS,piece.destination,piece.source,Color.WHITE)
        draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error("BEAM_ART: "+label)

func run(tree: SceneTree,enemy) -> int:
    manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/beams/manifest.json"))
    _check(manifest.families==ART.FAMILIES and manifest.body_thickness==ART.BODY and manifest.axis_y==ART.AXIS,"manifest and runtime agree on registration")
    var image:=ART.ATLAS.get_image()
    _check(image.get_size()==Vector2i(1024,512),"single bounded atlas contains sixteen parts")
    for family in ART.FAMILIES:
        var distinct: Dictionary={}
        var cels: Array[Image]=[]
        for part in range(4):
            var rect: Array=manifest.sources[family].frames[part].atlas_rect
            _check(ART.atlas_rect(family,part)==Rect2(rect[0],rect[1],rect[2],rect[3]),"%s/%d maps delivered part" % [family,part])
            var cel:=image.get_region(Rect2i(ART.atlas_rect(family,part)));cels.append(cel)
            _check(not cel.is_invisible(),"%s/%d contains authored pixels" % [family,part])
            distinct[cel.get_data().hex_encode().sha256_text()]=true
        _check(distinct.size()==4,family+" retains distinct origin/middle A/middle B/end")
        for part in range(4):
            var edges: Array=[cels[part].get_width()-1] if part==0 else ([0] if part==3 else [0,cels[part].get_width()-1])
            for edge in edges:
                var equal:=true
                for y in range(128):
                    var a:=cels[part].get_pixel(edge,y)
                    var b:=cels[0].get_pixel(cels[0].get_width()-1,y)
                    # Godot may refill RGB of fully transparent texels on import.
                    if a.a!=b.a or (a.a>0 and a!=b):equal=false
                _check(equal,"%s/%d join uses identical RGBA on every scanline" % [family,part])
        for part in [1,2]:
            var continuous:=true
            for x in range(cels[part].get_width()):
                var strongest:=0.0
                for y in range(56,72):strongest=maxf(strongest,cels[part].get_pixel(x,y).a)
                if strongest<.95:continuous=false
            _check(continuous,"%s/%d core has no transparent column" % [family,part])
        for length in [0.0,.25,1.0,17.0,100.0,160.0,455.0,650.0,720.0,100000.0]:
            for frame in range(2):
                var parts:=ART.segments(family,length,17,frame/ART.FPS+.001)
                if length<=0:
                    _check(parts.is_empty(),family+" zero-length wall clip has no visual parts")
                    continue
                var valid:=parts.size()>=2 and parts.size()<=ART.MAX_MIDDLES+2
                # Rect2 stores float32; the synthetic 100km stress case has
                # subpixel rounding above the normal <=720px gameplay range.
                var tolerance:=maxf(.001,length*.0000001)
                var end:=0.0
                for piece in parts:
                    var destination: Rect2=piece.destination
                    var source: Rect2=piece.source
                    valid=valid and absf(destination.position.x-end)<tolerance and destination.size.x>0 and source.size.x>0 and source.size.x<=256 and (source==ART.atlas_rect(family,0) or source==ART.atlas_rect(family,3) or source==ART.atlas_rect(family,frame+1))
                    end=destination.end.x
                _check(valid and absf(end-length)<tolerance,"%s length=%s has bounded gap-free pieces ending exactly at wall" % [family,length])
    _check(ART.middle_frame(.001)==1 and ART.middle_frame(.084)==2 and ART.middle_frame(.167)==1,"middle animation alternates at twelve fps")
    _check(ART.family_for("future")=="" and ART.family_for("steam")=="steam","unknown fallback and explicit family are preserved")
    _check(ART.segments("steam",NAN,17,0).is_empty() and ART.segments("steam",100,0,0).is_empty(),"invalid layout consumes no pieces")
    await _catalogue(tree,enemy)
    await _pixels(tree,enemy)
    await _collision(tree)
    print("BEAM_ART_VALIDATION checks=%d failures=%d families=4 parts=16" % [checks,failures])
    return failures

func _catalogue(tree: SceneTree,enemy) -> void:
    var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var expected: Dictionary={"pipe_thrower":"steam","valve_crawler":"steam","erasure_bailiff":"erase","sunken_hammer_smith":"thread","silent_crown_core":"gate"}
    var old_kind: String=enemy.kind
    var seen: Dictionary={}
    var count:=0
    for kind in catalogue:
        var commands: Array=catalogue[kind].get("attacks",[]).duplicate();commands.append_array(catalogue[kind].get("elite",{}).get("attacks",[]))
        for command: Dictionary in commands:
            if command.get("type","")!="beam":continue
            count+=1;enemy.kind=kind;enemy.attack_target=enemy.global_position+Vector2(400,-50)
            enemy._spawn_command_effects(command,true)
            var effect: Node2D=enemy.owned_attack_effects.back();effect.set_physics_process(false)
            var want: String=expected[kind]
            _check(ART.family_for(effect.skin,enemy)==want,command.id+" reaches correct art through actual spawn")
            seen[want]=true
            _check(effect.damage==command.damage and effect.radius==float(command.radius) and effect.length==float(command.beam_length),command.id+" preserves damage, width and range")
            _check(is_equal_approx(effect.arm_delay,float(command.windup)) and is_equal_approx(effect.duration-effect.arm_delay,float(command.hazard_life)),command.id+" preserves windup and active lifetime")
            _check(not effect.get_meta("blockable",true) and effect.z_index==POLICY.DANGER_Z and not effect.z_as_relative,command.id+" keeps unblockable flag and absolute priority")
            var aim: Vector2=(enemy.attack_target-effect.global_position).normalized()
            _check(effect.heading.distance_to(aim)<.001,command.id+" preserves normalized aiming")
            effect.cancel();await tree.process_frame
    enemy.kind=old_kind
    _check(count==5 and seen.size()==4,"all five authored beam commands reach four families")

func _oracle(family: String,length: float,radius: float,frame: int) -> Array[Dictionary]:
    # Independent layout derived from delivery manifest, never calls ART.segments.
    var rects: Array[Rect2]=[]
    for part in range(4):
        var r: Array=manifest.sources[family].frames[part].atlas_rect
        rects.append(Rect2(r[0],r[1],r[2],r[3]))
    var factor:=radius/16.0
    var left:=rects[0].size.x*factor
    var right:=rects[3].size.x*factor
    if left+right>length:
        left=length*left/(left+right);right=length-left
    var result: Array[Dictionary]=[{"source":rects[0],"destination":Rect2(0,-64*factor,left,128*factor)}]
    var fill:=maxf(0,length-left-right)
    var repeats:=ceili(fill/(rects[frame].size.x*factor))
    for tile in range(repeats):
        var at:=left+fill*tile/repeats
        var edge:=left+fill*(tile+1)/repeats
        result.append({"source":rects[frame],"destination":Rect2(at,-64*factor,edge-at,128*factor)})
    result.append({"source":rects[3],"destination":Rect2(length-right,-64*factor,right,128*factor)})
    return result

func _pixels(tree: SceneTree,enemy) -> void:
    _check(DisplayServer.get_name()!="headless","real GL required for segmented beam validation")
    if DisplayServer.get_name()=="headless":return
    var view:=SubViewport.new();view.size=Vector2i(1024,1024);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;tree.root.add_child(view)
    var stage:=Node2D.new();view.add_child(stage)
    var background:=Polygon2D.new();background.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,1024),Vector2(0,1024)]);stage.add_child(background)
    var reference:=Reference.new();stage.add_child(reference)
    for index in range(4):
        var family: String=ART.FAMILIES[index]
        var radius: float=[18,18,13,15][index]
        var length: float=[455,720,300,650][index]
        var beam: Node2D=enemy._effect("beam",Vector2.ZERO,Vector2.RIGHT,{"skin":family,"radius":radius,"beam_length":length},1,1)
        beam.set_physics_process(false);beam.reparent(stage,false)
        for light in [false,true]:
            background.color=Color(.89,.87,.8) if light else Color(.08,.12,.14)
            for angle in [0.0,PI,PI/4]:
                var origin:=Vector2(150,200) if angle==0 else (Vector2(880,200) if angle==PI else Vector2(160,160))
                var fingerprints: Dictionary={}
                for sample in range(3):
                    var frame:=1 if sample==0 else 2
                    beam.position=origin;beam.heading=Vector2.from_angle(angle);beam.age=1+(frame-1)/ART.FPS+.001 if sample<2 else beam.duration-.001;beam.show();beam.queue_redraw();reference.hide()
                    await tree.process_frame;await RenderingServer.frame_post_draw
                    var actual:=view.get_texture().get_image()
                    beam.hide();reference.position=origin;reference.angle=angle;reference.pieces=_oracle(family,length,radius,frame);reference.show();reference.queue_redraw()
                    await tree.process_frame;await RenderingServer.frame_post_draw
                    var expected:=view.get_texture().get_image()
                    var axis:=Vector2.from_angle(angle);var side:=axis.orthogonal()
                    var max_error:=0;var samples:=0;var visible:=0;var fingerprint: PackedByteArray=[]
                    for x in range(5,int(length)-4,3):
                        for y in range(-int(radius)+4,int(radius)-3,3):
                            var at:=Vector2i((origin+axis*x+side*y).floor())
                            var a:=actual.get_pixelv(at);var b:=expected.get_pixelv(at)
                            max_error=maxi(max_error,int(round(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))*255)))
                            if Vector3(a.r-background.color.r,a.g-background.color.g,a.b-background.color.b).length()>.12:visible+=1
                            fingerprint.append(int(a.r*255));fingerprint.append(int(a.g*255));fingerprint.append(int(a.b*255));samples+=1
                    _check(max_error<=1,"%s frame=%d angle=%s light=%s last_ms=%s matches independent source layout" % [family,frame,angle,light,sample==2])
                    _check(visible>samples/10,family+" remains visible at gameplay thickness")
                    fingerprints[fingerprint.hex_encode().sha256_text()]=true
                    var outside_clear:=true
                    for distance in [-6.0,length+6]:
                        for offset in [-radius,0.0,radius]:
                            var p:=Vector2i((origin+axis*distance+side*offset).floor());var pixel:=actual.get_pixelv(p)
                            if Vector3(pixel.r-background.color.r,pixel.g-background.color.g,pixel.b-background.color.b).length()>.02:outside_clear=false
                    _check(outside_clear,family+" never paints behind origin or beyond clipped endpoint")
                _check(fingerprints.size()==2,family+" really renders both middle shimmer frames")
        beam.cancel();await tree.process_frame
    # A small ray clip squeezes caps instead of painting through the obstruction.
    var short_beam: Node2D=enemy._effect("beam",Vector2.ZERO,Vector2.RIGHT,{"skin":"steam","radius":17,"beam_length":7},0,1)
    short_beam.set_physics_process(false);short_beam.reparent(stage,false);short_beam.position=Vector2(300,500);short_beam.age=.1
    reference.hide();await tree.process_frame;await RenderingServer.frame_post_draw
    var short_image:=view.get_texture().get_image()
    _check(Vector3(short_image.get_pixel(313,500).r-background.color.r,short_image.get_pixel(313,500).g-background.color.g,short_image.get_pixel(313,500).b-background.color.b).length()<.02,"short compressed caps cannot overrun a seven-pixel clip")
    short_beam.length=0;short_beam.queue_redraw();await tree.process_frame;await RenderingServer.frame_post_draw
    _check(Vector3(view.get_texture().get_image().get_pixel(300,500).r-background.color.r,view.get_texture().get_image().get_pixel(300,500).g-background.color.g,view.get_texture().get_image().get_pixel(300,500).b-background.color.b).length()<.02,"zero-length clipped beam emits no active pixels")
    short_beam.cancel();view.queue_free();await tree.process_frame;await tree.process_frame

func _collision(tree: SceneTree) -> void:
    var arena:=RockArena.new();tree.root.add_child(arena)
    var enemy:=ENEMY.new();arena.add_child(enemy);enemy.set_physics_process(false)
    var wall:=StaticBody2D.new();wall.position=Vector2(500,400)
    var shape:=RectangleShape2D.new();shape.size=Vector2(10,700)
    var collider:=CollisionShape2D.new();collider.shape=shape;wall.add_child(collider);arena.add_child(wall)
    await tree.physics_frame;await tree.process_frame
    for direction in [1.0,-1.0]:
        var origin:=Vector2(400 if direction>0 else 600,400)
        var beam: Node2D=enemy._effect("beam",origin,Vector2(direction,0),{"skin":"erase","radius":18,"beam_length":455},1,.36)
        beam.set_physics_process(false)
        _check(absf(beam.length-95)<.01,"solid wall clips real beam before art layout in direction "+str(direction))
        var endpoint: Vector2=beam.global_position+beam.heading*beam.length
        _check(absf(endpoint.x-(495 if direction>0 else 505))<.01,"art endpoint shares exact collision ray hit")
        beam.cancel()
    var diagonal: Node2D=enemy._effect("beam",Vector2(400,300),Vector2(1,1),{"skin":"gate","beam_length":720},1,.4)
    diagonal.set_physics_process(false)
    _check(absf(diagonal.length-95*sqrt(2))<.01,"diagonal beam clips by ray distance rather than horizontal projection")
    _check((diagonal.global_position+diagonal.heading*diagonal.length).distance_to(Vector2(495,395))<.01,"diagonal cap endpoint stays on collision wall")
    diagonal.cancel()
    arena.rock={"position":Vector2(550,400),"authored_rock":true}
    var farther: Node2D=enemy._effect("beam",Vector2(400,400),Vector2.RIGHT,{"skin":"thread","beam_length":650},1,.4)
    farther.set_physics_process(false)
    _check(farther.length==95,"farther authored rock does not override nearer wall")
    farther.cancel()
    arena.rock={"position":Vector2(400,400),"authored_rock":true}
    var zero: Node2D=enemy._effect("beam",Vector2(400,400),Vector2.RIGHT,{"skin":"thread","beam_length":650},1,.4)
    zero.set_physics_process(false)
    _check(zero.length==0 and ART.segments("thread",zero.length,zero.radius,0).is_empty(),"obstruction at origin reaches zero-length presentation path")
    zero.cancel()
    arena.rock={"position":Vector2(450,400),"authored_rock":true}
    var rock_beam: Node2D=enemy._effect("beam",Vector2(400,400),Vector2.RIGHT,{"skin":"thread","beam_length":650},1,.4)
    rock_beam.set_physics_process(false)
    _check(rock_beam.length==50,"nearer authored rock still wins over solid wall clipping")
    rock_beam.cancel();arena.rock={}
    var target:=Target.new();arena.add_child(target);target.add_to_group("player");target.position=Vector2(250,342)
    var live: Node2D=enemy._effect("beam",Vector2(200,300),Vector2.RIGHT,{"skin":"steam","radius":17,"beam_length":160,"damage":2,"blockable":false},1,.4)
    live.set_physics_process(false);live._physics_process(.999)
    _check(target.damage_received==0,"warning channel does not damage")
    live._physics_process(.002)
    _check(target.damage_received==2 and not live.reflected and not live.cancelled,"active beam retains one hit and cannot be reflected")
    live._physics_process(.2)
    _check(target.damage_received==2,"persistent beam cannot hit twice")
    _check(live._hits_player(Vector2(200,300)) and live._hits_player(Vector2(360,300)) and not live._hits_player(Vector2(199.99,300)) and not live._hits_player(Vector2(360.01,300)),"longitudinal inclusive endpoints remain unchanged")
    _check(live._hits_player(Vector2(250,335.99)) and not live._hits_player(Vector2(250,336.01)),"original width plus nineteen-pixel player tolerance remains unchanged")
    target.ui_input_locked=true;var saved: float=live.age;live._physics_process(10);target.ui_input_locked=false
    _check(live.age==saved and not live.cancelled,"UI lock pauses existing active clock")
    var before:=tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    live._physics_process(.2)
    _check(live.cancelled and not live.is_in_group("hostile_attack") and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()==before,"expiry retires beam without invented impact/fade")
    var retired: Node2D=enemy._effect("beam",Vector2.ZERO,Vector2.RIGHT,{"skin":"gate"},0,1)
    retired.set_physics_process(false);enemy.dying=true;retired._physics_process(.01);enemy.dying=false
    _check(retired.cancelled,"owner retirement cancels full beam immediately")
    var marks: Array[Node2D]=[]
    for i in range(12):
        var mark:=Node2D.new()
        if POLICY.attach_contact(arena,mark):marks.append(mark)
    var uncapped: Node2D=enemy._effect("beam",Vector2.ZERO,Vector2.RIGHT,{"skin":"gate"},0,1)
    uncapped.set_physics_process(false)
    _check(marks.size()==12 and uncapped.is_in_group("hostile_attack"),"contact decoration saturation never culls a dangerous beam")
    arena.queue_free();await tree.process_frame;await tree.process_frame
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(),"scene retirement clears all beam test decorations")
