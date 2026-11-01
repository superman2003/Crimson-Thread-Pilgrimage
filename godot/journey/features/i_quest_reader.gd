extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/quest_reader/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_quest_reader", "name": "已知任务阅读台", "summary": "已知任务的分页阅读、搜索定位与个人摘要"}
