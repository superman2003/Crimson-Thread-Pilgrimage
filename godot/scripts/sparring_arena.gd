extends Node2D
## A disposable copy of the fighter and build. The real journey is suspended.
const ORIGIN := Vector2(1000000,1000000)
var level: Node
var bout: Dictionary
var source: Dictionary
var player: CharacterBody2D
var build: RefCounted
var wave:=0
var alive: Array[Area2D]=[]
var actors: Array[Area2D]=[]
var paused_groups: Dictionary={}
var layers: Array=[]
var old_mode: int
var old_visible: bool
var label: Label
var finished:=false
var closing:=false
var elapsed:=0.0
var hits:=0
var record: Dictionary={}
var on_return: Callable

func begin(real_level: Node,plan: Dictionary,callback: Callable) -> void:
    level=real_level;bout=plan.duplicate(true);source=preload("res://scripts/sparring_policy.gd").sources(bout);on_return=callback
    old_mode=level.process_mode;old_visible=level.visible
    for group in ["enemy","player"]:
        paused_groups[group]=[]
        for node in get_tree().get_nodes_in_group(group):
            paused_groups[group].append(weakref(node));node.remove_from_group(group)
    for layer in level.find_children("*","CanvasLayer",true,false):
        layers.append({"node":weakref(layer),"visible":layer.visible});layer.hide()
    level.process_mode=Node.PROCESS_MODE_DISABLED;level.hide()
    _floor(Vector2(0,20),Vector2(1200,40))
    _floor(Vector2(-610,-220),Vector2(20,520));_floor(Vector2(610,-220),Vector2(20,520))
    player=load("res://scenes/Player.tscn").instantiate();player.position=ORIGIN+Vector2(-250,0);add_child(player)
    build=preload("res://scripts/build_system.gd").new();build.restore(level.build_system.serialize())
    player.build_system=build;player.apply_build_stats(build.profile());player.selected_skill=build.selected_skill()
    for property in ["dash_unlocked","wall_grip_unlocked","double_jump_unlocked","thread_grapple_unlocked","bell_guard_unlocked","thorn_downstrike_unlocked","lantern_phase_unlocked","crown_resonance_unlocked"]:player.set(property,level.player.get(property))
    player.hp=player.max_hp;player.energy=player.max_energy;player.set_spawn(player.position)
    player.hp_changed.connect(func(_hp: int):hits+=1)
    player.player_respawned.connect(func():finish(false,"练习角色倒下"))
    var camera: Camera2D=player.get_node("Camera2D");camera.position_smoothing_enabled=false;camera.make_current()
    var canvas:=CanvasLayer.new();canvas.layer=100;add_child(canvas)
    var panel:=PanelContainer.new();panel.theme=level.ui_shell.theme;panel.position=Vector2(18,18);canvas.add_child(panel)
    var column:=VBoxContainer.new();panel.add_child(column)
    label=Label.new();label.custom_minimum_size=Vector2(650,70);column.add_child(label)
    var leave:=Button.new();leave.text="结束并返回原旅途（Esc）";leave.pressed.connect(close);column.add_child(leave)
    _next_wave();queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(ORIGIN-Vector2(680,520),Vector2(1360,1200)),Color("191e26"))
    draw_rect(Rect2(ORIGIN+Vector2(-600,0),Vector2(1200,20)),Color("846b66"))
    for x in range(-560,600,80):draw_line(ORIGIN+Vector2(x,0),ORIGIN+Vector2(x,20),Color("b99d7e"),2)

func _floor(offset: Vector2,extent: Vector2) -> void:
    var body:=StaticBody2D.new();body.position=ORIGIN+offset;body.collision_layer=1
    var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=extent;shape.shape=rect;body.add_child(shape);add_child(body)

func _next_wave() -> void:
    if finished:return
    if wave>=bout.waves.size():finish(true,"全部轮次完成");return
    var ids: Array=bout.waves[wave];wave+=1
    for index in ids.size():
        var data: Dictionary=source.actors[String(ids[index])].duplicate(true)
        data.id="sparring_"+String(bout.id)+"_"+str(wave)+"_"+str(index)
        data.position=[0,0];data.patrol=100;data.leash_radius=1100;data.arena_min_x=ORIGIN.x-560;data.arena_max_x=ORIGIN.x+560
        var actor:=Area2D.new();actor.set_script(preload("res://scripts/enemy_actor.gd"))
        actor.configure(data,level.SPRITES.get(String(data.kind),level.SPRITES.moss_larva),bool(bout.boss),source.profiles.get(String(data.kind),{}))
        actor.position=ORIGIN+Vector2(140+index*180,0);actor.set_meta("sparring_actor",true);add_child(actor)
        alive.append(actor);actors.append(actor)
        actor.died.connect(func(_id: String,_boss: bool,_kind: String):_defeated(actor))

func _defeated(actor: Area2D) -> void:
    if finished or not alive.has(actor):return
    alive.erase(actor)
    if alive.is_empty():call_deferred("_next_wave")

func _process(delta: float) -> void:
    if not is_instance_valid(level):close();return
    if finished:return
    elapsed+=delta
    if player.hp<=0 or player.global_position.y>ORIGIN.y+120:finish(false,"练习角色倒下");return
    if elapsed>=300:finish(false,"五分钟练习时限已到");return
    label.text="%s · 第 %d/%d 轮 · 余敌 %d · %.1f 秒\n生命 %d/%d · 绯线 %d · 本场零掉落，旅途资源不变" % [String(bout.title),wave,bout.waves.size(),alive.size(),elapsed,player.hp,player.max_hp,player.energy]
    if Input.is_action_just_pressed("tool_cast"):
        var result: Dictionary=build.use_tool()
        if result.ok:player.cast_tool(result)
    elif Input.is_action_just_pressed("tool_cycle"):build.cycle_tool()
    elif Input.is_action_just_pressed("skill_cycle"):build.cycle_skill();player.selected_skill=build.selected_skill()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:close();get_viewport().set_input_as_handled()

func finish(complete: bool,reason: String) -> void:
    if finished:return
    finished=true;record={"bout":String(bout.id),"title":String(bout.title),"complete":complete,"seconds":elapsed,"hits":hits,"reason":reason}
    player.ui_input_locked=true
    for actor in actors:
        if is_instance_valid(actor):actor.set_physics_process(false)
    label.text="%s · %.1f 秒 · %s\n练习记录只供复盘；点击返回原旅途。" % [String(bout.title),elapsed,reason]

func close() -> void:
    if closing:return
    closing=true
    if not finished:finish(false,"主动结束")
    _restore_journey()
    if on_return.is_valid():on_return.call(record.duplicate(true))
    preload("res://scripts/audio_retirement.gd").retire_tree(self);queue_free()

func _restore_journey() -> void:
    if is_instance_valid(level):
        level.process_mode=old_mode;level.visible=old_visible
        for layer in layers:
            var node: Variant=layer.node.get_ref()
            if is_instance_valid(node):node.visible=layer.visible
        if is_instance_valid(level.player):level.player.get_node("Camera2D").make_current()
    for group in paused_groups:
        for reference in paused_groups[group]:
            var node: Variant=reference.get_ref()
            if is_instance_valid(node):node.add_to_group(group)
    paused_groups={};layers=[]

func _exit_tree() -> void:
    if not paused_groups.is_empty():_restore_journey()
