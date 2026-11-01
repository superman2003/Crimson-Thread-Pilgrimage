extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
var checks:=0
var failures:=0
var writes:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func disk(path: String) -> Dictionary:
    return {"exists":FileAccess.file_exists(path),"bytes":FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://settings_comparison_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:await physics_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"fixture saves real gameplay before comparison")
    world._toggle_audio_settings();var ui: Control=world.ui_shell
    ui.settings.get_node("SettingsProfilesButton").pressed.emit();await process_frame
    var desk: Node=ui.get_node("SettingsProfilesDesk")
    desk.model.configure("comparison_world")
    var a: Dictionary=desk.model.capture(ui)
    var b:=a.duplicate(true);b.values.subtitle_size=26 if a.values.subtitle_size!=26 else 17
    var event:=InputEventKey.new();event.physical_keycode=KEY_J;event.shift_pressed=true
    b.bindings.attack=[CODEC.encode(event)]
    check(desk.model.manage("save","","甲方案",a).ok and desk.model.manage("save","","乙方案",b).ok,"two genuine saved records seed isolated profile scope")
    desk.refresh()
    var profiles: Dictionary=desk.model.profiles.duplicate(true)
    var profile_disk:=disk(desk.model.store.path)
    var settings_disk:=disk(ui.accessibility_path)
    var game_disk:=disk(world.world_save_path)
    var current: Dictionary=ui.accessibility.duplicate(true)
    var bindings:=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    var wallet: String=var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.global_position])
    desk.model.store.writer=func(_data: Dictionary):writes+=1;return ERR_CANT_CREATE
    desk.model.apply_writer=func(_config: ConfigFile,_path: String):writes+=1;return ERR_CANT_CREATE
    var launcher:=desk.window.find_child("CompareSavedSettings",true,false) as Button
    check(launcher!=null and launcher.is_visible_in_tree(),"actual profile window exposes comparison launcher")
    launcher.grab_focus();launcher.pressed.emit();await process_frame
    var dialog: Node=desk.comparison
    check(dialog.visible and dialog.left.has_focus(),"nested comparison opens with keyboard focus")
    check(world.active_overlay=="settings" and world.player.ui_input_locked,"comparison keeps settings input ownership")
    check(dialog.names.size()==2 and dialog.left.selected!=dialog.right.selected,"two records are initially compared without applying either")
    check(dialog.detail.text.contains("字幕字号") and dialog.detail.text.contains("普攻"),"actual differences contain canonical setting and action names")
    var old_left: int=dialog.left.selected;var old_right: int=dialog.right.selected
    dialog.swap_sides()
    check(dialog.left.selected==old_right and dialog.right.selected==old_left,"swap changes both selected record identities")
    dialog.scope.select(3);dialog.scope.item_selected.emit(3)
    check(not dialog.detail.text.contains("字幕字号"),"controller-only view omits setting differences")
    dialog.only_changes.button_pressed=false;dialog.only_changes.toggled.emit(false)
    check(dialog.detail.text.contains("相同"),"same controller values are explicitly inspectable")
    dialog.scope.select(0);dialog.query.text="字幕字号";dialog.query.text_changed.emit(dialog.query.text)
    check(dialog.detail.text.contains("字幕字号") and not dialog.detail.text.contains("普攻"),"search narrows the saved pair rather than current live bindings")
    dialog.query.text="没有这条";dialog.query.text_changed.emit(dialog.query.text)
    check(dialog.detail.text.contains("没有符合筛选"),"empty search clears old detail instead of showing stale difference")
    desk.model.profiles["甲方案"].values.subtitle_size=19
    dialog.render()
    check(dialog.stale and dialog.detail.text.contains("重新读取"),"changed stored snapshot invalidates previous comparison")
    dialog.refresh();check(not dialog.stale,"explicit reload accepts updated saved snapshot")
    desk.model.profiles=profiles.duplicate(true);dialog.refresh()
    check(desk.model.profiles==profiles and writes==0,"all comparison actions perform zero persistence or application calls")
    check(ui.accessibility==current and CODEC.capture(ui.REMAPPABLE_ACTIONS)==bindings,"comparison preserves live preferences and complete InputMap")
    check(disk(desk.model.store.path)==profile_disk and disk(ui.accessibility_path)==settings_disk and disk(world.world_save_path)==game_disk,"profile preferences and gameplay files retain exact existence and bytes")
    check(var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.global_position])==wallet,"comparison preserves actual gameplay resources and position")
    desk.window.hide();await process_frame
    check(not dialog.visible and dialog.snapshot.is_empty() and dialog.detail.text.is_empty(),"parent close retires saved values and text")
    dialog.refresh();dialog.render();check(dialog.snapshot.is_empty(),"hidden stale callbacks cannot repopulate closed comparison")
    desk.open();desk.open_comparison();await process_frame
    check(dialog.visible and dialog.query.text.is_empty() and dialog.scope.selected==0 and dialog.only_changes.button_pressed,"reopening starts with safe fresh comparison filters")
    world._close_overlays();await process_frame
    check(not dialog.visible and not world.player.ui_input_locked,"settings close retires nested comparison and returns input")
    var profile_path: String=desk.model.store.path
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    for path in [profile_path,"user://settings_comparison_world.json"]:
        for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
    print("SETTINGS_COMPARISON_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
