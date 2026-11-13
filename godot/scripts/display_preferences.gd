extends RefCounted
## Window mode, vertical sync and frame cap for this installation. Stored apart
## from journey saves and settings profiles: a profile shared to another
## computer must not change that computer's window.
const CAPS: Array[int] = [0, 30, 60, 120, 144]
const DEFAULTS := {"fullscreen": false, "vsync": true, "fps_cap": 0}
var store := preload("res://scripts/journey_desk_store.gd").new()
## Injected by the validation; production talks to the engine.
var window_mode: Callable
var set_window_mode: Callable
var set_vsync: Callable
var set_fps_cap: Callable
var values := DEFAULTS.duplicate()
var notice := ""
var ready := false
var dirty := false

func initialize() -> void:
    if ready:return
    ready=true
    var headless:=DisplayServer.get_name()=="headless"
    if not window_mode.is_valid():
        window_mode=func():return DisplayServer.window_get_mode()
    if not set_window_mode.is_valid():
        set_window_mode=func(mode: int):
            if not headless:DisplayServer.window_set_mode(mode)
    if not set_vsync.is_valid():
        set_vsync=func(enabled: bool):
            if not headless:DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
    if not set_fps_cap.is_valid():
        set_fps_cap=func(cap: int):Engine.max_fps=cap
    store.configure("display","installation")
    var saved:=store.read()
    if saved.is_empty():
        # Nothing chosen yet: leave the window exactly as the player launched it.
        if not store.error.is_empty():notice=store.error
        return
    if not valid(saved):
        store.writable=false;store.error="显示设置记录无效，保留原文件。";notice=store.error
        return
    values=clean(saved)
    _apply()

static func valid(candidate: Variant) -> bool:
    if not candidate is Dictionary or candidate.size()!=DEFAULTS.size():return false
    if not candidate.get("fullscreen") is bool or not candidate.get("vsync") is bool:return false
    var cap: Variant=candidate.get("fps_cap")
    return typeof(cap) in [TYPE_INT,TYPE_FLOAT] and float(cap)==floorf(float(cap)) and CAPS.has(int(cap))

static func clean(candidate: Dictionary) -> Dictionary:
    return {"fullscreen":bool(candidate.fullscreen),"vsync":bool(candidate.vsync),"fps_cap":int(candidate.fps_cap)}

func _apply() -> void:
    # Leave a maximised or minimised window alone unless the mode really changes.
    var full:=int(window_mode.call()) in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
    if full!=bool(values.fullscreen):
        set_window_mode.call(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    set_vsync.call(bool(values.vsync))
    set_fps_cap.call(int(values.fps_cap))

func change(key: String, value: Variant) -> Dictionary:
    var candidate:=values.duplicate()
    candidate[key]=value
    if not DEFAULTS.has(key) or not valid(candidate):
        return {"ok":false,"reason":"无效的显示设置。"}
    values=clean(candidate);dirty=true
    _apply()
    return save()

func save() -> Dictionary:
    if not dirty:return {"ok":true,"reason":"显示设置已保存。"}
    if not store.write(values):
        notice="已生效，但未能保存。"+store.error
        return {"ok":false,"applied":true,"reason":notice}
    dirty=false;notice="显示设置已保存。"
    return {"ok":true,"applied":true,"reason":notice}
