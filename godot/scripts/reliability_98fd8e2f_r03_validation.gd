extends SceneTree
const MODEL=preload("res://scripts/settings_profiles.gd")
const CODEC=preload("res://scripts/settings_profile_codec.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    if not InputMap.has_action("heal"):InputMap.add_action("heal")
    var key:=InputEventKey.new();key.physical_keycode=KEY_H;InputMap.action_add_event("heal",key)
    var event:=CODEC.encode(key)
    var good:={"values":MODEL.values({}),"bindings":{"heal":[event]}}
    check(MODEL.profile_error(good).is_empty(),"valid native profile")
    var bads: Array=[null,{}, {"values":[],"bindings":{}}, {"values":{},"bindings":{}}]
    for key_name in ["subtitle_size","flash_enabled","unknown"]:
        var invalid:=good.duplicate(true);invalid.values[key_name]="wrong";bads.append(invalid)
    var duplicate:=good.duplicate(true);duplicate.bindings.heal.append(event);bads.append(duplicate)
    var unknown:=event.duplicate();unknown.extra=1
    check(CODEC.decode(unknown)==null,"unknown event field refused")
    var malformed:=good.duplicate(true);malformed.bindings.heal=[unknown];bads.append(malformed)
    for bad in bads:check(not MODEL.profile_error(bad).is_empty(),"malformed profile refused")
    check(not CODEC.restore(duplicate.bindings,{"heal":"疗伤"}).ok,"duplicate inputs refused by application codec")
    var model:=MODEL.new();model.configure("r03")
    var raw:={"good":good,"broken":malformed}
    check(model.store.write({"profiles":raw}),"actual mixed file written")
    model.configure("r03")
    check(model.profiles.has("good") and not model.profiles.has("broken"),"good profile available without broken row")
    check(model.rejected_profiles.has("broken") and not model.rejected_summary().is_empty(),"bad row retained and explained")
    check(not model.manage("save","","broken",good).ok,"bad row name cannot be overwritten silently")
    check(model.manage("copy","good","copied").ok,"valid profile management remains usable")
    var after:=model.store.read()
    check(after.profiles.broken==model.rejected_profiles.broken,"management retains exact rejected entry")
    check(after.profiles.has("copied") and after.profiles.has("good"),"good records persisted alongside rejected record")
    var bytes:=FileAccess.get_file_as_bytes(model.store.path)
    check(model.rejected_profiles.size()==1,"quarantine count stable")
    check(FileAccess.get_file_as_bytes(model.store.path)==bytes,"inspection is read only")
    print("RELIABILITY_R03 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
