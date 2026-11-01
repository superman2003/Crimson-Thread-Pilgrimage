extends RefCounted
## Private candidate publication for material/contract operations at a real bell.
static func ready(level: Node) -> bool:
    return is_instance_valid(level) and level.get("world_mode")==true and not level.world_loading and not level.chapter_transitioning and not level.world_save_blocked and is_instance_valid(level.player) and level.player.hp>0 and level.active_overlay=="build" and level.ui_shell.build_panel.is_visible_in_tree() and level.is_near_shrine()

static func commit(level: Node, counts: Dictionary, flags: Dictionary, money: int) -> Dictionary:
    if not ready(level):return {"ok":false,"reason":"请回到真实钟龛旁，在构筑页重新确认。"}
    var receipt_before:=preload("res://scripts/field_receipt_owner.gd").capture(level)
    var prepared: Dictionary=level._prepare_world_checkpoint({"inventory_counts":counts,"story_flags":flags,"currency":money,
        "current_region":String(level.config.id),"entry":level.active_spawn,"hp":level.player.hp,
        "energy":maxi(0,level.player.energy-level.player.practice_energy),"build_state":level.build_system.serialize()})
    if not prepared.ok or level.world_save_failure_injected_for_validation:return {"ok":false,"reason":"归途记录未写入，本次操作尚未结算，可原样重试。"}
    if not level.world_state.write_candidate(prepared.candidate,level.world_save_path):return {"ok":false,"reason":"归途记录未写入，本次操作尚未结算，可原样重试。"}
    level.world_state.data=prepared.candidate
    level.story_flags=flags
    level._set_build_wallet({"inventory_counts":counts,"currency":money})
    preload("res://scripts/field_receipt_owner.gd").committed(level,receipt_before)
    level._refresh_hud()
    return {"ok":true,"reason":"已写入归途记录。"}
