extends SceneTree

const ENEMY_ACTOR_SCRIPT := preload("res://scripts/enemy_actor.gd")
const REGISTRY_PATH := "res://assets/sprites/bosses/boss_asset_registry.json"
const RUNTIME_ANIMATIONS := ["idle", "walk", "attack", "hurt", "death"]
const WALK_FRAME_COUNT := 16
const ATTACK_FRAME_COUNT := 8

var failure_count := 0
var checked_bosses := 0
var checked_core_frames := 0
var runtime_loaded := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var registry := _load_json(REGISTRY_PATH)
    var entries: Array = registry.get("entries", [])
    _assert(int(registry.get("count", 0)) == 20, "registry exposes 20 bosses")
    _assert(entries.size() == 20, "registry has 20 boss entries")
    var seen_ids := {}
    for entry_value in entries:
        if not (entry_value is Dictionary):
            _assert(false, "registry entry is dictionary")
            continue
        await _validate_entry(entry_value as Dictionary, seen_ids)
    if failure_count > 0:
        quit(1)
        return
    print("BOSS_ASSET_REGISTRY_VALIDATION_PASS bosses=%d runtime_loaded=%d core_frames=%d registry=%s" % [
        checked_bosses,
        runtime_loaded,
        checked_core_frames,
        REGISTRY_PATH
    ])
    quit(0)


func _validate_entry(entry: Dictionary, seen_ids: Dictionary) -> void:
    var boss_id := String(entry.get("id", ""))
    var manifest_path := String(entry.get("manifest", ""))
    _assert(not boss_id.is_empty(), "boss id is present")
    _assert(not seen_ids.has(boss_id), boss_id + " id is unique")
    seen_ids[boss_id] = true
    _assert(manifest_path.begins_with("res://assets/sprites/bosses/"), boss_id + " manifest uses Godot boss asset path")
    _assert(FileAccess.file_exists(manifest_path), boss_id + " manifest exists")
    var manifest := _load_json(manifest_path)
    _assert(String(manifest.get("id", "")) == boss_id, boss_id + " manifest id matches")
    _assert(_array_equals(manifest.get("frame_size", []), [256, 256]), boss_id + " frame size is 256x256")
    var animations := _animations_by_name(manifest)
    for runtime_name in RUNTIME_ANIMATIONS:
        _assert(_animation_frame_count(animations, String(runtime_name)) > 0, boss_id + " runtime animation exists: " + String(runtime_name))
    var required: Array = entry.get("required_directional_animations", [])
    for animation_name_value in required:
        var animation_name := String(animation_name_value)
        var minimum := WALK_FRAME_COUNT if animation_name.begins_with("walk_") else ATTACK_FRAME_COUNT
        var frame_count := _animation_frame_count(animations, animation_name)
        _assert(frame_count >= minimum, boss_id + " " + animation_name + " has >= " + str(minimum) + " frames")
        checked_core_frames += mini(frame_count, minimum)
        _assert(_animation_frames_exist(animations, animation_name, minimum), boss_id + " " + animation_name + " frame files load")
    var attacks: Array = manifest.get("attacks", [])
    _assert(attacks.size() == 3, boss_id + " has 3 special attack records")
    for index in range(1, 4):
        var attack_id := "%s_atk_%02d" % [boss_id, index]
        _assert(_has_attack_record(attacks, attack_id), boss_id + " attack record exists: " + attack_id)
    await _validate_enemy_actor_runtime(entry, required)
    checked_bosses += 1


func _validate_enemy_actor_runtime(entry: Dictionary, required: Array) -> void:
    var boss_id := String(entry.get("id", ""))
    var manifest_path := String(entry.get("manifest", ""))
    var actor := Area2D.new()
    actor.set_script(ENEMY_ACTOR_SCRIPT)
    actor.configure({
        "id": boss_id + "_registry_probe",
        "kind": boss_id,
        "sprite": manifest_path,
        "hp": 10,
        "damage": 1,
        "visual_scale": 0.5,
        "body_size": [150, 138],
        "hurtbox_size": [164, 160]
    }, manifest_path, true, {"attacks": []})
    root.add_child(actor)
    await process_frame
    var animated := actor.get("animated_sprite") as AnimatedSprite2D
    _assert(animated != null, boss_id + " EnemyActor builds AnimatedSprite2D")
    if animated != null:
        var frames := animated.sprite_frames
        _assert(frames != null, boss_id + " EnemyActor loads SpriteFrames")
        if frames != null:
            for runtime_name in RUNTIME_ANIMATIONS:
                _assert(frames.has_animation(String(runtime_name)), boss_id + " SpriteFrames has " + String(runtime_name))
            for animation_name_value in required:
                var animation_name := String(animation_name_value)
                var minimum := WALK_FRAME_COUNT if animation_name.begins_with("walk_") else ATTACK_FRAME_COUNT
                _assert(frames.has_animation(animation_name), boss_id + " SpriteFrames has " + animation_name)
                if frames.has_animation(animation_name):
                    _assert(frames.get_frame_count(animation_name) >= minimum, boss_id + " SpriteFrames frame count ok: " + animation_name)
            actor.set("direction", -1)
            actor.call("_set_enemy_animation", "walk")
            _assert(animated.animation == "walk_left", boss_id + " runtime resolves walk_left")
            actor.set("direction", 1)
            actor.call("_set_enemy_animation", "attack")
            _assert(animated.animation == "attack_right", boss_id + " runtime resolves attack_right")
            var attack_name := "%s_atk_01" % boss_id
            actor.set("state", "windup")
            actor.set("direction", -1)
            actor.set("attack_direction", -1)
            actor.call("_set_enemy_animation", attack_name)
            _assert(animated.animation == attack_name + "_left", boss_id + " runtime resolves first special attack left")
            runtime_loaded += 1
    root.remove_child(actor)
    actor.queue_free()
    await process_frame


func _animations_by_name(manifest: Dictionary) -> Dictionary:
    var result := {}
    for animation in manifest.get("animations", []):
        if not (animation is Dictionary):
            continue
        var animation_data: Dictionary = animation
        var name := String(animation_data.get("name", ""))
        if not name.is_empty():
            result[name] = animation_data
    return result


func _animation_frame_count(animations: Dictionary, animation_name: String) -> int:
    if not animations.has(animation_name):
        return 0
    var animation: Dictionary = animations[animation_name]
    var frames: Array = animation.get("frames", [])
    return frames.size()


func _animation_frames_exist(animations: Dictionary, animation_name: String, minimum: int) -> bool:
    if not animations.has(animation_name):
        return false
    var animation: Dictionary = animations[animation_name]
    var frames: Array = animation.get("frames", [])
    if frames.size() < minimum:
        return false
    for index in range(minimum):
        var frame_path := String(frames[index]).strip_edges()
        if not FileAccess.file_exists(frame_path):
            return false
        var image := Image.load_from_file(frame_path)
        if image == null or image.get_size() != Vector2i(256, 256):
            return false
    return true


func _has_attack_record(attacks: Array, attack_id: String) -> bool:
    for attack in attacks:
        if attack is Dictionary and String((attack as Dictionary).get("id", "")) == attack_id:
            return true
    return false


func _array_equals(value, expected: Array) -> bool:
    if not (value is Array):
        return false
    var data: Array = value
    if data.size() != expected.size():
        return false
    for index in range(expected.size()):
        if data[index] != expected[index]:
            return false
    return true


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _assert(condition: bool, label: String) -> void:
    if condition:
        return
    failure_count += 1
    push_error("BOSS_ASSET_REGISTRY_VALIDATION_FAIL: " + label)
