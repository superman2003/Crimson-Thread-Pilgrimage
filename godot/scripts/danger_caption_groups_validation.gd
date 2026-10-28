extends SceneTree
const GROUPS := preload("res://scripts/danger_caption_groups.gd")
const HOST := preload("res://scripts/danger_caption_refresh_contract.gd")
var checks := 0
var failures := 0
class Player extends Node:
    var hp := 5
class Level extends Node:
    var player: Node
    var world_loading := false
    var active_overlay := ""
class UI extends Control:
    var accessibility := {"danger_captions":true,"danger_caption_limit":2,"subtitle_size":26}
    func get_accessibility(key: String, fallback: Variant) -> Variant:return accessibility.get(key,fallback)
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
    checks += 1
    if not ok:failures += 1;push_error(text)
func tell(id: int, text: String = "右侧 · 突进", rank: float = 12.0, unblockable: bool = false) -> Dictionary:
    return {"source":id,"text":text,"rank":rank,"unblockable":unblockable,"secret":"never display"}
func run() -> void:
    var input := [tell(3),tell(2),tell(1),tell(4,"左侧 · 不可格挡 · 重砸",0.0,true),tell(5,"上方 · 散射",14.0)]
    var snapshot := input.duplicate(true)
    var result := GROUPS.select(input,2)
    check(result.size()==2 and result[0].unblockable,"danger priority applies before the number of displayed groups")
    check(result[1].count==3 and result[1].source==1,"identical observed directions and tells combine with a stable source")
    check(not result[1].has("secret") and input==snapshot,"grouping is read only and publishes only explicit caption fields")
    check(GROUPS.select([tell(1),tell(1)],3)[0].count==1,"duplicate actor observations cannot inflate threat counts")
    check(GROUPS.select([tell(1),tell(2,"左侧 · 突进")],3).size()==2,"different directions remain separate")
    check(GROUPS.select([tell(1),tell(2,"右侧 · 突进",0,true)],3).size()==2,"unblockable and ordinary tells remain distinct")
    check(GROUPS.select([tell(1,"右侧 · 突进",15),tell(2,"右侧 · 突进",11)],3)[0].rank==11.0,"group urgency follows the most urgent observed member")
    for invalid in [null,{},true,tell(-1),tell(1,""),tell(1,"x",NAN),tell(1,"x",INF),{"source":true,"rank":1,"text":"x","unblockable":false}]:
        check(GROUPS.select([invalid],3).is_empty(),"invalid observations cannot create captions")
    check(GROUPS.select(input,0).size()==1 and GROUPS.select(input,99).size()==3,"caption count stays within the existing one-to-three setting")
    var many: Array=[]
    for id in 200:many.append(tell(id+1))
    check(GROUPS.select(many,3)[0].count==128,"grouping work and counts obey the existing observation budget")
    var labels: Array[Label]=[]
    for unused in 3:labels.append(Label.new())
    GROUPS.render(labels,result,26)
    check(labels[1].text.ends_with("×3") and not labels[2].visible,"native labels display a count without filling every row with the same warning")
    check(labels[0].get_theme_font_size("font_size")==26 and labels[0].get_theme_color("font_color")==GROUPS.COLORS[1],"subtitle size and danger color remain effective")
    GROUPS.render(labels,GROUPS.select([tell(8)],2),21)
    check(not labels[0].text.contains("×") and labels[1].text.is_empty(),"a single current threat has no stale count or hidden stale label text")
    for label in labels:label.free()
    _production_refresh()
    print("DANGER_CAPTION_GROUPS checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
func _production_refresh() -> void:
    var host := HOST.new()
    var level := Level.new()
    var ui := UI.new()
    var player := Player.new()
    root.add_child(host);root.add_child(level);level.add_child(player);level.player=player;root.add_child(ui)
    host.level=level;host.ui=ui;host.panel=PanelContainer.new();ui.add_child(host.panel)
    for unused in 3:
        var label := Label.new();host.panel.add_child(label);host.labels.append(label)
    host.surface.panel=host.panel
    host.surface.labels=host.labels
    var candidates: Array=[]
    for index in 4:
        var actor := Node.new();level.add_child(actor);candidates.append(actor)
        actor.set_meta("tell",tell(actor.get_instance_id(),"右侧 · 突进" if index<3 else "左侧 · 不可格挡 · 重砸",12.0 if index<3 else 0.0,index==3))
    host.refresh(candidates)
    check(host.rows.size()==2 and host.labels[1].text.ends_with("×3"),"exact production refresh method routes current observations through grouping and native labels")
    candidates[0].set_meta("tell",{})
    host.refresh(candidates)
    check(host.labels[1].text.ends_with("×2"),"interrupted observations disappear from the next frame count")
    level.active_overlay="bag";host.refresh(candidates)
    check(not host.panel.visible and host.rows.is_empty(),"opening a menu immediately removes all captions")
    level.active_overlay="";ui.accessibility.danger_captions=false;host.refresh(candidates)
    check(not host.panel.visible,"disabled captions do not retain an earlier warning")
    ui.accessibility.danger_captions=true;level.world_loading=true;host.refresh(candidates)
    check(not host.panel.visible,"region loading suppresses captions")
    host.free();level.free();ui.free()
