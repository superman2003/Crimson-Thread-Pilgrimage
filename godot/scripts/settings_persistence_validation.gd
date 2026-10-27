extends SceneTree
const STORE = preload("res://scripts/settings_persistence.gd")
const UI = preload("res://scripts/pilgrimage_interface.gd")
const FIXTURE = preload("res://scripts/build_slots_ui_validation.gd")
const PATH := "user://settings_persistence_fixture.cfg"
var checks := 0
var failures := 0

class WriteFailure extends "res://scripts/settings_persistence.gd":
    func _write(_config: ConfigFile, _path: String) -> Error: return ERR_UNAUTHORIZED

class VerificationFailure extends "res://scripts/settings_persistence.gd":
    func _verified(_config: ConfigFile, _path: String) -> bool: return false

class InstallFailure extends "res://scripts/settings_persistence.gd":
    func _install(_temporary: String, _path: String) -> Error: return ERR_CANT_CREATE

class WrongContent extends "res://scripts/settings_persistence.gd":
    func _write(_config: ConfigFile, path: String) -> Error:
        var different:=ConfigFile.new()
        different.set_value("accessibility","subtitle_size",20)
        return different.save(path)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL SETTINGS_PERSISTENCE: " + label)

func config(size: int = 21) -> ConfigFile:
    var value:=ConfigFile.new()
    value.set_value("accessibility","subtitle_size",size)
    value.set_value("accessibility","navigation_assist",false)
    var event:=InputEventKey.new()
    event.physical_keycode=KEY_H
    event.device=-1
    value.set_value("bindings","heal",[event])
    value.set_value("other_feature","note","retain this section")
    return value

func cleanup() -> void:
    for suffix in ["", ".pending.tmp"]:
        var file:=ProjectSettings.globalize_path(PATH+suffix)
        if FileAccess.file_exists(file):DirAccess.remove_absolute(file)

func filesystem_checks() -> void:
    cleanup()
    var first:=config()
    var store:=STORE.new()
    check(store.save(first,PATH)==OK, "real ConfigFile roundtrip and atomic install succeed")
    check(not store.pending and store.last_error==OK and store.attempts==1, "successful state has no pending warning")
    check(not FileAccess.file_exists(PATH+".pending.tmp"), "successful install leaves no temporary file")
    var old:=FileAccess.get_file_as_bytes(PATH)
    var candidate:=config(26)
    for broken in [WriteFailure.new(), VerificationFailure.new(), InstallFailure.new(), WrongContent.new()]:
        var code: Error=broken.save(candidate,PATH)
        check(code!=OK and broken.pending, "each actual write stage exposes a pending failure")
        check(FileAccess.get_file_as_bytes(PATH)==old, "failed stage preserves previous settings bytes")
        check(not FileAccess.file_exists(PATH+".pending.tmp"), "failed stage removes only staged settings")
        check(broken.message().contains("尚未保存"), "failure has persistent human-readable status")
    check(store.save(candidate,PATH)==OK, "retry installs latest candidate")
    check(FileAccess.get_file_as_bytes(PATH)!=old, "retry actually changes persisted settings")
    var loaded:=ConfigFile.new()
    check(loaded.load(PATH)==OK and loaded.get_value("accessibility","subtitle_size")==26, "newly loaded process sees actual new value")
    var events: Array=loaded.get_value("bindings","heal",[])
    check(events.size()==1 and events[0] is InputEventKey and events[0].physical_keycode==KEY_H, "native input event survives verified roundtrip")
    var mouse:=InputEventMouseButton.new()
    mouse.button_index=MOUSE_BUTTON_XBUTTON1
    var controller:=InputEventJoypadButton.new()
    controller.button_index=JOY_BUTTON_A
    var trigger:=InputEventJoypadMotion.new()
    trigger.axis=JOY_AXIS_TRIGGER_RIGHT
    trigger.axis_value=1.0
    candidate.set_value("bindings","all_devices",[events[0],mouse,controller,trigger])
    check(store.save(candidate,PATH)==OK, "native mouse/button/axis event serialization verifies deterministically")
    loaded.load(PATH)
    var devices: Array=loaded.get_value("bindings","all_devices")
    check(devices.size()==4 and devices[1] is InputEventMouseButton and devices[2] is InputEventJoypadButton and devices[3] is InputEventJoypadMotion, "all supported device events survive actual disk read")
    check(devices[1].button_index==MOUSE_BUTTON_XBUTTON1 and devices[2].button_index==JOY_BUTTON_A and devices[3].axis==JOY_AXIS_TRIGGER_RIGHT, "event-specific fields survive atomic replacement")
    candidate.set_value("accessibility","controller_deadzone",.43000000000000005)
    check(store.save(candidate,PATH)==OK, "stepped calibration survives native parser last-bit rounding")
    check(not store._same(.43,.43001), "meaningful numeric changes remain invalid")
    check(not store._same(NAN,NAN) and not store._same(INF,INF), "non-finite values never verify")
    var changed_axis:=trigger.duplicate() as InputEventJoypadMotion
    changed_axis.axis_value=-1.0
    check(not store._same(trigger,changed_axis), "input axis polarity must match exactly")
    var changed_key:=events[0].duplicate() as InputEventKey
    changed_key.physical_keycode=KEY_J
    check(not store._same(events[0],changed_key), "native binding fields cannot change during verification")
    var pending:=InstallFailure.new()
    pending.save(config(17),PATH)
    pending.reconcile(candidate,PATH)
    check(not pending.pending and pending.last_error==OK, "another successful settings path can satisfy pending state")
    pending.save(config(17),PATH)
    pending.reconcile(config(17),PATH)
    check(pending.pending, "different on-disk preferences cannot clear the warning")

func make_runtime() -> Node:
    var runtime:=FIXTURE.MockRuntime.new()
    runtime.player=FIXTURE.MockPlayer.new()
    runtime.add_child(runtime.player)
    runtime.build_system=FIXTURE.MockBuild.new()
    runtime.world_narrative=FIXTURE.MockNarrative.new()
    root.add_child(runtime)
    return runtime

func ui_checks() -> void:
    cleanup()
    check(config().save(PATH)==OK, "native UI fixture begins with real persisted settings")
    var runtime:=make_runtime()
    var ui:=UI.new()
    runtime.add_child(ui)
    ui.accessibility_path=PATH
    ui.bind(runtime)
    ui.set_process(false)
    runtime.active_overlay="settings"
    ui.settings.show()
    check(not ui.settings_save_notice.visible and not ui.settings_save_retry.visible, "saved screen has no false pending notice")
    var before:=FileAccess.get_file_as_bytes(PATH)
    var wallet: Array=[runtime.currency_count,runtime.inventory_counts.duplicate(true),runtime.build_system.state.duplicate(true)]
    ui.settings_persistence=InstallFailure.new()
    var slider: HSlider=ui.accessibility_controls.subtitle_size.slider
    slider.value=26
    check(ui.accessibility.subtitle_size==26 and runtime.player.get_meta("accessibility").subtitle_size==26, "failed save leaves chosen live accessibility usable")
    check(FileAccess.get_file_as_bytes(PATH)==before, "actual slider cannot corrupt previous file on failed replacement")
    check(ui.settings_save_notice.visible and ui.settings_save_retry.visible, "failure remains visible after ordinary transient toast")
    check(ui.settings_save_notice.text.contains("尚未保存"), "pending state is distinct from success")
    ui.toast.text=""
    ui.toast_age=100
    ui._refresh_settings_save_notice()
    check(ui.settings_save_notice.visible, "toast expiration does not hide pending state")
    var pending_rect:=Rect2(ui.settings_save_notice.position,ui.settings_save_notice.size)
    var retry_rect:=Rect2(ui.settings_save_retry.position,ui.settings_save_retry.size)
    check(not pending_rect.intersects(retry_rect), "save status and retry control do not overlap")
    check(pending_rect.end.y<=retry_rect.position.y, "pending status stays above retry and remapping controls")
    check(retry_rect.position.x>=245 and retry_rect.end.x<=480, "retry stays clear of comfort button and right settings column")
    check(ui._is_navigable_focus(ui.settings_save_retry), "retry supports keyboard/controller focus")
    ui.settings_save_retry.grab_focus()
    var attempts: int=ui.settings_persistence.attempts
    ui.settings_save_retry.pressed.emit()
    check(ui.settings_persistence.attempts==attempts+1 and ui.settings_save_notice.visible, "failed native retry remains retryable")
    ui.accessibility.subtitle_speed=1.5
    if not InputMap.has_action("heal"):InputMap.add_action("heal")
    InputMap.action_erase_events("heal")
    var latest_key:=InputEventKey.new()
    latest_key.physical_keycode=KEY_J
    InputMap.action_add_event("heal",latest_key)
    ui.settings_persistence=STORE.new()
    ui.settings_save_retry.pressed.emit()
    check(not ui.settings_save_notice.visible and not ui.settings_save_retry.visible, "successful retry clears both warning and action")
    var loaded:=ConfigFile.new()
    loaded.load(PATH)
    check(loaded.get_value("accessibility","subtitle_size")==26 and is_equal_approx(float(loaded.get_value("accessibility","subtitle_speed")),1.5), "retry saves latest values rather than the first failed candidate")
    var saved_bindings: Array=loaded.get_value("bindings","heal",[])
    check(saved_bindings.size()==1 and saved_bindings[0].physical_keycode==KEY_J, "retry saves latest remapped input rather than original failed snapshot")
    check(loaded.get_value("other_feature","note")=="retain this section", "saving panel preserves unrelated preference sections")
    check(ui.get_viewport().gui_get_focus_owner()!=ui.settings_save_retry and ui._is_navigable_focus(ui.get_viewport().gui_get_focus_owner()), "successful hidden retry returns focus to visible settings")
    check([runtime.currency_count,runtime.inventory_counts,runtime.build_system.state]==wallet, "save/retry cannot change game resources or equipment")
    ui.settings_persistence=InstallFailure.new()
    ui.accessibility.subtitle_size=17
    ui._save_accessibility()
    ui.settings.hide()
    ui.settings.show()
    check(ui.settings_save_notice.visible, "closing and reopening settings preserves pending warning")
    var native:=STORE.new()
    native.save(ui._accessibility_config(),PATH)
    ui._apply_accessibility()
    check(not ui.settings_save_notice.visible, "successful alternate settings writer reconciles pending state")
    var writes: int=ui.settings_persistence.attempts
    ui.queue_free()
    check(ui._save_accessibility()==ERR_UNAVAILABLE and ui.settings_persistence.attempts==writes, "queued old UI cannot overwrite newer preferences")
    runtime.queue_free()
    await process_frame
    await process_frame
    cleanup()

func run() -> void:
    filesystem_checks()
    await ui_checks()
    print("SETTINGS_PERSISTENCE checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
