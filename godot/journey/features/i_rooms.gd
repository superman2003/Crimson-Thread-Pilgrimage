extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/rooms/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_rooms", "name": "现场房间档案", "summary": "已抵达空间档案、复访札记与快照比较"}
