extends SceneTree
const LIB:=preload("res://scripts/expedition_draft_library.gd")
var checks:=0
var failures:=0
class Storage extends RefCounted:
    var accept:=true
    var error:="fixture itinerary write failed"
    var saved: Dictionary={}
    func write(candidate: Dictionary) -> bool:
        if not accept:return false
        saved=candidate.duplicate(true);return true
class Plan extends RefCounted:
    var state:={"stops":["room:b:2"],"done":["room:b:2"],"deferred":[],"active":true}
    var store:=Storage.new()
class Fault extends "res://scripts/settings_persistence.gd":
    var fail:=true
    func _install(temporary: String, path: String) -> Error:
        return ERR_CANT_CREATE if fail else super._install(temporary,path)
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var known: Array=[{"key":"room:a:1","title":"第一处","region_name":"已知地区"},{"key":"room:b:2","title":"第二处","region_name":"已知地区"}]
    var current:={"stops":["room:a:1","room:b:2"],"done":["room:a:1"],"deferred":["room:b:2"],"active":true}
    var before:=current.duplicate(true)
    var model:=LIB.new();model.configure("route_contract")
    check(model.drafts.is_empty() and model.writable,"new slot has no invented drafts")
    check(model.save_new("巡查",current,known).ok,"real verified file writer saves a named station order")
    check(current==before and model.drafts["巡查"]==current.stops,"library saves only order and never changes borrowed live plan")
    var bytes:=FileAccess.get_file_as_bytes(model.path)
    check(not FileAccess.get_file_as_string(model.path).contains("deferred"),"draft file excludes completion, deferral and activity state")
    check(not model.save_new("巡查",current,known).ok,"duplicate name does not silently overwrite")
    for name in [""," leading","trailing ","x\ny","x".repeat(25)]:check(not model.save_new(name,current,known).ok,"invalid name is rejected before persistence")
    for stops in [[],["room:a:1","room:a:1"],["unknown"],["room:private:9"]]:
        check(not model.save_new("新草案",{"stops":stops},known).ok,"empty, duplicate, malformed or undisclosed stops are refused")
    check(FileAccess.get_file_as_bytes(model.path)==bytes,"all rejected saves keep original file bytes")
    var reload:=LIB.new();reload.configure("route_contract")
    check(reload.drafts==model.drafts,"fresh library instance reads actual saved order")
    var other:=LIB.new();other.configure("different_route_slot")
    check(other.path!=model.path and other.drafts.is_empty(),"slot identity isolates libraries")
    var plan:=Plan.new();var plan_before:=plan.state.duplicate(true)
    var quote:=model.quote_restore("巡查",plan.state,known)
    check(quote.ok and quote.labels==["已知地区 · 第一处","已知地区 · 第二处"],"quote contains only currently public names in stored order")
    check(plan.state==plan_before and plan.store.saved.is_empty(),"preview does not publish or persist a plan")
    quote.candidate.stops.clear()
    check(model.restore("巡查",String(quote.fingerprint),plan,known).ok and plan.state.stops==current.stops,"apply recomputes candidate instead of trusting modified preview payload")
    check(not plan.state.active and plan.state.done.is_empty() and plan.state.deferred.is_empty(),"restoring explicitly resets progress and pauses itinerary")
    check(plan.store.saved==plan.state and FileAccess.get_file_as_bytes(model.path)==bytes,"restore writes itinerary only, never its library or gameplay save")
    quote=model.quote_restore("巡查",plan.state,known);plan.state.active=true
    var changed:=plan.state.duplicate(true)
    check(not model.restore("巡查",String(quote.fingerprint),plan,known).ok and plan.state==changed,"changed active plan invalidates previous confirmation")
    quote=model.quote_restore("巡查",plan.state,known)
    check(not model.restore("巡查",String(quote.fingerprint),plan,known.slice(0,1)).ok,"loss of disclosed station prevents restoring stale route")
    quote=model.quote_restore("巡查",plan.state,known);plan.store.accept=false
    check(not model.restore("巡查",String(quote.fingerprint),plan,known).ok and plan.state==changed,"itinerary save failure leaves exact old live state")
    var fault:=Fault.new();model.persistence=fault
    check(not model.save_new("第二份",current,known).ok and not model.drafts.has("第二份"),"library installation failure does not publish unsaved draft")
    check(FileAccess.get_file_as_bytes(model.path)==bytes,"library failure preserves exact prior bytes")
    fault.fail=false;check(model.save_new("第二份",current,known).ok,"same explicit action can retry successfully")
    var latest:=FileAccess.get_file_as_bytes(model.path)
    check(not reload.save_new("过时写入",current,known).ok and FileAccess.get_file_as_bytes(model.path)==latest,"stale library instance cannot overwrite newer file")
    check(not model.remove("巡查","stale").ok and model.drafts.has("巡查"),"delete requires current library identity")
    check(model.remove("巡查",model.source_hash).ok and not model.drafts.has("巡查"),"explicit deletion removes only selected saved draft")
    var damaged:=FileAccess.open(model.path,FileAccess.WRITE);damaged.store_string("bad config");damaged.close()
    var evidence:=FileAccess.get_file_as_bytes(model.path);model.configure("route_contract",true)
    check(not model.writable and not model.save_new("不会覆盖",current,known).ok,"damaged library blocks writes without being replaced with empty defaults")
    check(FileAccess.get_file_as_bytes(model.path)==evidence,"damaged evidence stays byte exact")
    var capacity:=LIB.new();capacity.configure("capacity_routes")
    for index in LIB.LIMIT:
        if not capacity.save_new("route%d" % index,current,known).ok:check(false,"capacity fixture write")
    var capacity_bytes:=FileAccess.get_file_as_bytes(capacity.path)
    check(not capacity.save_new("第九份",current,known).ok and capacity.drafts.size()==LIB.LIMIT,"ninth draft is refused without silently evicting eight saved orders")
    check(FileAccess.get_file_as_bytes(capacity.path)==capacity_bytes,"capacity refusal keeps complete existing library bytes")
    var check_capacity:=LIB.new();check_capacity.configure("capacity_routes")
    check(check_capacity.drafts==capacity.drafts,"complete bounded library survives a fresh native reader")
    for library in [model,reload,other,capacity,check_capacity]:
        if FileAccess.file_exists(library.path):DirAccess.remove_absolute(ProjectSettings.globalize_path(library.path))
    print("EXPEDITION_DRAFTS checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
