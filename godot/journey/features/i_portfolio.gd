extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/portfolio/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_portfolio", "name": "物资组合分析", "summary": "库存集中度、个人安全储备、缺口与再平衡计划"}
