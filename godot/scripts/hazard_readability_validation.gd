extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var failures:=0
    var checks:=0
    var base="res://data/"
    var names=["moss_bell_court","rain_foundry_canal","saltwhite_archive","broken_string_greenhouse","obsidian_pilgrim_road","silent_crown_core"]
    for i in names.size():
        for path: String in [base+"demo_ch%02d_%s.json"%[i+1,names[i]],base+"generated/demo_ch%02d_%s.generated.json"%[i+1,names[i]]]:
            var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
            checks+=1
            if not data is Dictionary or not data.get("hazards",[]).is_empty(): failures+=1;push_error("retired level traps in "+path)
    print("HAZARD_READABILITY_PASS hazards=0 checks=%d"%checks)
    quit(0 if failures==0 else 1)
