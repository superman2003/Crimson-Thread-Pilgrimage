extends SceneTree
const MODEL = preload("res://scripts/settings_profiles.gd")
const CODEC = preload("res://scripts/settings_profile_codec.gd")
var checks := 0
var failures := 0
class Shell extends Control:
    const REMAPPABLE_ACTIONS := {"heal":"疗伤"}
    var accessibility := {}
    var accessibility_path := "user://profile.cfg"
    var applied := 0
    var refreshed := 0
    func _apply_accessibility() -> void:applied+=1
    func _refresh_remap_labels() -> void:refreshed+=1
class Reject extends "res://scripts/settings_persistence.gd":
    func _install(_source: String,_target: String) -> Error:return ERR_CANT_CREATE
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func run() -> void:
    if not InputMap.has_action("heal"):InputMap.add_action("heal")
    var key:=InputEventKey.new();key.physical_keycode=KEY_H;InputMap.action_add_event("heal",key)
    var shell:=Shell.new();root.add_child(shell);shell.accessibility=MODEL.values({})
    var model:=MODEL.new();var saved:=model.capture(shell);saved.values.subtitle_size=26
    saved.values.controller_deadzone=.43
    model.profiles={"test":saved}
    var original:=ConfigFile.new();original.set_value("other","keep",7);original.save(shell.accessibility_path)
    var bytes:=FileAccess.get_file_as_bytes(shell.accessibility_path)
    model.preference_writer=Reject.new()
    check(not model.apply("test",shell,1,saved).ok,"fallback install failure exposed")
    check(shell.accessibility.subtitle_size==21 and shell.applied==0,"failed write never applies live values")
    check(FileAccess.get_file_as_bytes(shell.accessibility_path)==bytes,"failed apply keeps original bytes")
    check(InputMap.action_get_events("heal")[0].physical_keycode==KEY_H,"failed apply keeps input")
    model.preference_writer=preload("res://scripts/settings_persistence.gd").new()
    for scope in [1,2,3,0]:
        var before:=shell.applied
        var result:=model.apply("test",shell,scope,saved)
        check(result.ok,"native apply scope %d"%scope)
        check(shell.applied==before+1 and shell.refreshed==shell.applied,"one live commit per success")
        var loaded:=ConfigFile.new();check(loaded.load(shell.accessibility_path)==OK,"committed file readable")
        check(loaded.get_value("other","keep")==7,"preserves unrelated section")
    check(shell.accessibility.subtitle_size==26 and shell.accessibility.controller_deadzone==.43,"visual and controller scope applied")
    var stale:=saved.duplicate(true);stale.values.subtitle_size=17
    check(not model.apply("test",shell,0,stale).ok,"stale profile quote still refused")
    model.apply_writer=func(_cfg: ConfigFile,_path: String):return ERR_UNAUTHORIZED
    var count:=shell.applied
    check(not model.apply("test",shell,0,saved).ok and shell.applied==count,"injected writer failure also atomic")
    shell.free()
    print("RELIABILITY_R02 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
