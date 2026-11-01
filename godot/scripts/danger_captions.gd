extends Node
## Captions are a view of the actor's current tell, never an encounter predictor.
const MAX_SCAN := 128
const MAX_DISTANCE := 620.0
const GROUPS := preload("res://scripts/danger_caption_groups.gd")
const TELLS := {"melee":"近身挥击","lunge":"突进","rush":"冲锋","fan":"散射","pool":"地面危险","dive":"俯冲","guard":"防守反击","combo":"连续挥击","wave":"地面波","vault":"跃击","mortar":"抛射","beam":"直线照射","rootline":"沿地蔓延","pulse":"范围震荡","projectile":"远程射击","throw":"投掷","slam":"重砸","sweep":"横扫"}
var surface:=preload("res://scripts/danger_caption_surface.gd").new()
var level: Node
var ui: Control
var panel: PanelContainer
var labels: Array[Label]=[]
var rows: Array=[]
var cursor:=0
var scanned:=0

func setup(world: Node,shell: Control) -> void:
    level=world;ui=shell
    var installed: Dictionary=surface.install(shell)
    if installed.is_empty():panel=null;labels=[];return
    panel=installed.panel;labels=installed.labels

func _exit_tree() -> void:
    surface.clear()

static func direction(delta: Vector2) -> String:
    if delta.length()<45:return "身侧"
    if absf(delta.y)>absf(delta.x)*1.3:return "上方" if delta.y<0 else "下方"
    return "左侧" if delta.x<0 else "右侧"

static func rank(unblockable: bool,boss: bool,remaining: float,distance: float) -> float:
    return (0.0 if unblockable else 10.0)+(0.0 if boss else 2.0)+clampf(remaining,0,5)*0.1+distance*0.0001

func observe(actor: Node) -> Dictionary:
    if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.get_script()!=preload("res://scripts/enemy_actor.gd"):return {}
    if actor.get_parent()!=level or not actor.is_inside_tree() or not actor.world_residency_active() or not actor.is_visible_in_tree():return {}
    if actor.dying or actor.hp<=0 or actor.state!="windup" or actor.active_attack.is_empty() or not is_finite(actor.state_timer) or actor.state_timer<=0:return {}
    if not is_instance_valid(actor.sprite) or not actor.sprite.is_visible_in_tree() or actor.modulate.a<0.1 or actor.sprite.modulate.a<0.1:return {}
    var point: Vector2=actor.global_position+Vector2(0,-40)
    var listener: Vector2=level.player.global_position+Vector2(0,-40)
    if not point.is_finite() or point.distance_to(listener)>MAX_DISTANCE:return {}
    var screen: Vector2=level.get_canvas_transform()*point
    if not level.get_viewport_rect().grow(-12).has_point(screen):return {}
    var ray:=PhysicsRayQueryParameters2D.create(listener,point,1,[level.player.get_rid(),actor.get_rid()]);ray.collide_with_areas=false
    if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():return {}
    var attack: Dictionary=actor.active_attack
    var unblockable: bool=attack.get("blockable",true)==false
    var text:="%s · %s%s" % [direction(point-listener),"不可格挡 · " if unblockable else "",String(TELLS.get(String(attack.get("type","")),"蓄力出招"))]
    # No species, room, spawn id or next move is exposed, even for known foes.
    return {"source":actor.get_instance_id(),"text":text,"unblockable":unblockable,"rank":rank(unblockable,actor.is_boss,actor.state_timer,point.distance_to(listener))}

func refresh(candidates: Array) -> void:
    rows=[];scanned=0
    if not is_instance_valid(panel) or panel.is_queued_for_deletion() or not is_instance_valid(ui) or ui.is_queued_for_deletion():return
    if not is_instance_valid(level) or not is_instance_valid(level.player) or level.player.hp<=0 or level.world_loading or not level.active_overlay.is_empty() or ui.get_accessibility("danger_captions",false)!=true:
        surface.hide();return
    var seen: Dictionary={}
    if not candidates.is_empty():
        for offset in mini(MAX_SCAN,candidates.size()):
            var index: int=(cursor+offset)%candidates.size();scanned+=1
            var candidate: Node=candidates[index]
            if not is_instance_valid(candidate) or seen.has(candidate.get_instance_id()):continue
            seen[candidate.get_instance_id()]=true
            var row:=observe(candidate)
            if not row.is_empty():rows.append(row)
        cursor=(cursor+MAX_SCAN)%candidates.size()
    var preferences:=preload("res://scripts/controller_preferences.gd").normalize(ui.accessibility)
    rows=GROUPS.select(rows,int(preferences.danger_caption_limit))
    surface.apply(preferences)
    GROUPS.render(labels,rows,int(preferences.subtitle_size))
    panel.visible=not rows.is_empty()

func _process(_delta: float) -> void:
    refresh(get_tree().get_nodes_in_group("enemy"))
