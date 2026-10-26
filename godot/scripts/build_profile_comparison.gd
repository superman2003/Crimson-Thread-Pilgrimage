extends RefCounted
## The union of real before/after profiles determines which effects changed.
const LABELS := {
    "max_hp":"生命上限", "max_energy":"绯线上限", "slots":"铭饰容量",
    "attack_damage_mult":"针击伤害倍率", "attack_reach_mult":"针击触及倍率",
    "attack_speed_mult":"针击速度倍率", "attack_bonus":"针击基础加成",
    "move_mult":"移动倍率", "damage_taken_mult":"受到伤害倍率",
    "heal_cost":"疗伤耗线", "heal_amount":"疗伤恢复", "heal_duration":"疗伤秒数",
    "heal_interrupt_loss_ratio":"疗伤打断损失比例", "heal_airborne":"空中疗伤",
    "heal_knockback_duration":"疗伤抗击退持续秒数", "heal_mark_extension":"疗伤延长盐记秒数",
    "heal_move_duration":"疗伤后移速持续秒数", "energy_gain_mult":"命中取线倍率",
    "melee_energy_mult":"近战取线倍率", "energy_per_hit":"每次命中取线",
    "skill_cost_mult":"线技耗线倍率", "skill_damage_mult":"线技伤害倍率",
    "ranged_range_mult":"远程触及倍率", "knockback_mult":"受到击退倍率",
    "status_buildup_mult":"状态积累倍率", "tool_capacity_bonus":"战具容量加成",
    "pogo_bounce_mult":"下击反弹倍率", "hazard_trigger_mult":"环境陷阱触发范围倍率",
    "status_resist_duration":"状态抗性持续秒数", "guard_refund":"格挡取线返还",
    "mechanism_unlocked":"当前契印机制启用", "crimson_repaired":"缝名机制修复",
    "description":"契印说明", "mechanism":"契印机制", "attack_description":"针击动作",
    "heal_effect":"疗伤特性"
}
# These are either repeated labels already shown by the slot/crest comparison,
# provenance/UI metadata, or exact aliases derived by BuildSystem.profile().
const METADATA := ["name","crest_id","source","unlock_flag","unlock_hint","mechanism_flag","slot_layout"]
const ALIASES := {"speed_multiplier":"move_mult","skill_range_mult":"ranged_range_mult","downstrike_bounce_mult":"pogo_bounce_mult","heal_energy_cost":"heal_cost"}
const DEFAULTS := {"hazard_trigger_mult":1.0,"tool_capacity_bonus":0}

static func value(profile: Dictionary, key: String) -> Variant:
    return profile.get(key,DEFAULTS.get(key,0))

static func rows(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
    var keys:=before.keys()
    for key in after:
        if not keys.has(key):keys.append(key)
    keys.sort()
    var result: Array[Dictionary]=[]
    for key in keys:
        if key in METADATA or ALIASES.has(key):continue
        var old: Variant=value(before,key)
        var next: Variant=value(after,key)
        if old==next:continue
        result.append({"key":key,"label":String(LABELS.get(key,"附加构筑效果")),"from":old,"to":next})
    return result

static func display(value: Variant) -> String:
    if value is bool:return "开启" if value else "关闭"
    if value is int:return str(value)
    if value is float:
        var number:=String.num(value,6)
        while number.contains(".") and number.ends_with("0"):number=number.substr(0,number.length()-1)
        return number.trim_suffix(".")
    if value is String:return value
    return JSON.stringify(value)

static func lines(before: Dictionary, after: Dictionary) -> Array[String]:
    var result: Array[String]=[]
    for row in rows(before,after):
        result.append("%s：%s → %s" % [row.label,display(row.from),display(row.to)])
    return result

static func uncovered(profile: Dictionary) -> Array[String]:
    var result: Array[String]=[]
    for key in profile:
        if key not in METADATA and not ALIASES.has(key) and not LABELS.has(key):result.append(String(key))
    return result
