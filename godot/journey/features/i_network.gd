extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/network/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_network", "name": "已知地图结构", "summary": "已知房间有向图、连通分量、割点与路径冗余"}
