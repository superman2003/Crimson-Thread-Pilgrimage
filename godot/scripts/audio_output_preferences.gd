extends RefCounted
## Device routing is global to this installation; it never touches journey saves.
const DEFAULT := "Default"
var store := preload("res://scripts/journey_desk_store.gd").new()
var devices: Callable
var current: Callable
var route: Callable
var preferred := DEFAULT
var notice := ""
var ready := false
var dirty := false
var observed := DEFAULT

func initialize() -> void:
    if ready:return
    ready=true
    if not devices.is_valid():devices=func():return AudioServer.get_output_device_list()
    if not current.is_valid():current=func():return AudioServer.output_device
    if not route.is_valid():route=func(name: String):AudioServer.output_device=name
    store.configure("audio_output","installation")
    var saved:=store.read()
    if not saved.is_empty():
        if saved.size()!=1 or not valid_name(saved.get("device")):
            store.writable=false;store.error="输出设备记录无效，保留原文件。"
        else:preferred=String(saved.device)
    var available:=choices()
    if preferred in available:
        if not _switch(preferred):notice="系统未确认保存的输出设备，请重新选择。"
    else:
        var fallback:=_switch(DEFAULT)
        notice="保存的输出设备当前不在此电脑上，"+("已使用系统默认；重新连接后请明确选择。" if fallback else "系统未确认默认输出，请检查系统声音设置。")
    if not store.error.is_empty():notice=store.error

static func valid_name(value: Variant) -> bool:
    if not value is String:return false
    var name:=String(value)
    if name.is_empty() or name.length()>512:return false
    for index in name.length():
        if name.unicode_at(index)<32 or name.unicode_at(index)==127:return false
    return true

func choices() -> Array[String]:
    var result: Array[String]=[DEFAULT]
    if not devices.is_valid():return result
    var found: Variant=devices.call()
    if not found is Array and not found is PackedStringArray:return result
    for candidate in found:
        if valid_name(candidate) and not result.has(String(candidate)):
            result.append(String(candidate))
    return result

func active() -> String:
    if not current.is_valid():return DEFAULT
    var value: Variant=current.call()
    return String(value) if valid_name(value) else DEFAULT

func _switch(name: String) -> bool:
    if not route.is_valid():return false
    route.call(name)
    var accepted:=active()==name
    if accepted:observed=name
    return accepted

func refresh() -> Dictionary:
    var available:=choices()
    var actual:=active()
    if observed!=DEFAULT and not available.has(observed) and actual==DEFAULT:
        notice="输出设备已断开，系统已切回默认输出；重新连接后请明确选择。"
    if not available.has(actual):
        if _switch(DEFAULT):
            notice="输出设备已断开，已切回系统默认；不会在重连时自动抢回输出。"
        else:notice="输出设备已断开，系统未确认默认输出。请检查系统声音设置。"
    observed=active()
    return {"devices":available,"active":active(),"preferred":preferred,
        "dirty":dirty,"notice":notice,"save_error":store.error}

func quote(name: String) -> Dictionary:
    var view:=refresh()
    if not valid_name(name) or not view.devices.has(name):
        return {"ok":false,"reason":"该输出设备已不可用，请重新选择。"}
    return {"ok":true,"device":name,"before":view.active,
        "fingerprint":var_to_str([view.devices,view.active,preferred]).sha256_text()}

func apply(name: String, fingerprint: String) -> Dictionary:
    var fresh:=quote(name)
    if not fresh.get("ok",false):return fresh
    if fingerprint.is_empty() or fingerprint!=fresh.fingerprint:
        return {"ok":false,"reason":"设备列表或当前输出已变化，请重新核对。"}
    var before:=active()
    if not _switch(name):
        if choices().has(before):_switch(before)
        notice="系统未确认设备切换，未保存此选择。"
        return {"ok":false,"reason":notice}
    preferred=name;dirty=true
    return save()

func save() -> Dictionary:
    if not dirty:return {"ok":true,"reason":"输出设备选择已保存。"}
    if not store.write({"device":preferred}):
        notice="声音已切换，但偏好未保存。"+store.error
        return {"ok":false,"applied":true,"reason":notice}
    dirty=false;notice="输出设备选择已保存。"
    return {"ok":true,"applied":true,"reason":notice}
