extends SceneTree
const REVIEW:=preload("res://scripts/loadout_restore_review.gd")
const DIALOG:=preload("res://scripts/loadout_restore_dialog.gd")
const BUILD:=preload("res://scripts/build_system.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
var checks:=0
var failures:=0
var applies:=0

class QuietPlayer extends "res://scripts/player_controller.gd":
    func _ready() -> void:pass
    func _process(_delta: float) -> void:pass
    func _physics_process(_delta: float) -> void:pass
    func _exit_tree() -> void:pass

class Runtime extends "res://scripts/main_level.gd":
    var at_bell:=true
    var save_ok:=true
    var writes:=0
    var notices: Array[String]=[]
    func _ready() -> void:pass
    func _process(_delta: float) -> void:pass
    func _physics_process(_delta: float) -> void:pass
    func _exit_tree() -> void:pass
    func _near_workstation(_artisan_only: bool=false) -> bool:return at_bell
    func _save_world() -> bool:writes+=1;return save_ok
    func _refresh_hud() -> void:pass
    func _toast(message: String) -> void:notices.append(message)

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func make_runtime() -> Node:
    var world:=Runtime.new()
    world.world_mode=true
    world.world_loading=false
    world.build_system=BUILD.new()
    world.player=preload("res://scenes/Player.tscn").instantiate()
    world.player.set_script(QuietPlayer)
    world.add_child(world.player)
    root.add_child(world)
    world.currency_count=111
    world.inventory_counts={"moss_chitin":3}
    world.build_system.state.tool_counts.shard=1
    world.build_system.save_loadout("轻装")
    world.build_system.state.equipped_families.tool[0]=""
    world.build_system._sync_aliases()
    world.build_system.cooldowns.cleave=2.0
    world.player.hp=4
    world.player.energy=37
    return world
func run() -> void:
    complete_profile_checks()
    await model_and_runtime_checks()
    await dialog_checks()
    await production_entry_checks()
    print("LOADOUT_RESTORE_REVIEW checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func model_and_runtime_checks() -> void:
    check(not REVIEW.quote(null,"none").ok,"no runtime cannot produce an actionable quote")
    var world:=make_runtime()
    var before: Dictionary=world.build_system.serialize()
    var wallet: Dictionary=world._build_wallet_snapshot()
    var quote: Dictionary=world.quote_loadout_restore("轻装")
    check(quote.ok and quote.can_restore and quote.fingerprint.length()==64,"production quote carries an exact review identity")
    check(world.build_system.serialize()==before and world._build_wallet_snapshot()==wallet and world.writes==0,"preview is read-only across build, wallet and persistence")
    check(quote.resources.hp_after==4 and quote.resources.energy_after==37 and quote.currency_cost==0 and not quote.refills_resources,"preview exposes no heal, thread refill or implicit money charge")
    check(quote.resources.counts.shard==1 and not quote.changes.is_empty(),"existing charge stock and actual equipment differences are present")
    quote.resources.counts.shard=999
    check(world.build_system.state.tool_counts.shard==1,"quote containers never alias live tool inventory")
    quote=world.quote_loadout_restore("轻装")
    world.build_system.tick(0.5)
    check(world.quote_loadout_restore("轻装").fingerprint==quote.fingerprint,"ordinary recovery timer decay does not force endless reconfirmation")
    var timer: float=world.build_system.cooldowns.cleave
    var result: Dictionary=world.apply_reviewed_loadout("轻装",quote.fingerprint)
    check(result.ok and world.writes==1 and world.build_system.state.tools[0]=="shard","accepted review delegates to the actual Main transaction and saved-plan restore")
    check(is_equal_approx(world.build_system.cooldowns.cleave,timer),"restoring equipment never resets recovery timers")
    check(world.player.hp==4 and world.player.energy==37 and world.build_system.state.tool_counts.shard==1 and world._build_wallet_snapshot()==wallet,"successful real profile application preserves current resources")
    quote=world.quote_loadout_restore("轻装")
    world.player.energy-=1
    check(not world.apply_reviewed_loadout("轻装",quote.fingerprint).ok and world.writes==1,"resource changes invalidate acceptance before any transaction")
    for field in ["world_loading","chapter_transitioning","world_save_blocked"]:
        world.set(field,true)
        check(not world.quote_loadout_restore("轻装").ok,"runtime gate rejects "+field)
        world.set(field,false)
    world.at_bell=false
    check(not world.quote_loadout_restore("轻装").can_restore,"road cannot restore a saved plan")
    world.at_bell=true
    world.player.hp=0
    check(not world.quote_loadout_restore("轻装").ok,"dead player cannot restore")
    world.player.hp=4
    world.player.heal_timer=0.5
    check(not world.quote_loadout_restore("轻装").ok and world.quote_loadout_restore("轻装").reason.contains("疗伤"),"active reserved heal must settle before resource-clamp review")
    world.player.heal_timer=0.0
    check(not world.quote_loadout_restore("missing").ok,"deleted saved plan is not actionable")
    quote=world.quote_loadout_restore("轻装")
    world.build_system.state.loadouts["轻装"].equipped_families.tool[0]=""
    world.build_system.state.loadouts["轻装"].tools[0]=""
    check(not world.apply_reviewed_loadout("轻装",quote.fingerprint).ok,"overwritten source invalidates a prior review")
    quote=world.quote_loadout_restore("轻装")
    world.currency_count+=1
    check(not world.apply_reviewed_loadout("轻装",quote.fingerprint).ok,"wallet changes also require a fresh review")
    quote=world.quote_loadout_restore("轻装")
    world.inventory_counts.moss_chitin+=1
    check(not world.apply_reviewed_loadout("轻装",quote.fingerprint).ok,"material changes invalidate the prior quote even when restoring has no material cost")
    quote=world.quote_loadout_restore("轻装")
    world.story_flags.review_context_changed=true
    check(not world.apply_reviewed_loadout("轻装",quote.fingerprint).ok,"progress/compatibility context changes cannot reuse acceptance")
    quote=world.quote_loadout_restore("轻装")
    world.build_system.permanent_stats.max_hp=1
    check(not world.apply_reviewed_loadout("轻装",quote.fingerprint).ok,"derived permanent-stat changes invalidate resource projection")
    world.build_system.permanent_stats.clear()
    quote=world.quote_loadout_restore("轻装")
    check(not world.apply_reviewed_loadout("轻装","").ok,"empty identity cannot bypass review")
    world.world_mode=false
    check(not world.quote_loadout_restore("轻装").ok,"chapter-only entry has no durable build restoration")
    world.world_mode=true
    world.save_ok=false
    before=world.build_system.serialize()
    wallet=world._build_wallet_snapshot()
    result=world.apply_reviewed_loadout("轻装",quote.fingerprint)
    check(not result.ok and world.build_system.serialize()==before and world._build_wallet_snapshot()==wallet,"injected persistence failure follows the existing Main rollback without changing build or wallet")
    check(world.player.hp==4 and world.player.energy==36,"failed save never applies new derived stats or refills resources")
    # An explicit alternate-capacity catalogue fixture exercises the real Player
    # clamp; current authored crests happen to share base HP/thread capacities.
    world.save_ok=true
    world.build_system.catalog.crests.bell.max_hp=8
    world.build_system.catalog.crests.bell.max_energy=180
    world.build_system.state.unlocked_crests.append("bell")
    world.build_system.state.crest="bell"
    world._sync_player_build()
    world.player.hp=8
    world.player.energy=180
    quote=world.quote_loadout_restore("轻装")
    check(quote.resources.hp_after==5 and quote.resources.energy_after==100,"preview states the exact lower-capacity consequence in an explicit alternate-capacity catalogue fixture")
    result=world.apply_reviewed_loadout("轻装",quote.fingerprint)
    check(result.ok and world.player.hp==quote.resources.hp_after and world.player.energy==quote.resources.energy_after,"real Main and Player application agree with the reviewed projection")
    world.free()
    await process_frame

func dialog_checks() -> void:
    var world:=make_runtime()
    var dialog:=DIALOG.new()
    root.add_child(dialog)
    var query:=func(name: String):return world.quote_loadout_restore(name)
    var action:=func(name: String,identity: String):applies+=1;return world.apply_reviewed_loadout(name,identity)
    var formatter:=func(_quote: Dictionary):return ["战具1：空 → 碎片"]
    dialog.open("轻装",query,action,formatter)
    check(dialog.visible and dialog.get_cancel_button().has_focus() and not dialog.get_ok_button().disabled,"native review opens with safe cancellation focused")
    check(dialog.changes.text.contains("战具1") and dialog.changes.text.contains("生命：4 → 4") and dialog.changes.text.contains("不会补满"),"native review shows real changes and resource consequences before acceptance")
    check(not dialog.changes.bbcode_enabled,"custom plan names cannot inject markup into the preview")
    dialog.hide()
    check(applies==0 and world.writes==0,"cancel cannot issue any equipment transaction")
    dialog.open("轻装",query,action,formatter)
    world.player.energy=20
    dialog.confirmed.emit()
    check(dialog.visible and dialog.status.text.contains("已变化") and applies==0,"changed resources require an explicit second confirmation")
    dialog.confirmed.emit()
    check(not dialog.visible and applies==1 and world.writes==1,"reviewed current state executes exactly once")
    dialog.confirmed.emit()
    check(applies==1,"duplicate confirmation after success cannot replay a transaction")
    dialog.open("轻装",query,action,formatter)
    world.at_bell=false
    dialog.confirmed.emit()
    check(dialog.visible and dialog.get_ok_button().disabled and applies==1,"leaving workstation disables acceptance at confirmation time")
    world.at_bell=true
    dialog.open("轻装",query,action,formatter)
    world.save_ok=false
    dialog.confirmed.emit()
    check(dialog.visible and dialog.status.text.contains("回滚"),"persistence failure stays visible and reports the existing transaction rollback")
    world.save_ok=true
    dialog.confirmed.emit()
    check(not dialog.visible and applies==3,"explicit retry can succeed after persistence becomes available")
    dialog.open("轻装",func(_name: String):return {"ok":true,"can_restore":true},action,formatter)
    check(dialog.get_ok_button().disabled,"a quote without identity cannot enable native confirmation")
    dialog.open("轻装",func(_name: String):return [],action,formatter)
    check(dialog.get_ok_button().disabled,"malformed quote stays non-actionable without type errors")
    dialog.open("<custom plan>",query,action,formatter)
    check(dialog.get_ok_button().disabled and dialog.changes.text.contains("<custom plan>"),"custom names are literal, and unsaved names remain unavailable")
    dialog.free()
    world.free()
    await process_frame

func production_entry_checks() -> void:
    var world:=make_runtime()
    var ui:=UI.new()
    root.add_child(ui)
    ui.level=world
    ui.build_panel=ColorRect.new()
    ui.add_child(ui.build_panel)
    ui.build_category="构筑"
    # Supply the normal refresh method without building unrelated HUD controls.
    # The accepted dialog path was already exercised against Main above.
    ui._open_loadout_restore("轻装")
    var dialog: ConfirmationDialog=ui.loadout_restore_dialog
    check(dialog.visible and world.writes==0,"actual shell entry opens review rather than immediately restoring equipment")
    check(dialog.get("changes").text.contains("战具1"),"actual production difference formatter is used by the review")
    ui.build_panel.hide()
    check(not dialog.visible and world.writes==0,"closing build overlay cancels the pending review without a transaction")
    ui._open_loadout_restore("轻装")
    check(not dialog.visible,"hidden build overlay cannot open an equipment confirmation")
    ui.free()
    world.free()
    await process_frame

func complete_profile_checks() -> void:
    var compare:=preload("res://scripts/build_profile_comparison.gd")
    var build:=BUILD.new()
    var labels:=compare.LABELS
    for crest in build.catalog.crests:
        build.state.crest=crest
        check(compare.uncovered(build.profile()).is_empty(),"every actual crest profile field has a readable label or documented alias/metadata treatment")
        for id in build.catalog.passives:
            for key in build.catalog.passives[id].modifiers:
                check(labels.has(key),"every real accessory modifier is covered by restore review: "+id+"/"+key)
    var before:={"skill_damage_mult":1.0,"tool_capacity_bonus":0,"damage_taken_mult":1.0,"attack_reach_mult":1.0,"heal_airborne":false}
    var after:={"skill_damage_mult":0.9,"tool_capacity_bonus":1,"damage_taken_mult":1.2,"attack_reach_mult":1.25,"hazard_trigger_mult":0.8,"heal_airborne":true}
    var original:=before.duplicate(true)
    var lines: Array=compare.lines(before,after)
    var text:="\n".join(lines)
    check(lines.size()==6 and before==original,"profile union reports all six changed effects without mutating input")
    check(text.contains("线技伤害倍率：1 → 0.9") and text.contains("战具容量加成：0 → 1"),"reflux and needlecase consequences cannot be omitted from confirmation")
    check(text.contains("环境陷阱触发范围倍率：1 → 0.8"),"missing trap multiplier uses the actual Player default rather than inventing zero")
    check(text.contains("受到伤害倍率") and text.contains("针击触及倍率") and text.contains("空中疗伤：关闭 → 开启"),"crest-specific reach, damage and boolean healing traits are readable")
    check(compare.rows(after,after).is_empty(),"unchanged effects are not duplicated as differences")
    check(compare.rows({"move_mult":1.0,"speed_multiplier":1.0},{"move_mult":1.1,"speed_multiplier":1.1}).size()==1,"documented exact aliases do not duplicate the canonical effect")
    check(compare.lines({"heal_duration":0.550001},{"heal_duration":0.550002})[0].contains("0.550002"),"small genuine changes are not rounded into identical displayed values")
    check(compare.uncovered({"future_modifier":0.7})==["future_modifier"],"new unlabelled profile fields are detectable by catalogue coverage CI")
    # Production formatter must include the complete profile comparison too.
    var ui:=UI.new()
    var output: Array=ui._loadout_difference_text({"changes":[],"current_profile":before,"profile":after},build)
    check("\n".join(output).contains("环境陷阱触发范围倍率"),"actual shell formatter used by the dialog includes effects beyond the old fixed list")
    ui.free()
