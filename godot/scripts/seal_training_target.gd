extends "res://scripts/enemy_actor.gd"
## A practice fixture in the real level, never a progression enemy or reward source.
var training_reset := 0.0
var hit_count := 0
var guard_practice_clock := 0.0
var contact_ready := false
var contact_frame := -1

func _ready() -> void:
    super._ready()
    collision_mask = 0
    set_meta("seal_training_target", true)

func _physics_process(delta: float) -> void:
    _refresh_practice_caption()
    var practice_player: Node2D = get_tree().get_first_node_in_group("player")
    if practice_player != null and bool(practice_player.get("ui_input_locked")):
        return
    salt_mark_timer = maxf(0.0, salt_mark_timer - delta)
    snare_timer = maxf(0.0, snare_timer - delta)
    trip_timer = maxf(0.0, trip_timer - delta)
    training_reset = maxf(0.0, training_reset - delta)
    if training_reset <= 0.0 and hp <= 0:
        hp = max_hp
        clear_salt_mark()
    modulate = Color("d6a75e") if snare_timer > 0.0 else (Color("e9e1bd") if salt_mark_timer > 0.0 else Color.WHITE)
    if String(name) == "seal_training_ward":
        guard_practice_clock += delta
        queue_redraw()
        if guard_practice_clock >= 2.0:
            guard_practice_clock = 0.0
            if practice_player != null and practice_player.global_position.distance_to(global_position) < 115.0 and practice_player.has_method("practice_guard_contact"):
                if practice_player.practice_guard_contact(global_position):
                    _report_guard_practice(practice_player)

func _draw() -> void:
    if String(name) == "seal_training_ward" and guard_practice_clock > 1.5:
        draw_line(Vector2(-44, -30), Vector2(44, -30), Color("f0ce83"), 3.0)
        draw_line(Vector2(-44, -30), Vector2(-32, -40), Color("f0ce83"), 3.0)

func take_hit(amount: int, _hit_direction: int) -> void:
    contact_ready=false
    if hp <= 0 or amount<=0:
        return
    hp = maxi(0, hp - maxi(0, amount))
    hit_count += 1
    training_reset = 1.5 if hp <= 0 else 0.0
    contact_ready=true;contact_frame=Engine.get_physics_frames()

## Contacts are reported explicitly by actual skill hit paths, never by damage alone.
func report_skill_contact(owner_player: Node, skill_id: String, serial: int) -> void:
    if not contact_ready or contact_frame!=Engine.get_physics_frames():return
    contact_ready=false
    var level:=get_parent()
    if level==null or level.get("player")!=owner_player:return
    level._on_skill_practice_hit(skill_id,self,serial,"skill")
    _refresh_practice_caption()

func _report_guard_practice(owner_player: Node) -> void:
    var level:=get_parent()
    if level==null or level.get("player")!=owner_player:return
    level._on_skill_practice_hit("ward",self,int(owner_player.last_skill_cast_serial),"guard")
    _refresh_practice_caption()

func _refresh_practice_caption() -> void:
    var label:=get_node_or_null("PracticeCaption") as Label
    var level:=get_parent()
    if label==null or level==null or not level.has_method("get_skill_practice_progress"):return
    var skill_id:=String(get_meta("practice_skill_id",""))
    var progress: Dictionary=level.get_skill_practice_progress(skill_id)
    var text:=String(label.get_meta("base_text",""))+"\n"
    if not progress.known:text+="先取得并装备这门线术。"
    elif progress.completed:text+="已练熟 · 可找工匠选择校习方向。"
    elif progress.pending_save:text+="练习达标，记录待写入；再次有效施放重试。"
    else:text+="本次练习 %d / %d；独立有效施放，同次多段只计一次。" % [int(progress.count),int(progress.required)]
    if label.text!=text:label.text=text
