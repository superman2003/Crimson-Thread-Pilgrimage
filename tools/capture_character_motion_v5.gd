extends SceneTree
## Real renderer / production actor contact sheets. Optional --baseline=<folder>
## compares an archived set of pre-integration manifests/atlases on the same rig.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const BOSSES := ["broken_string_gardener", "rust_crown_guardian", "saltwhite_contract_judge", "sunken_hammer_smith", "silent_crown_core", "silent_pilgrim_commander"]
const CELL := Vector2(210, 206)
var destination := ""
var baseline := ""
var view: SubViewport
var shots: Array = []
class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-output="): destination = arg.trim_prefix("--capture-output=")
        if arg.begins_with("--baseline="): baseline = arg.trim_prefix("--baseline=")
    call_deferred("run")

func _manifest(kind: String, before: bool) -> String:
    if not before:
        return ART.character_manifest("original_npcs" if kind.begins_with("npc_") else "original_creatures", kind)
    var actual := baseline.path_join(kind).path_join("motion_manifest.json")
    # The production actor selects its original-art loader by family path.
    var family := "original_npcs" if kind.begins_with("npc_") else "original_creatures"
    var path := baseline.path_join(family).path_join(kind).path_join("motion_manifest.json")
    if not ART.manifest_cache.has(path):
        var data: Dictionary = ART.manifest(actual).duplicate(true)
        for animation: Dictionary in data.animations:
            for frame: Dictionary in animation.frames:
                frame.atlas = baseline.path_join(kind).path_join(String(frame.atlas).get_file())
        ART.manifest_cache[path] = data
    return path

func _caption(stage: Node, text: String, pos: Vector2, size: int = 13) -> void:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    stage.add_child(label)

func _page(name: String, rows: Array, before: bool) -> void:
    var stage := Stage.new()
    view.add_child(stage)
    _caption(stage, "V5 / " + name + (" / BEFORE" if before else " / AFTER") + " / production frames, staged review", Vector2(20, 8), 18)
    var samples: Array = []
    for row_index in rows.size():
        var row: Array = rows[row_index]
        var kind := String(row[0])
        var path := _manifest(kind, before)
        var manifest: Dictionary = ART.manifest(path)
        var frames: SpriteFrames = ART.frames(path)
        _caption(stage, kind, Vector2(12, 38 + row_index * CELL.y), 14)
        for column in row[1].size():
            var spec: Array = row[1][column]
            var animation := String(spec[0])
            # Before has no attack-specific recovery; show the old generic
            # pose it used at this phase instead of silently omitting the row.
            if not frames.has_animation(animation): animation = "recover"
            var index := mini(int(spec[1]), frames.get_frame_count(animation) - 1)
            if index < 0: index = frames.get_frame_count(animation) - 1
            var origin := Vector2((column + 0.5) * CELL.x, 222 + row_index * CELL.y)
            var review_scale := 0.5 if kind in BOSSES else 1.0
            var sprite: AnimatedSprite2D
            if kind.begins_with("npc_"):
                sprite = AnimatedSprite2D.new()
                sprite.sprite_frames = frames
                sprite.scale = Vector2.ONE * float(manifest.visual_scale) * review_scale
                sprite.position = origin + Vector2(float(manifest.visual_offset[0]), float(manifest.visual_offset[1])) * review_scale
                stage.add_child(sprite)
            else:
                var enemy = ENEMY.new()
                enemy.configure({"id":"capture_v5", "kind":kind, "hp":20}, "", kind in BOSSES)
                enemy.asset_path = path
                enemy.visual_scale = float(manifest.visual_scale)
                enemy.visual_offset = Vector2(float(manifest.visual_offset[0]), float(manifest.visual_offset[1]))
                enemy.position = origin
                enemy.scale = Vector2.ONE * review_scale
                stage.add_child(enemy)
                enemy.set_physics_process(false)
                sprite = enemy.animated_sprite
            sprite.play(animation)
            sprite.set_frame_and_progress(index, 0.0)
            sprite.pause()
            _caption(stage, animation + "/" + str(index), Vector2(column * CELL.x + 12, 230 + row_index * CELL.y))
            samples.append({"kind":kind, "animation":animation, "frame":index})
    await process_frame
    await RenderingServer.frame_post_draw
    var captured := view.get_texture().get_image()
    var crop_height := mini(view.size.y, 54 + rows.size() * int(CELL.y))
    if not captured.is_empty(): captured = captured.get_region(Rect2i(0, 0, view.size.x, crop_height))
    var filename := ("before_" if before else "after_") + name + ".jpg"
    if captured.is_empty() or captured.save_jpg(destination.path_join(filename), 0.94) != OK:
        push_error("Capture failed: " + filename)
        quit(1)
        return
    shots.append({"image":filename, "capture_scale_boss":0.5, "capture_scale_other":1.0, "height":crop_height, "samples":samples})
    stage.queue_free()
    await process_frame

func run() -> void:
    if destination.is_empty() or DisplayServer.get_name() == "headless":
        push_error("Real display and --capture-output=absolute-directory required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    view = SubViewport.new()
    view.size = Vector2i(1680, 1290)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    RenderingServer.set_default_clear_color(Color("152026"))
    var pages: Dictionary = {}
    var rows: Array = []
    for kind in BOSSES.slice(0, 4):
        rows.append([kind, [["idle",0],["phase_windup",3],["phase",0],["phase",1],["phase",2],["phase",3],["phase_recover",0],["phase_recover",1]]])
    pages.phase = rows
    for attack in ["heavy", "cast", "phase"]:
        rows = []
        for kind in BOSSES:
            rows.append([kind, [[attack,3],[attack+"_recover",0],[attack+"_recover",1],[attack+"_recover",2],[attack+"_recover",3],[attack+"_recover",-1],["idle",0]]])
        pages[attack + "_recovery"] = rows
    rows = []
    for kind in ["ash_banner_imp", "echo_contract_scribe", "wax_lancer"]:
        rows.append([kind, [["windup",0],["windup",1],["windup",2],["windup",3],["attack",0],["attack",1],["attack",2],["attack",3]]])
    pages.regular_attacks = rows
    rows = []
    for kind in ["ash_banner_imp", "wax_lancer"]:
        rows.append([kind, [["attack",3],["recover",0],["recover",1],["recover",2],["recover",3],["recover",4],["recover",5],["idle",0]]])
    pages.regular_recovery = rows
    pages.repairs = [
        ["broken_string_gardener", [["death",1],["death",2],["death",3]]],
        ["delayed_shadow", [["attack",3],["recover",0],["recover",1]]],
        ["pipe_thrower", [["hurt",0],["hurt",1],["hurt",2]]],
        ["npc_blind_bell_knight", [["talk",2],["talk",3],["talk",4]]],
        ["npc_deserter_flagbearer", [["talk",5],["talk",6],["talk",7]]]
    ]
    for name: String in pages:
        if not baseline.is_empty(): await _page(name, pages[name], true)
        await _page(name, pages[name], false)
    var file := FileAccess.open(destination.path_join("capture.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(), "viewport":[1680,1290], "shots":shots}, "  ") + "\n")
    file.close()
    print("CHARACTER_MOTION_V5_CAPTURE shots=%d" % shots.size())
    view.queue_free()
    await process_frame
    quit(0)
