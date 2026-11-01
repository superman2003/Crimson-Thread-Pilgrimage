extends SceneTree
var failures := 0
func _initialize() -> void:
    var expected := 1
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--expected-features="):
            expected = argument.trim_prefix("--expected-features=").to_int()
    var found := {}
    for file in DirAccess.get_files_at("res://journey/features"):
        var name := String(file).trim_suffix(".remap")
        if not name.ends_with(".gd"):
            continue
        var script: Script = load("res://journey/features/" + name)
        if script == null:
            failures += 1
            continue
        var feature: RefCounted = script.new()
        var id: String = feature.descriptor().id
        if found.has(id) or not feature.valid(feature.initial()):
            failures += 1
        found[id] = true
    if found.size() != expected or ResourceLoader.exists("res://journey/tests/core.gd"):
        failures += 1
    print("JOURNEY_PACK features=%d tests_excluded=%s failures=%d" % [found.size(), not ResourceLoader.exists("res://journey/tests/core.gd"), failures])
    quit(1 if failures else 0)
