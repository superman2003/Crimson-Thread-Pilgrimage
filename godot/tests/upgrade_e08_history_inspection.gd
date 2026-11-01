extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func finish() -> void:
    for failure in failures:push_error(failure)
    print("UPGRADE_%s checks=%d failures=%d" % [get_script().resource_path.get_file().get_basename(),checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
func photograph() -> void:
    var target:=OS.get_environment("UPGRADE_CAPTURE")
    if target.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(target)
const PROP=preload("res://scripts/scene_history_prop.gd")
class Host extends Node2D:
    var active_overlay:=""
    var current_room_id:="room"
    var chosen: Area2D
    func interaction_target(_candidate=null):return chosen
func run() -> void:
    var host:=Host.new();root.add_child(host)
    var prop:=PROP.new();prop.entry={"title":"旧钟模","look":"bell_mold","role":"daily"};prop.position=Vector2(180,100);host.add_child(prop)
    check(prop.inspection_text()=="观察旧物","unread cue does not reveal authored title")
    host.chosen=prop;prop._process(0)
    check(prop.inspection_caption.visible and prop.inspection_focused,"actual selected prop shows inspection cue")
    prop.mark_seen()
    check(prop.inspection_text().contains("旧钟模") and prop.inspection_text().contains("已记下"),"recorded cue shows remembered title")
    host.active_overlay="dialogue";prop._process(0)
    check(not prop.inspection_caption.visible and not prop.inspection_focused,"reading overlay hides exploration caption")
    var player:=CharacterBody2D.new();player.position=Vector2(100,142);host.add_child(player)
    var wall:=StaticBody2D.new();var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(12,12);shape.shape=box;wall.add_child(shape);wall.position=Vector2(130,126);host.add_child(wall)
    await physics_frame;await physics_frame
    check(prop.accessible_from(player),"low floor lip does not block chest-level reading")
    wall.position=Vector2(140,100);await physics_frame;await physics_frame
    check(not prop.accessible_from(player),"wall across reading sightline blocks interaction")
    wall.free();player.position=Vector2(800,142)
    check(not prop.accessible_from(player),"far prop cannot be read")
    player.position=Vector2(100,142);prop.hide()
    check(not prop.accessible_from(player),"hidden prop cannot be read")
    host.free();await process_frame;finish()
