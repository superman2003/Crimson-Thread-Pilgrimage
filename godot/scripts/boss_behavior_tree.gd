extends "res://addons/beehave/nodes/beehave_tree.gd"
## Project-owned lifecycle fix; pinned upstream code remains unchanged.
func _exit_tree() -> void:
    if not Engine.is_editor_hint():
        _get_global_debugger().unregister_tree(self)
        BeehaveDebuggerMessages.unregister_tree(get_instance_id())
    super()
