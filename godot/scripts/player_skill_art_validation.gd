extends RefCounted
## Uses the registered seal_combat entry with independent source-pixel checks.
const ART:=preload("res://scripts/player_skill_art.gd")
const EFFECT:=preload("res://scripts/player_tool_effect.gd")
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
var checks:=0
var failures:=0
var manifest:Dictionary

class Target extends Node2D:
    var active:=true
    var hits:=0
    var damage:=0
    var marked:=false
    var staggers:Array[float]=[]
    var snares:Array[float]=[]
    func world_residency_active()->bool:return active
    func get_hurtbox_rect()->Rect2:return Rect2(global_position-Vector2(10,10),Vector2(20,20))
    func take_hit(amount:int,_direction:int)->void:hits+=1;damage+=amount
    func apply_salt_mark(_seconds:float)->void:marked=true
    func apply_stagger(seconds:float)->void:staggers.append(seconds)
    func consume_salt_mark()->bool:
        var had:=marked;marked=false;return had
    func apply_snare(seconds:float)->void:snares.append(seconds)

class Reference extends Node2D:
    var source:=Rect2()
    var destination:=Rect2()
    var mirror:=1.0
    var alpha:=1.0
    func _draw()->void:
        draw_set_transform(Vector2.ZERO,0,Vector2(mirror,1))
        draw_texture_rect_region(ART.ATLAS,destination,source,Color(1,1,1,alpha))
        draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures+=1;push_error("PLAYER_SKILL_ART: "+label)

func _effect(stage:Node,owner_node:Node2D,payload:Dictionary,point:Vector2,direction:int=1)->Node2D:
    var node:=EFFECT.new();node.payload=payload.duplicate(true);node.owner_player=owner_node;node.direction=direction;node.position=point;stage.add_child(node);node.set_physics_process(false);return node

func run(tree:SceneTree)->int:
    manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/player_skills/manifest.json"))
    _check(manifest.families==ART.FAMILIES,"manifest and runtime agree on three skills")
    var image:=ART.ATLAS.get_image()
    _check(image.get_size()==Vector2i(1536,576),"bounded atlas has twenty-four frames")
    for family in ART.FAMILIES:
        var distinct:Dictionary={}
        for frame in range(8):
            var rect:Array=manifest.sources[family].frames[frame].atlas_rect
            _check(ART.atlas_rect(family,frame)==Rect2(rect[0],rect[1],rect[2],rect[3]),"%s/%d uses delivered frame" % [family,frame])
            var cel:=image.get_region(Rect2i(ART.atlas_rect(family,frame)))
            _check(not cel.is_invisible(),"%s/%d has authored pixels" % [family,frame]);distinct[cel.get_data().hex_encode().sha256_text()]=true
        _check(distinct.size()==8,family+" preserves eight distinct source frames")
    _check(ART.family_for({"kind":"projectile","id":"shard"})=="" and ART.family_for({"kind":"wave"})=="","tools and unmarked payloads retain original fallback")
    _check(ART.active_frame("shockwave",.209)==5 and ART.active_frame("snare",.084)==1,"wave fits its loop within short range while snare keeps slower growth")
    await _casts(tree)
    await _pixels(tree)
    await _physics(tree)
    print("PLAYER_SKILL_ART_VALIDATION checks=%d failures=%d families=3 frames=24" % [checks,failures])
    return failures

func _casts(tree:SceneTree)->void:
    var stage:=Node2D.new();tree.root.add_child(stage)
    var floor_node:=StaticBody2D.new();floor_node.position=Vector2(0,10)
    var shape:=RectangleShape2D.new();shape.size=Vector2(1800,20)
    var collider:=CollisionShape2D.new();collider.shape=shape;floor_node.add_child(collider);stage.add_child(floor_node)
    var player=load("res://scenes/Player.tscn").instantiate();stage.add_child(player)
    for i in range(10):await tree.physics_frame
    player.set_physics_process(false);player.build_system=null;player.apply_build_stats({"crest_id":"crimson"})
    var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    for direction in [-1,1]:
        for id in ["needle","shockwave","snare"]:
            player._reset_traversal_state();player.skill_cooldown=0;player.energy=100;player.facing=direction
            var row:Dictionary=catalog.skills[id].duplicate(true);row["id"]=id;player.configure_selected_skill(row)
            _check(player.cast_selected_skill(),id+" starts through actual selected-skill action")
            _check(player.energy==100-int(row.energy_cost),id+" retains listed thread cost")
            player._update_attack(float(row.windup)+.01)
            var effects:Array[Node2D]=[]
            for node in stage.get_children():
                if node.get_script()==EFFECT and not node.is_queued_for_deletion():node.set_physics_process(false);effects.append(node)
            _check(effects.size()==1,id+" emits exactly one real effect")
            if effects.size()==1:
                var effect:Node2D=effects[0]
                _check(effect.art_family==id and effect.direction==direction,id+" reaches authored family and facing")
                _check(effect.payload.damage==player.attack_damage and effect.payload.skill_effect==true,id+" keeps actual skill payload")
                _check(effect.z_index==POLICY.BLADE_Z and not effect.z_as_relative,id+" stays below enemy danger and warning layers")
                var offset:=Vector2(direction*(90 if id=="snare" else 24),-6 if id=="snare" else -42)
                _check(effect.global_position.distance_to(player.global_position+offset)<.001,id+" retains original spawn anchor")
                effect.queue_free()
            await tree.process_frame
    player._reset_traversal_state();player.skill_cooldown=0
    var field:Dictionary={"kind":"snare_field","skill_effect":true,"duration":1.4,"damage":1,"range":10000}
    _check(player.cast_tool(field),"first field is placed through actual public spawn")
    var first:Node2D=null
    for node in stage.get_children():
        if node.get_script()==EFFECT and not node.is_queued_for_deletion():first=node;node.set_physics_process(false)
    var before:=tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()
    _check(player.cast_tool(field) and is_instance_valid(first) and first.is_queued_for_deletion(),"second field replaces the first with original one-field rule")
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()==before,"replacement does not manufacture natural-expiry fade")
    stage.queue_free();await tree.process_frame;await tree.process_frame

func _reference(reference:Reference,family:String,frame:int,direction:int,alpha:float)->void:
    var meta:Dictionary=manifest.sources[family];var rect:Array=meta.frames[frame].atlas_rect
    reference.source=Rect2(rect[0],rect[1],rect[2],rect[3])
    var factor:=float(manifest.native_widths[family])/float(meta.body_width)
    var anchor:=Vector2(meta.packed_anchor[0],meta.packed_anchor[1])
    var offset:=Vector2.ZERO if family=="needle" else Vector2(0,42 if family=="shockwave" else 6)
    reference.destination=Rect2(offset-anchor*factor,Vector2(192,192)*factor)
    reference.mirror=-1 if direction<0 and family!="snare" else 1;reference.alpha=alpha;reference.queue_redraw()

func _pixels(tree:SceneTree)->void:
    _check(DisplayServer.get_name()!="headless","real GL required for skill source readback")
    if DisplayServer.get_name()=="headless":return
    var view:=SubViewport.new();view.size=Vector2i(640,220);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;tree.root.add_child(view)
    var stage:=Node2D.new();view.add_child(stage)
    var background:=Polygon2D.new();background.polygon=PackedVector2Array([Vector2.ZERO,Vector2(640,0),Vector2(640,220),Vector2(0,220)]);stage.add_child(background)
    var owner_node:=CharacterBody2D.new();stage.add_child(owner_node)
    var nodes:Array[Node2D]=[];var references:Array[Reference]=[]
    for index in range(3):
        var payload:Dictionary={"kind":["projectile","wave","snare_field"][index],"skill_effect":true,"duration":5,"range":10000}
        var node:=_effect(stage,owner_node,payload,Vector2(index*210+65,100));nodes.append(node)
        var reference:=Reference.new();reference.position=node.position+Vector2(88,0);stage.add_child(reference);references.append(reference)
    for light in [false,true]:
        background.color=Color(.89,.87,.8) if light else Color(.08,.12,.14)
        for direction in [-1,1]:
            var distinct:Array[Dictionary]=[{}, {}, {}]
            for frame in range(8):
                var marks:Array[Node2D]=[]
                for index in range(3):
                    var family:String=ART.FAMILIES[index];var terminal:=frame>=(4 if index==0 else 6)
                    var alpha:=1.0
                    if terminal:
                        nodes[index].hide()
                        var mark:=ART.spawn_terminal(stage,nodes[index].position,family,direction,"hit" if index==0 else "expiry")
                        mark.set_process(false)
                        var fps:=20.0 if index==0 else 12.0
                        mark.age=(frame-(4 if index==0 else 6))/fps+.001;alpha=clampf(((.2 if index==0 else 2.0/12)-mark.age)*fps,0,1)
                        mark.queue_redraw();marks.append(mark)
                    else:
                        nodes[index].show();nodes[index].direction=direction;nodes[index].elapsed=frame/(14.0 if index==0 else 24.0 if index==1 else 12.0)+.001;nodes[index].queue_redraw()
                    _reference(references[index],family,frame,direction,alpha)
                await tree.process_frame;await RenderingServer.frame_post_draw
                var image:=view.get_texture().get_image()
                for index in range(3):
                    var center:=Vector2i(nodes[index].position);var offset:=Vector2i(-20,-24) if index==0 else Vector2i(-40,-48)
                    var size:=Vector2i(40,48) if index==0 else Vector2i(80,100)
                    var actual:=image.get_region(Rect2i(center+offset,size));var expected:=image.get_region(Rect2i(center+Vector2i(88,0)+offset,size))
                    var a:=actual.get_data();var b:=expected.get_data();var max_error:=0;var visible:=0
                    for y in range(size.y):
                        for x in range(size.x):
                            if index==2 and frame<6 and absf((Vector2(offset+Vector2i(x,y))+Vector2(.5,.5)).length()-36)<3.5:continue
                            if frame==2:
                                var pixel:=actual.get_pixel(x,y)
                                if Vector3(pixel.r-background.color.r,pixel.g-background.color.g,pixel.b-background.color.b).length()>.1:visible+=1
                            for channel in range(4):
                                var at:=(y*size.x+x)*4+channel;max_error=maxi(max_error,absi(int(a[at])-int(b[at])))
                    _check(max_error<=1,"%s/%d direction=%d light=%s displays registered source pixels" % [ART.FAMILIES[index],frame,direction,light])
                    if frame==2:_check(visible>=(12 if index==0 else 80),ART.FAMILIES[index]+" remains readable at native size")
                    if (index==0 and frame<4) or (index>0 and frame in [2,3,4,5]):distinct[index][a.hex_encode().sha256_text()]=true
                for mark in marks:mark.queue_free()
                await tree.process_frame
            for index in range(3):_check(distinct[index].size()==4,ART.FAMILIES[index]+" has four actual rendered active cels")
    view.queue_free();await tree.process_frame;await tree.process_frame

func _physics(tree:SceneTree)->void:
    var stage:=Node2D.new();tree.root.add_child(stage);var owner_node:=CharacterBody2D.new();stage.add_child(owner_node)
    var inactive:=Target.new();inactive.position=Vector2(40,-42);inactive.active=false;stage.add_child(inactive);inactive.add_to_group("enemy")
    var target:=Target.new();target.position=Vector2(60,-42);stage.add_child(target);target.add_to_group("enemy")
    var needle:=_effect(stage,owner_node,{"kind":"projectile","skill_effect":true,"duration":1.2,"range":420,"damage":2,"salt_mark":true},Vector2(24,-42))
    needle._physics_process(.12)
    _check(target.hits==1 and target.damage==2 and target.marked and inactive.hits==0,"real swept needle hits one resident enemy and preserves salt mark")
    _check(needle.is_queued_for_deletion() and not needle.is_physics_processing(),"needle retires damage immediately before cosmetic impact")
    var marks:=tree.get_nodes_in_group(POLICY.CONTACT_GROUP)
    _check(marks.size()==1 and marks[0].global_position.distance_to(Vector2(60,-42))<.01,"needle impact uses swept contact point instead of overshot endpoint")
    needle._physics_process(.01);_check(target.hits==1,"retired needle cannot hit again")
    target.queue_free();inactive.queue_free()
    for mark in marks:mark.queue_free()
    await tree.process_frame
    var wall:=StaticBody2D.new();wall.position=Vector2(300,-42)
    var shape:=RectangleShape2D.new();shape.size=Vector2(10,100);var collider:=CollisionShape2D.new();collider.shape=shape;wall.add_child(collider);stage.add_child(wall)
    await tree.physics_frame;await tree.process_frame
    var wall_needle:=_effect(stage,owner_node,{"kind":"projectile","skill_effect":true,"duration":1.2,"range":420},Vector2(250,-42))
    wall_needle._physics_process(.1)
    marks=tree.get_nodes_in_group(POLICY.CONTACT_GROUP)
    _check(wall_needle.is_queued_for_deletion() and marks.size()==1 and marks[0].global_position.distance_to(Vector2(295,-42))<.01,"wall impact stays at actual ray hit without piercing")
    wall.queue_free();for mark in marks:mark.queue_free()
    await tree.physics_frame;await tree.process_frame
    var enemies:Array[Target]=[]
    for x in [40,100]:
        var enemy:=Target.new();enemy.position=Vector2(x,-42);stage.add_child(enemy);enemy.add_to_group("enemy");enemies.append(enemy)
    var wave:=_effect(stage,owner_node,{"kind":"wave","skill_effect":true,"duration":.8,"range":160,"damage":3,"stagger":.4},Vector2(24,-42))
    wave._physics_process(.2)
    _check(wave.global_position==Vector2(148,-42) and is_equal_approx(wave.travelled,124),"wave keeps original 620px/s horizontal path")
    for enemy in enemies:_check(enemy.hits==1 and enemy.damage==3 and enemy.staggers==[.4],"wave hits each swept enemy once with unchanged stagger")
    wave._physics_process(.01);_check(enemies[1].hits==1,"wave target memory prevents repeat damage")
    wave._physics_process(.06);wave._physics_process(.001)
    _check(wave.is_queued_for_deletion() and not wave.is_physics_processing() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()==1,"range retirement emits separate safe wave collapse")
    for enemy in enemies:enemy.queue_free()
    for mark in tree.get_nodes_in_group(POLICY.CONTACT_GROUP):mark.queue_free()
    await tree.process_frame
    var snared:=Target.new();snared.position=Vector2(135.9,-6);snared.marked=true;stage.add_child(snared);snared.add_to_group("enemy")
    var outside:=Target.new();outside.position=Vector2(136.1,-6);stage.add_child(outside);outside.add_to_group("enemy")
    var field:=_effect(stage,owner_node,{"kind":"snare_field","skill_effect":true,"duration":1.4,"range":10000,"damage":1,"salt_consume":true},Vector2(90,-6))
    field._physics_process(.01)
    _check(snared.hits==1 and snared.damage==1 and snared.snares==[2.9] and not snared.marked,"first appearance retains immediate control and salt-mark consumption")
    _check(outside.hits==0,"snare keeps original hurtbox growth threshold")
    field._physics_process(.1);_check(snared.hits==1 and snared.snares.size()==1,"field controls an enemy only once")
    field._physics_process(1.3)
    _check(field.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()==1,"field expiry retires control before safe fade")
    snared.queue_free();outside.queue_free()
    for mark in tree.get_nodes_in_group(POLICY.CONTACT_GROUP):mark.queue_free()
    await tree.process_frame
    var miss:=_effect(stage,owner_node,{"kind":"projectile","skill_effect":true,"duration":.01,"range":420},Vector2.ZERO)
    miss._physics_process(.02);_check(miss.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(),"needle natural expiry emits no fake hit")
    var cancelled:=_effect(stage,owner_node,{"kind":"snare_field","skill_effect":true,"duration":1.4},Vector2.ZERO);cancelled.queue_free()
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(),"external cancellation emits no fake natural fade")
    var orphan:=_effect(stage,owner_node,{"kind":"wave","skill_effect":true,"duration":.8},Vector2.ZERO)
    owner_node.queue_free();await tree.process_frame;orphan._physics_process(.01)
    _check(orphan.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(),"freed owner retires skill without terminal decoration")
    for family in ART.FAMILIES:
        var mark:=ART.spawn_terminal(stage,Vector2(10,20),family,-1,"hit" if family=="needle" else "expiry")
        mark.set_process(false);var selected:Array[int]=[]
        mark.paint=func(_host,_family,frame,_direction,_alpha):selected.append(frame)
        var first:=4 if family=="needle" else 6;var count:=4 if family=="needle" else 2;var fps:=20.0 if family=="needle" else 12.0
        for i in range(count):mark.age=i/fps+.001;mark._draw()
        var want:Array[int]=[];for i in range(count):want.append(first+i)
        _check(selected==want,family+" terminal selects all delivered frames")
        _check(not mark.is_in_group("player_snare_field") and not mark.is_in_group("player_trap"),"terminal cannot retain control/trap membership")
        mark.age=0;mark._process(.3);_check(not mark.is_queued_for_deletion(),"slow first draw preserves first terminal frame")
        mark._process(.3);_check(mark.is_queued_for_deletion(),"terminal completes within bounded lifetime")
    await tree.process_frame
    for i in range(20):ART.spawn_terminal(stage,Vector2.ZERO,"needle",1,"hit")
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size()==12,"terminal effects share twelve-decoration cap")
    var owner_again:=CharacterBody2D.new();stage.add_child(owner_again)
    var uncapped:=_effect(stage,owner_again,{"kind":"snare_field","skill_effect":true,"duration":1.4},Vector2.ZERO)
    _check(uncapped.is_in_group("player_snare_field") and not uncapped.is_queued_for_deletion(),"decoration saturation does not cull active control")
    var legacy:=_effect(stage,owner_again,{"id":"mine","kind":"trap","duration":6},Vector2.ZERO)
    _check(legacy.art_family.is_empty() and legacy.get_child_count()==1 and legacy.get_child(0) is Polygon2D,"unconverted tools retain original procedural visual")
    stage.queue_free();await tree.process_frame;await tree.process_frame
    _check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(),"scene retirement releases all cosmetic capacity")
