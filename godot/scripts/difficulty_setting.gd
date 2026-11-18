extends RefCounted
## Difficulty of one journey. Life is five whole masks, so tiers change whole
## masks per hit and the safe time after one, never a fraction of damage.
## Stored beside the save: the save file and settings profiles are untouched.
const TIERS := {
    "gentle": {"name": "从容", "damage_bonus": -1, "mercy": 0.9, "note": "重击少扣一格；受击后多 0.9 秒安全时间。"},
    "standard": {"name": "标准", "damage_bonus": 0, "mercy": 0.0, "note": "原本的设计。"},
    "harsh": {"name": "严苛", "damage_bonus": 1, "mercy": 0.0, "note": "每次受击多扣一格。"},
}
const ORDER: Array[String] = ["gentle", "standard", "harsh"]
const DEFAULT := "standard"
var store := preload("res://scripts/journey_desk_store.gd").new()
var tier := DEFAULT
var notice := ""

func attach(save_path: String) -> void:
    store.configure("difficulty",save_path)
    tier=DEFAULT;notice=""
    var saved:=store.read()
    if saved.is_empty():
        if store.error.is_empty() and FileAccess.file_exists(store.path):
            store.writable=false;store.error="难度记录无效，保留原文件，按标准进行。"
        notice=store.error;return
    if saved.size()!=1 or not saved.get("tier") is String or not TIERS.has(saved.tier):
        store.writable=false;store.error="难度记录无效，保留原文件，按标准进行。";notice=store.error
        return
    tier=String(saved.tier)

func choose(value: String) -> Dictionary:
    if not TIERS.has(value):return {"ok":false,"reason":"无效的难度。"}
    tier=value
    if not store.write({"tier":tier}):
        notice="已生效，但未能保存。"+store.error
        return {"ok":false,"applied":true,"reason":notice}
    notice="难度已保存。"
    return {"ok":true,"applied":true,"reason":notice}

func apply(player: Node) -> void:
    if not is_instance_valid(player):return
    player.set("difficulty_damage_bonus",int(TIERS[tier].damage_bonus))
    player.set("difficulty_mercy",float(TIERS[tier].mercy))
