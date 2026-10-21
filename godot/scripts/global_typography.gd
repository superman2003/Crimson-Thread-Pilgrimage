extends Node
## Runtime installation avoids loading an imported font before a fresh editor scan.
func _enter_tree() -> void:
    get_tree().root.theme=load("res://assets/ui/global_typeface.tres") as Theme
