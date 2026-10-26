extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/itinerary/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_itinerary", "name": "多站巡礼排程", "summary": "已知房间多站顺序、精确与启发式路线规划"}
