extends Node
## Installation-local cosmetic preference; no changes to gameplay bindings/saves.
const MOTION:=preload("res://scripts/decorative_motion.gd")
var store:=preload("res://scripts/journey_desk_store.gd").new()
var ui: Control
var button: Button
var retry: Button
var dirty:=false
var notice:=""

static func install(shell: Control) -> void:
    if shell.has_node("DecorativeMotionSettings"):return
    var control:=new();control.name="DecorativeMotionSettings";shell.add_child(control);control.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    store.configure("decorative_motion","installation")
    var data:=store.read()
    MOTION.enabled=true
    if not data.is_empty():
        if data.size()==1 and data.get("enabled") is bool:MOTION.enabled=data.enabled
        else:store.writable=false;store.error="装饰动态记录无效，保留原文件。"
    notice=store.error
    button=ui._button(ui.settings,"",Vector2(600,20),Vector2(196,32),toggle)
    button.name="DecorativeMotionToggle";button.add_theme_font_size_override("font_size",15)
    button.tooltip_text="只控制钟龛尾声和泵渠旧物的装饰动作；危险预警、角色动作、受击闪光与声音保持原规则。此偏好不随设置方案或分享码转移。"
    retry=ui._button(ui.settings,"重试保存",Vector2(802,20),Vector2(100,32),save)
    retry.name="DecorativeMotionRetry";retry.add_theme_font_size_override("font_size",14)
    refresh()

func refresh() -> void:
    button.text="装饰动态："+("开启" if MOTION.enabled else "静止")+(" · 未存" if dirty else "")
    button.add_theme_font_size_override("font_size",13 if dirty else 15)
    retry.disabled=not dirty
    button.tooltip_text="只控制钟龛尾声和泵渠旧物；危险预警、角色、受击闪光与声音不变。独立保存，不随分享码转移。\n"+(notice if not notice.is_empty() else "静止装饰仍保留形状、名称与交互。")

func toggle() -> void:
    if not is_instance_valid(ui) or not ui.settings.is_visible_in_tree():return
    MOTION.enabled=not MOTION.enabled
    dirty=true
    save()

func save() -> void:
    if not is_instance_valid(ui) or not ui.settings.is_visible_in_tree():return
    if not dirty:return
    if store.write({"enabled":MOTION.enabled}):dirty=false;notice="装饰动态偏好已保存。"
    else:notice="本次已生效，未保存。"+store.error
    refresh()
