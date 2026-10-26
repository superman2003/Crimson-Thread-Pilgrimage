extends SceneTree
var failed := 0
func scan(directory: String) -> void:
    for name in DirAccess.get_files_at(directory):
        if name.ends_with(".gd"):
            var script: Script = load(directory.path_join(name))
            if script == null or not script.can_instantiate():
                failed += 1
    for name in DirAccess.get_directories_at(directory):
        if name != "tests":
            scan(directory.path_join(name))
func _initialize() -> void:
    scan("res://journey")
    print("WORKBENCH_BOOTSTRAP failures=%d" % failed)
    quit(1 if failed else 0)
