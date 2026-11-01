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
const VOICE=preload("res://scripts/protagonist_voice.gd")
func run() -> void:
    check(VOICE.records({}).is_empty(),"unearned abilities expose no reflection")
    var all: Dictionary={}
    for row in VOICE.catalogue():all[row.ability]=1
    check(VOICE.records(all).size()==20,"eight abilities reveal eight originals and twelve earned combinations")
    for bad in [true,"1",0,-1,0.5,NAN,INF,1000001]:
        var invalid:=all.duplicate()
        for id in invalid:invalid[id]=bad
        check(VOICE.records(invalid).is_empty(),"malformed ownership cannot unlock reflections")
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonist_voice.json"))
    var ids: Dictionary={}
    for row in data.combinations:
        var inventory: Dictionary={}
        for id in row.requires:inventory[id]=1
        var record_id: String="voice_combo_"+String(row.id)
        var earned: Array=VOICE.records(inventory).filter(func(record):return record.id==record_id)
        check(earned.size()==1 and not ids.has(record_id),"each compound reflection is uniquely earned")
        inventory.erase(row.requires[0])
        check(VOICE.records(inventory).filter(func(record):return record.id==record_id).is_empty(),"missing any requirement hides compound reflection")
        ids[record_id]=true
    finish()
