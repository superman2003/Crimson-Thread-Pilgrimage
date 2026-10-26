extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:failures.append(message)
func finish() -> void:
    for message in failures:push_error(message)
    print("UPGRADE_E01 checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
const PINS = preload("res://scripts/map_player_pins.gd")
const UI = preload("res://scripts/map_player_pins_runtime.gd")
const JOURNAL = preload("res://scripts/pilgrimage_cartography.gd")
func run() -> void:
    root.gui_embed_subwindows=true
    root.size=Vector2i(1280,720)
    var config:={"map_rooms":[{"id":"hall","layout_rect":[0,0,1000,600]}]}
    var flags:={};var configs:={"test":config}
    JOURNAL.region(flags,"test").owned=true;JOURNAL.region(flags,"test").charted.hall=true
    var added:=PINS.add(flags,configs,"test",Vector2(50,50),"goal")
    flags[PINS.KEY]=added.records
    var old: Dictionary=PINS.records(flags,configs)[0].duplicate(true)
    var before:=flags.duplicate(true)
    var edit:=PINS.edit(flags,configs,1,"return","  回来取材料  ",old)
    check(edit.ok and edit.records[0].label=="回来取材料" and edit.records[0].kind=="return","label/type edit is normalized")
    check(flags==before and edit.records[0].position==old.position and edit.records[0].id==old.id,"candidate preserves identity/position and caller state")
    for label in [true,"x".repeat(25),"a\nb","a\tb"]:check(not PINS.edit(flags,configs,1,"goal",label).ok,"invalid label rejects atomically")
    check(not PINS.edit(flags,configs,1,"fake","x").ok and not PINS.edit(flags,configs,9,"goal","x").ok,"bad kind and missing pin reject")
    flags[PINS.KEY]=edit.records
    check(not PINS.edit(flags,configs,1,"goal","x",old).ok,"stale editor cannot overwrite another edit")
    check(PINS.records(flags,configs)[0].label=="回来取材料","normalized annotation reads back")
    flags[PINS.KEY][0].label=true
    check(PINS.records(flags,configs).size()==1 and PINS.records(flags,configs)[0].label=="","malformed optional label does not destroy usable pin")
    var level: Node=load("res://scenes/World.tscn").instantiate()
    level.world_resume=false;level.world_save_path="user://upgrade_e01.json";root.add_child(level)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
    level.set_process(false);level.player.set_physics_process(false)
    var region:=String(level.config.id);var room:=PINS.owner(level.config,level.player.global_position)
    JOURNAL.region(level.story_flags,region).owned=true;JOURNAL.region(level.story_flags,region).charted[String(room.id)]=true
    level._toggle_map();check(UI.add_current(level).ok,"real map durable transaction adds pin")
    var list: OptionButton=level.map_panel.get_node("PlayerPinToolbar/PinList");list.select(1)
    UI.edit_selected(level)
    var popup: ConfirmationDialog=level.map_panel.get_node_or_null("PinEditor")
    check(popup!=null and popup.visible and popup.get_cancel_button().has_focus(),"real editor opens with cancel focus")
    await capture_if_requested()
    popup.get_node("Fields/PinLabel").text="回灯处"
    popup.get_node("Fields/PinType").select(2);popup.confirmed.emit()
    await process_frame
    check(PINS.records(level.story_flags,UI.configurations(level))[0].label=="回灯处","real editor publishes saved annotation")
    var disk:=preload("res://scripts/world_state.gd").new()
    check(disk.read(level.world_save_path) and disk.data.story_flags[PINS.KEY][0].label=="回灯处","real world file contains exact annotation")
    UI.edit_selected(level);level._close_overlays();await process_frame
    check(level.map_panel.get_node_or_null("PinEditor")==null,"closing map retires editor")
    level.free();await process_frame
    await preload("res://scripts/audio_retirement.gd").drain(self)
    finish()

func capture_if_requested() -> void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await process_frame
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))
