extends Node
signal stepped(clock: float)


func _init() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
    stepped.emit(float(Time.get_ticks_usec()) / 1000000.0)
