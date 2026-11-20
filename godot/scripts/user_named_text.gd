extends Node
## Render authored text around literal player names. Keep both parts separately
## so changing the language can redraw the same control without touching a save.
var template: String
var arguments: Array
var authored: Array
var tooltip: String

## These eight stable keys are also the game's built-in loadout titles.
static func is_default_loadout(value: String) -> bool:
    var suffix := value.trim_prefix("巡礼方案 ")
    return suffix != value and suffix.length() == 1 and suffix >= "1" and suffix <= "8"

static func bind(control: Control, source: String, values: Array, authored_indexes: Array = [], tip: String = "") -> void:
    var binding = control.get_node_or_null("UserNamedText")
    if binding == null:
        binding = new()
        binding.name = "UserNamedText"
        control.add_child(binding)
    binding.template = source
    binding.arguments = values.duplicate()
    binding.authored = authored_indexes.duplicate()
    binding.tooltip = tip
    control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    binding.render()

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
        render()

func render() -> void:
    if template.is_empty():
        return
    var values := arguments.duplicate()
    for index in values.size():
        var value := String(values[index])
        if index in authored or is_default_loadout(value):
            values[index] = String(TranslationServer.translate(value))
    var control := get_parent() as Control
    control.set("text", String(TranslationServer.translate(template)) % values)
    control.tooltip_text = String(TranslationServer.translate(tooltip)) if not tooltip.is_empty() else ""
