extends CanvasLayer
## Six gatekeepers back to back, on the clock. Each stage is the existing boss
## trial (a region loaded straight at its gatekeeper with that region's fixed
## kit), so every run fights under the same conditions and times compare.
const TYPE := preload("res://scripts/ui_type_scale.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const STAGES: Array[String] = [
    "res://data/demo_ch01_moss_bell_court.json", "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json", "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json", "res://data/demo_ch06_silent_crown_core.json",
]
const QUIT_HOLD := 1.2
signal finished(result: Dictionary)
var stages: Array[String] = STAGES
var store := preload("res://scripts/journey_desk_store.gd").new()
var label: Label
var stage := -1
var scene: Node
var fighting := false
var elapsed := 0.0
var splits: Array[float] = []
var quit_held := 0.0
var done := false
## Validation hooks: production loads the real scenes.
var make_stage: Callable
var make_world: Callable

## Offered once every gatekeeper has been beaten in some journey.
static func available() -> bool:
    var record:=preload("res://scripts/achievements.gd").new()
    record.load()
    return record.unlocked.has("all_gatekeepers")

static func clock_text(seconds: float) -> String:
    var tenths:=int(floor(maxf(seconds,0.0)*10.0))
    return "%d:%02d.%d" % [tenths/600,(tenths/10)%60,tenths%10]

func best() -> float:
    store.configure("boss_rush","installation")
    var saved:=store.read()
    var value: Variant=saved.get("best_seconds")
    if saved.size()==1 and typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0.0:return float(value)
    if not saved.is_empty():store.writable=false
    return 0.0

## Replace `world` with the first stage. The journey was saved by the caller.
func begin(world: Node) -> void:
    name="BossRush";layer=58;process_mode=Node.PROCESS_MODE_ALWAYS
    if not make_stage.is_valid():
        make_stage=func(path: String):
            var level: Node=load("res://scenes/Main.tscn").instantiate()
            level.config_path=path;level.world_mode=false;level.boss_trial_mode=true
            return level
    if not make_world.is_valid():
        make_world=func():
            var level: Node=load("res://scenes/World.tscn").instantiate()
            level.world_startup_options_enabled=false
            return level
    label=Label.new();label.name="Clock";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    label.offset_left=-220;label.offset_right=220;label.offset_top=96;label.offset_bottom=124
    label.add_theme_font_size_override("font_size",TYPE.TITLE);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(label)
    var host:=world.get_parent()
    host.add_child(self)
    _swap(world,null)
    _next()

func _swap(old: Node, new: Node) -> void:
    var tree:=get_tree()
    if is_instance_valid(old):
        RETIRE.retire_tree(old)
        old.get_parent().remove_child(old);old.queue_free()
    scene=new
    if new!=null:
        get_parent().add_child(new);tree.current_scene=new

func _next() -> void:
    fighting=false;stage+=1
    if stage>=stages.size():
        _finish(true);return
    _swap(scene,make_stage.call(stages[stage]))
    _refresh()

func _process(delta: float) -> void:
    if done:return
    var esc:=Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_joy_button_pressed(0,JOY_BUTTON_BACK)
    quit_held=quit_held+delta if esc else 0.0
    if quit_held>=QUIT_HOLD:
        _finish(false);return
    if not is_instance_valid(scene):return
    if not fighting:
        # The clock starts when the gatekeeper stands in the arena, not while loading.
        var boss: Variant=scene.get("boss_actor")
        if boss is Node and is_instance_valid(boss):fighting=true
        _refresh();return
    if bool(scene.get("demo_complete")):
        splits.append(elapsed);_next();return
    if not get_tree().paused:elapsed+=minf(delta,0.25)
    _refresh()

func _refresh() -> void:
    if label==null:return
    label.text="%d / %d · %s" % [mini(stage+1,stages.size()),stages.size(),clock_text(elapsed)]

func _finish(cleared: bool) -> void:
    done=true;fighting=false
    var previous:=best()
    var improved:=cleared and (previous<=0.0 or elapsed<previous)
    var record:=improved and store.writable and store.write({"best_seconds":elapsed})
    var unsaved:=improved and not record
    var result:={"cleared":cleared,"seconds":elapsed,"splits":splits.duplicate(),"best":elapsed if record else previous,"record":record}
    _swap(scene,make_world.call())
    label.visible=false
    var window:=AcceptDialog.new();window.name="Result";window.title="首领连战"
    window.process_mode=Node.PROCESS_MODE_ALWAYS
    window.dialog_text=("用时 %s%s" % [clock_text(elapsed),"　新纪录" if record else ("　未能保存纪录。"+store.error if unsaved else ("　最佳 "+clock_text(previous) if previous>0.0 else ""))]) if cleared else "已退出连战。"
    add_child(window)
    var close:=func():
        finished.emit(result);queue_free()
    window.confirmed.connect(close);window.canceled.connect(close)
    window.popup_centered()
