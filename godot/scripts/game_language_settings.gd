extends Node
## Install the saved language before the title, HUD and first region are built.
const LANGUAGE := preload("res://scripts/ui_language.gd")
var preferences := LANGUAGE.new()

func _enter_tree() -> void:
    preferences.initialize()

func _exit_tree() -> void:
    # The scripted Translation must leave the server before GDScript shuts down.
    LANGUAGE.uninstall()
