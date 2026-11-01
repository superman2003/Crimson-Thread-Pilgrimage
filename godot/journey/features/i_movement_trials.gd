extends "res://journey/fieldwork/sessionpanel.gd"
const DOMAIN := preload("res://journey/fieldwork/movement_trials/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_movement_trials", "name": "机动区间练习", "summary": "显式当前区间采样、分段轨迹与资源变化观察"}


func requires_window() -> bool:
    return false


func release() -> void:
    pass


func shutdown() -> void:
    if live != null:
        _finish_session("所属旅途已退役")
    _disconnect()


func session_tick(clock: float) -> void:
    var owner: Node = context.level()
    if owner == null or not is_instance_valid(owner.get("player")):
        live.end("角色已经退役")
        return
    var player: Node2D = owner.player
    var snapshot := {
        "region": String(owner.config.get("id", "")),
        "exploring":
        (
            String(owner.active_overlay).is_empty()
            and not bool(owner.world_loading)
            and not bool(owner.chapter_transitioning)
        ),
        "player":
        {
            "position": VALUES.pair(player.global_position),
            "velocity": VALUES.pair(player.get("velocity")),
            "hp": float(player.get("hp")),
            "energy": float(player.get("energy")),
            "grounded": player.is_on_floor()
        }
    }
    live.sample(snapshot, clock)
