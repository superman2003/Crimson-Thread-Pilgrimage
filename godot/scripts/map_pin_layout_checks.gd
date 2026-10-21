extends RefCounted
## Real production redraws with synthetic charting: layout coverage, not playthrough.
const UI := preload("res://scripts/map_player_pins_runtime.gd")
const PINS := preload("res://scripts/map_player_pins.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SURVEY := preload("res://scripts/cartography_runtime.gd")

static func run(scene: Node, check: Callable) -> void:
    var original_config: Dictionary = scene.config
    var original_flags: Dictionary = scene.story_flags
    var original_view: bool = scene.world_map_view
    var original_text: String = scene.map_text.text
    var state: Dictionary = scene.world_state.data
    var state_value := state.duplicate(true)
    var save := FileAccess.get_file_as_bytes(scene.world_save_path)
    var backup := FileAccess.get_file_as_bytes(scene.world_save_path + ".bak")
    var rows := []
    for region in ROUTES.cached_chapters():
        var config := ATLAS.configuration(region)
        scene.config = config
        var flags := {}
        JOURNAL.region(flags, region).owned = true
        for room in config.map_rooms: JOURNAL.region(flags, region).charted[String(room.id)] = true
        for world_view in [false, true]:
            scene.world_map_view = world_view
            for id_offset in [0, 999999980]:
                var summary := {"region": region, "world_view": world_view, "id_offset": id_offset,
                    "layouts": 0, "outside": 0, "overlap": 0, "missing": 0, "moved_anchor": 0,
                    "changed_flags": 0, "far_layouts": 0, "unlinked": 0, "leaders": 0, "max_drift": 0.0}
                for room in config.map_rooms:
                    var rect := SURVEY.room_rect(room)
                    if rect.size.x < 100 or rect.size.y < 75: continue
                    for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
                        var local_flags := flags.duplicate(true)
                        for index in PINS.LIMIT:
                            var delta := Vector2(1 + (index % 4) * 25, 1 + int(index / 4) * 25)
                            var point := rect.position + Vector2(delta.x if corner.x == 0 else rect.size.x - delta.x, delta.y if corner.y == 0 else rect.size.y - delta.y)
                            var added := PINS.add(local_flags, {region: config}, region, point, PINS.KINDS[index % 3])
                            if added.ok: local_flags[PINS.KEY] = added.records
                        var records := PINS.records(local_flags, {region: config})
                        if records.size() != PINS.LIMIT: continue
                        if id_offset > 0:
                            for record in records: record.id += id_offset
                            local_flags[PINS.KEY] = records
                        scene.story_flags = local_flags
                        var before := local_flags.duplicate(true)
                        scene.map_text.text = ""
                        var initial_children: int = scene.map_draw_root.get_child_count()
                        UI.refresh(scene)
                        var result := _inspect(scene, records, initial_children)
                        summary.layouts += 1
                        for pair in [["outside", "inside"], ["overlap", "clear"], ["missing", "complete"], ["moved_anchor", "anchored"], ["unlinked", "linked"]]:
                            summary[pair[0]] += int(not result[pair[1]])
                        summary.changed_flags += int(local_flags != before)
                        summary.leaders += int(result.leaders)
                        summary.far_layouts += int(result.max_drift > UI.MAX_DRIFT + 0.01)
                        summary.max_drift = maxf(summary.max_drift, result.max_drift)
                        if id_offset == 0 and result.max_drift > UI.MAX_DRIFT + 0.01 and not summary.has("first_far"):
                            summary.first_far = {"room": String(room.id), "corner": [corner.x, corner.y], "records": records}
                        _clear_markers(scene, records)
                var prefix := "%s world=%s id_offset=%d: " % [region, world_view, id_offset]
                check.call(summary.layouts > 0, prefix + "authored room-corner fixtures contain twelve independently accepted pins")
                check.call(summary.outside == 0, prefix + "real Label rectangles stay fully inside the clipped map paper")
                check.call(summary.overlap == 0, prefix + "visible real-font rectangles never overlap")
                check.call(summary.missing == 0, prefix + "every pin number and deletion-list ID appears exactly once")
                check.call(summary.moved_anchor == 0 and summary.changed_flags == 0, prefix + "redraw preserves all true anchors and serialized pin values")
                check.call(summary.unlinked == 0, prefix + "every far label has a thin leader to each distant represented pin")
                rows.append(summary)
    check.call(rows.any(func(row): return row.id_offset == 0 and row.leaders > 0), "normal-number layouts actually generate leaders to distant pins")
    check.call(rows.any(func(row): return row.id_offset > 0 and row.leaders > 0), "legacy-number layouts actually generate leaders to distant pins")
    scene.config = original_config
    scene.story_flags = original_flags
    scene.world_map_view = original_view
    scene.map_text.text = original_text
    scene._refresh_map_overlay()
    check.call(is_same(scene.world_state.data, state) and state == state_value and FileAccess.get_file_as_bytes(scene.world_save_path) == save and FileAccess.get_file_as_bytes(scene.world_save_path + ".bak") == backup, "dense edge redraws preserve checkpoint identity/value and both save files")
    print("PIN_BOUNDARY_LAYOUTS " + JSON.stringify({"rows": rows, "synthetic_charting": true, "natural_exploration": false, "physical_controller": false}))

static func _clear_markers(scene: Node, records: Array[Dictionary]) -> void:
    for record in records:
        for prefix in ["PlayerMapPin_", "PlayerMapPinLeader_"]:
            var child: Node = scene.map_draw_root.get_node_or_null(prefix + str(record.id))
            if child != null: child.free()

static func _inspect(scene: Node, records: Array[Dictionary], initial_children: int) -> Dictionary:
    var labels: Array[Label] = []
    var shown := []
    var hosts := {}
    var rectangles := {}
    var inside := true
    var clear := true
    var anchored := true
    var complete := true
    var drift := 0.0
    var linked := true
    var needed_leaders := 0
    var paper := Rect2(Vector2.ZERO, scene.map_draw_root.size)
    for record in records:
        var label: Label = scene.map_draw_root.get_node_or_null("PlayerMapPin_" + str(record.id))
        if label == null:
            complete = false
            continue
        var point := Vector2(record.position[0], record.position[1])
        anchored = anchored and (label.get_meta("map_anchor") as Vector2).is_equal_approx(UI.project(scene, record.region_id, point)) and label.get_meta("local_position") == point and label.get_meta("region_id") == record.region_id
        if not label.visible: continue
        # Independent of the production collision-box helper: use Control's
        # actual font and line-spacing size, including joined multi-line labels.
        var rect := Rect2(label.position, label.get_combined_minimum_size())
        inside = inside and paper.encloses(rect)
        for other in labels:
            if rect.intersects(rectangles[other]): clear = false
        labels.append(label)
        rectangles[label] = rect
        for token in label.text.replace("\n", " ").split(" ", false):
            shown.append(token)
            hosts[token] = label
        for anchor in UI.represented(label): drift = maxf(drift, (label.position + UI.LABEL_ORIGIN).distance_to(anchor))
    for record in records:
        var anchor := UI.project(scene, record.region_id, Vector2(record.position[0], record.position[1]))
        var token: String = PINS.SYMBOLS[PINS.KINDS.find(record.kind)] + str(record.id)
        var target: Label = hosts.get(token)
        if target == null:
            linked = false
            continue
        var end := target.position + UI.LABEL_ORIGIN
        var needed := end.distance_to(anchor) > UI.MAX_DRIFT
        var leader: Line2D = scene.map_draw_root.get_node_or_null("PlayerMapPinLeader_" + str(record.id))
        if needed:
            needed_leaders += 1
            linked = linked and leader != null
            if leader != null:
                linked = linked and leader.points.size() == 2 and leader.points[0].is_equal_approx(anchor) and leader.points[1].is_equal_approx(end) and is_equal_approx(leader.width, 1.0) and int(leader.get_meta("label_id")) == int(target.get_meta("pin_id"))
        else: linked = linked and leader == null
    var added_children: int = scene.map_draw_root.get_child_count() - initial_children
    linked = linked and added_children == records.size() + needed_leaders and needed_leaders <= PINS.LIMIT
    var list: OptionButton = scene.map_panel.get_node("PlayerPinToolbar/PinList")
    var listed := []
    for index in range(1, list.item_count): listed.append(list.get_item_id(index))
    for record in records:
        var number: String = PINS.SYMBOLS[PINS.KINDS.find(record.kind)] + str(record.id)
        complete = complete and shown.count(number) == 1 and listed.count(int(record.id)) == 1
    return {"inside": inside, "clear": clear, "complete": complete, "anchored": anchored, "linked": linked, "leaders": added_children - records.size(), "max_drift": drift}
