extends Node
## Runtime installation avoids loading an imported font before a fresh editor scan.
func _enter_tree() -> void:
    var theme := load("res://assets/ui/global_typeface.tres") as Theme
    get_tree().root.theme=theme
    # Text shaped before a control has resolved the root theme (and windows that
    # do not inherit it) uses the engine's default theme font, which has no CJK
    # glyphs: every such shaping searches the system fonts, several ms a label.
    ThemeDB.get_default_theme().default_font=theme.default_font
