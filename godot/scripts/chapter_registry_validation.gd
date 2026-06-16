extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    _assert(int(state.get("campaign_chapter_total", 0)) == 6, "campaign overview exposes 6 chapters")
    _assert(String(state.get("campaign_current_chapter", "")) == "苔钟庭", "current playable chapter maps through runtime_config_id")

    var chapter_file_total := int(state.get("chapter_file_total", 0))
    var chapter_file_ids: Array = state.get("chapter_file_ids", [])
    _assert(chapter_file_total >= 5, "runtime discovers chapter data files for CH02-CH06")
    for id in [
        "ch02_rain_foundry_canal",
        "ch03_saltwhite_archive",
        "ch04_broken_string_greenhouse",
        "ch05_obsidian_pilgrim_road",
        "ch06_silent_crown_core"
    ]:
        _assert(id in chapter_file_ids, "runtime chapter registry includes " + id)

    print("CHAPTER_REGISTRY_VALIDATION_PASS campaign=6 chapter_files=%d" % chapter_file_total)
    quit(0)


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
