extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/itinerary/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_itinerary", "name": "多站巡礼排程", "summary": "已知房间多站顺序、精确与启发式路线规划"}


func _editor(parent: Control) -> void:
    super._editor(parent)
    if draft.is_empty() or not DOMAIN.validate(draft):return
    UI.divider(parent)
    UI.hint(parent,"可将这份候选的求解目标顺序安排到实际六站行程。先核对已补绘地点，再明确确认；此按钮是独立的辅助行程写入操作。")
    var button: Button=UI.button(parent,"核对并安排实际行程",func():
        var level: Node=context.level()
        if not is_instance_valid(level):context.tell("当前旅途已关闭。");return
        preload("res://scripts/itinerary_handoff_dialog.gd").open_for(level,parent.get_window(),draft))
    button.name="ItineraryHandoffButton"
