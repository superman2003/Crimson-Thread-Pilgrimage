extends RefCounted
## Side-effect-free quote for an explicit, potentially stat-clamping restore.
static func quote(world: Node, name: String) -> Dictionary:
    var unavailable:={"ok":false,"can_restore":false,"reason":"当前无法恢复构筑方案。"}
    if not is_instance_valid(world) or not world.get("world_mode"):return unavailable
    if world.get("world_loading") or world.get("chapter_transitioning") or world.get("world_save_blocked"):return unavailable
    var player: Variant=world.get("player")
    var build: Variant=world.get("build_system")
    if not is_instance_valid(player) or player.hp<=0 or build==null:return unavailable
    var healing: Variant=player.get("heal_timer")
    if (healing is int or healing is float) and float(healing)>0.0:
        return {"ok":false,"can_restore":false,"reason":"请先结束疗伤，再核对构筑；疗伤预留的绯线仍按原契印结算。"}
    var at_bell: bool=world.call("_near_workstation")
    var result: Dictionary=build.preview_loadout(name,at_bell)
    if not result.get("ok",false) or not result.get("can_restore",false):return result
    var current: Dictionary=build.serialize()
    # Recovery timers continue to tick independently of the selected equipment.
    # They are not a quote identity and restoring a plan must not reset them.
    current.erase("cooldowns")
    var wallet: Dictionary=world.call("_build_wallet_snapshot")
    var health_after:=mini(int(player.hp),int(result.profile.get("max_hp",player.max_hp)))
    var thread_after:=mini(int(player.energy),int(result.profile.get("max_energy",player.max_energy)))
    result["resources"]={"hp_before":int(player.hp),"hp_after":health_after,"energy_before":int(player.energy),"energy_after":thread_after,
        "currency":int(wallet.currency),"counts":build.state.tool_counts.duplicate(true)}
    result["name"]=name
    result["fingerprint"]=var_to_str([name,current,build.permanent_stats,wallet,world.get("story_flags"),result.profile,result.equipped_families,result.resources]).sha256_text()
    return result

static func apply(world: Node, name: String, fingerprint: String) -> Dictionary:
    var fresh:=quote(world,name)
    if not fresh.get("ok",false) or not fresh.get("can_restore",false):return fresh
    if fingerprint.is_empty() or String(fresh.fingerprint)!=fingerprint:
        return {"ok":false,"changed":true,"reason":"方案、装备或资源已变化，请重新核对。"}
    # Preserve the existing durable transaction, rollback and derived-stat order.
    return world.call("perform_build_action","restore_loadout",name)
