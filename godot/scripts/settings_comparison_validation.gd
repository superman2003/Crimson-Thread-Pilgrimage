extends SceneTree
const MODEL:=preload("res://scripts/settings_profile_comparison.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
var checks:=0
var failures:=0
const ACTIONS:={"attack":"针击","build_menu":"构筑"}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func key(code: int) -> Dictionary:
    var event:=InputEventKey.new();event.physical_keycode=code;return CODEC.encode(event)
func joy(code: int) -> Dictionary:
    var event:=InputEventJoypadButton.new();event.button_index=code;return CODEC.encode(event)
func profile() -> Dictionary:
    return {"values":{"subtitle_size":21,"flash_enabled":true},"bindings":{"attack":[key(KEY_J),joy(JOY_BUTTON_X)],"build_menu":[key(KEY_B)]}}
func find_row(report: Dictionary,id: String) -> Dictionary:
    for entry in report.get("rows",[]):
        if entry.id==id:return entry
    return {}
func run() -> void:
    var a:=profile();var b:=a.duplicate(true)
    var original:=var_to_str(a)
    var report:=MODEL.compare(a,b,ACTIONS)
    check(report.ok and report.changed==0,"identical saved records have no differences")
    check(MODEL.select(report).is_empty(),"changed-only default does not invent differences")
    check(not MODEL.select(report,"",false).is_empty(),"same entries remain explicitly inspectable")
    b.values.subtitle_size=26;b.bindings.attack=[key(KEY_K),joy(JOY_BUTTON_X)]
    report=MODEL.compare(a,b,ACTIONS)
    check(report.changed==2,"setting and action changes are counted separately")
    check(find_row(report,"subtitle_size").before=="21" and find_row(report,"subtitle_size").after=="26","saved values appear side by side")
    check(find_row(report,"attack").before.contains("J") and find_row(report,"attack").after.contains("K"),"canonical key labels come from stored events")
    check(MODEL.compare(a,b,ACTIONS,1).changed==1,"settings-only excludes input differences")
    check(MODEL.compare(a,b,ACTIONS,2).changed==1,"keyboard-only isolates keyboard difference")
    check(MODEL.compare(a,b,ACTIONS,3).changed==0,"unchanged controller is not marked changed by keyboard difference")
    b.bindings.attack=[key(KEY_J),joy(JOY_BUTTON_Y)]
    check(MODEL.compare(a,b,ACTIONS,2).changed==0,"controller-only change leaves keyboard view unchanged")
    check(MODEL.compare(a,b,ACTIONS,3).changed==1,"controller button labels compare actual stored buttons")
    b=profile();b.values.erase("flash_enabled")
    report=MODEL.compare(a,b,ACTIONS)
    check(find_row(report,"flash_enabled").changed and find_row(report,"flash_enabled").after.contains("未记录"),"omitted legacy setting is not silently replaced by a default")
    check(find_row(report,"flash_enabled").before=="开启","boolean settings have readable labels")
    b=profile();b.bindings.erase("build_menu")
    report=MODEL.compare(a,b,ACTIONS)
    check(find_row(report,"build_menu").changed and find_row(report,"build_menu").after.contains("未记录"),"old missing build action is not filled from current InputMap")
    var old:=b.duplicate(true)
    check(not find_row(MODEL.compare(old,b,ACTIONS),"build_menu").changed,"both old omissions compare identically without invented binding")
    var labels:=MODEL.select(MODEL.compare(a,profile(),ACTIONS),"字幕字号",false)
    check(labels.size()==1 and labels[0].id=="subtitle_size","known setting names can filter same entries")
    check(MODEL.select(MODEL.compare(a,profile(),ACTIONS),"不存在",false).is_empty(),"unmatched query does not return a stale row")
    check(MODEL.select(MODEL.compare(a,profile(),ACTIONS),"针击 J",false).size()==1,"multi-token query searches canonical action labels and inputs")
    b=profile();b.bindings.attack=[joy(JOY_BUTTON_X),key(KEY_J)]
    check(find_row(MODEL.compare(a,b,ACTIONS),"attack").changed,"all-device comparison preserves binding priority order")
    check(not find_row(MODEL.compare(a,b,ACTIONS,2),"attack").changed,"device filtering ignores order of unrelated device events")
    var bad:=profile();bad.bindings.attack=[{"type":"key"}]
    check(not MODEL.compare(a,bad,ACTIONS).ok,"malformed input is rejected rather than labelled as missing")
    bad=profile();bad.values.subtitle_size=99
    check(not MODEL.compare(a,bad,ACTIONS).ok,"out-of-range saved value is rejected instead of normalized into equality")
    bad=profile();bad.bindings.unknown=[key(KEY_H)]
    check(not MODEL.compare(a,bad,ACTIONS).ok,"unknown action is not exposed by an internal ID")
    bad=profile();bad.bindings.attack=[key(KEY_J),key(KEY_J)]
    check(not MODEL.compare(a,bad,ACTIONS).ok,"duplicate event records retain canonical profile rejection")
    check(not MODEL.compare(a,{},ACTIONS).ok,"broken profile cannot be compared as defaults")
    check(not MODEL.compare(a,b,ACTIONS,4).ok,"unsupported comparison scope rejects explicitly")
    report=MODEL.compare(a,b,ACTIONS);var rows:=MODEL.select(report,"",false);rows[0].before="mutated"
    check(report.rows[0].before!="mutated","filtered rows are detached from report")
    check(var_to_str(a)==original,"all comparisons preserve the saved left record")
    check(MODEL.describe(MODEL.compare(a,a,ACTIONS)).contains("不读取或应用当前输入"),"readonly and missing-value limits remain visible")
    var untouched:=CODEC.capture(ACTIONS)
    MODEL.compare(a,old,ACTIONS)
    check(CODEC.capture(ACTIONS)==untouched,"legacy comparison never installs a current or default action")
    print("SETTINGS_COMPARISON checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
