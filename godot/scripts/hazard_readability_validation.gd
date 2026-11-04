extends SceneTree
## V01: every authored trap is drawn across the width that actually hurts and
## stands on the trap's floor. Coverage is measured from the cropped opaque
## motifs the level adds, not from the transparent texture cells.
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const CHAPTERS := [
    "res://data/demo_ch01_moss_bell_court.json",
    "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json",
    "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json",
    "res://data/demo_ch06_silent_crown_core.json",
]
const MIN_COVERAGE := 0.85

var failures := 0
var checks := 0
var hazards := 0
var lowest := INF


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for path: String in CHAPTERS:
        var scene: Node = MAIN_SCENE.instantiate()
        scene.set("config_path", path)
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        await _frames(2)
        for data: Dictionary in scene.config.get("hazards", []):
            var area: Area2D = scene.get_node_or_null(String(data.get("id", "")))
            _check(area != null, "%s %s is built" % [path.get_file(), data.get("id", "")])
            if area != null:
                _check_hazard(area, String(data.get("kind", "spikes")), path.get_file())
        scene.queue_free()
        await _frames(3)
    if failures > 0:
        print("HAZARD_READABILITY_FAIL failures=%d checks=%d" % [failures, checks])
        call_deferred("quit", 1)
        return
    print("HAZARD_READABILITY_PASS hazards=%d lowest_coverage=%.2f checks=%d" % [hazards, lowest, checks])
    call_deferred("quit", 0)


func _check_hazard(area: Area2D, kind: String, chapter: String) -> void:
    hazards += 1
    var size: Vector2 = area.get_meta("hazard_authored_size")
    var spans: Array = []
    var bottoms: Array = []
    for child in area.get_children():
        if child is Sprite2D and String(child.name).begins_with("HazardMotif"):
            var drawn: Vector2 = child.texture.get_size() * child.scale
            spans.append(Vector2(child.position.x - drawn.x * 0.5, child.position.x + drawn.x * 0.5))
            bottoms.append(child.position.y + drawn.y * 0.5)
    _check(not spans.is_empty(), "%s %s draws its %s motif" % [chapter, area.name, kind])
    if spans.is_empty():
        return
    var covered := _covered(spans, -size.x * 0.5, size.x * 0.5)
    var coverage := covered / size.x
    lowest = minf(lowest, coverage)
    _check(coverage >= MIN_COVERAGE, "%s %s (%s) is drawn over %.0f%% of its %.0fpx damaging width" % [chapter, area.name, kind, coverage * 100.0, size.x])
    for bottom: float in bottoms:
        _check(absf(bottom - (size.y * 0.5 + 2.0)) <= 1.0, "%s %s motif stands on the trap floor" % [chapter, area.name])


## Length of [left, right] covered by the union of the given spans.
func _covered(spans: Array, left: float, right: float) -> float:
    spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
    var total := 0.0
    var cursor := left
    for span: Vector2 in spans:
        var start := maxf(span.x, cursor)
        var finish := minf(span.y, right)
        if finish > start:
            total += finish - start
            cursor = finish
    return total


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("HAZARD_READABILITY " + label)
