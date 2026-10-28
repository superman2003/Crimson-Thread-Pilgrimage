extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_04 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const BATCH:=preload("res://scripts/contract_batch_settlement.gd")
const CONTRACTS:=preload("res://scripts/field_contracts.gd")
class Player extends Node:
    var hp:=5
    var energy:=80
    var practice_energy:=0
class Build extends RefCounted:
    func serialize() -> Dictionary:return {}
class Save extends RefCounted:
    var data: Dictionary={"regions":{}}
    var accept_write:=false
    var calls:=0
    func get_region(_id: String) -> Dictionary:return {"visited_rooms":{}}
    func write_candidate(_candidate: Dictionary,_path: String) -> bool:
        calls+=1;return accept_write
class Level extends Node:
    var world_mode:=true
    var world_loading:=false
    var chapter_transitioning:=false
    var world_save_blocked:=false
    var world_save_failure_injected_for_validation:=false
    var player: Node
    var active_overlay:="build"
    var ui_shell: Control
    var config: Dictionary={}
    var inventory_counts: Dictionary={}
    var story_flags: Dictionary={}
    var visited_rooms: Dictionary={}
    var currency_count:=100
    var active_spawn: Array=[0,0]
    var world_save_path:="user://unused_batch_fixture.json"
    var world_state:=Save.new()
    var build_system:=Build.new()
    func is_near_shrine() -> bool:return true
    func _prepare_world_checkpoint(patch: Dictionary) -> Dictionary:return {"ok":true,"candidate":patch.merged({"regions":{}})}
    func _set_build_wallet(wallet: Dictionary) -> void:inventory_counts=wallet.inventory_counts;currency_count=wallet.currency
    func _refresh_hud() -> void:pass
class UI extends Control:
    var level: Node
    var build_panel: Control
    func register_text_entry_window(_window: Window) -> void:pass
var quotes: Dictionary={}
func single(id: String) -> Dictionary:return quotes.get(id,{"ok":false,"reason":"拒绝"}).duplicate(true)
func run() -> void:
    var entries: Array=[{"contract_id":"a","accepted":true,"ready":true,"claimed":false,"title":"甲"},{"contract_id":"b","accepted":true,"ready":true,"claimed":false,"title":"乙"}]
    var counts: Dictionary={"proof":3,"kept":7};var flags: Dictionary={"old":true}
    quotes={"a":{"ok":true,"counts":{"proof":4,"kept":7},"flags":{"old":true,"a_claimed":true},"fingerprint":"a1","summary":"甲回礼"},"b":{"ok":true,"counts":{"proof":4,"kept":7},"flags":{"old":true,"b_claimed":true},"fingerprint":"b1","summary":"乙回礼"}}
    var original:=var_to_str([entries,counts,flags,quotes])
    var result:=BATCH.quote(entries,counts,flags,single)
    check(result.ok and result.counts.proof==5,"same reward accumulates both independent quote deltas")
    check(result.counts.kept==7 and result.flags.a_claimed and result.flags.b_claimed,"unrelated items preserved and both claim flags combined")
    check(result.ids==["a","b"] and result.summary.contains("甲回礼") and result.summary.contains("乙回礼"),"review lists exact batch")
    check(var_to_str([entries,counts,flags,quotes])==original,"batch quote has no side effects")
    check(not BATCH.quote([],counts,flags,single).ok,"empty batch rejected")
    check(not BATCH.quote(entries+[entries[0]],counts,flags,single).ok,"duplicate contract rejected")
    var filtered:=entries.duplicate(true);filtered[1].ready=false
    check(BATCH.quote(filtered,counts,flags,single).ids==["a"],"not-ready contract excluded before preview")
    filtered=entries.duplicate(true);filtered[1].claimed=true
    check(BATCH.quote(filtered,counts,flags,single).ids==["a"],"already claimed never included")
    quotes.b.ok=false
    check(not BATCH.quote(entries,counts,flags,single).ok and counts.proof==3,"one quote failure rejects whole candidate")
    quotes.b.ok=true;quotes.b.counts.proof=999999
    check(not BATCH.quote(entries,counts,flags,single).ok,"combined capacity overflow rejected")
    quotes.b.counts.proof=2
    check(not BATCH.quote(entries,counts,flags,single).ok,"unexpected deduction rejected")
    quotes.b.counts.proof=true
    check(not BATCH.quote(entries,counts,flags,single).ok,"boolean counter rejected")
    quotes.b.counts.proof=4;quotes.b.counts.erase("kept")
    check(not BATCH.quote(entries,counts,flags,single).ok,"missing original item rejected")
    quotes.b.counts.kept=7;quotes.b.flags.old=false
    check(not BATCH.quote(entries,counts,flags,single).ok,"unexpected flag removal rejected")
    quotes.b.flags.old=true;quotes.b.fingerprint="b2"
    check(BATCH.quote(entries,counts,flags,single).fingerprint!=result.fingerprint,"changed canonical quote invalidates batch confirmation")
    var four: Array=[]
    for id in ["a","b","c","d"]:four.append({"contract_id":id,"accepted":true,"ready":true,"claimed":false})
    check(not BATCH.quote(four,counts,flags,single).ok,"batch obeys three-active-contract limit")
    var catalog:=CONTRACTS.contracts();var region:=String(catalog[0].region)
    var level:=Level.new();var ui:=UI.new();root.add_child(level);root.add_child(ui)
    level.config={"id":region};level.player=Player.new();level.add_child(level.player)
    ui.level=level;ui.build_panel=Control.new();ui.add_child(ui.build_panel);level.ui_shell=ui
    var accepted: Array=[]
    for contract in catalog:
        if contract.region!=region:continue
        accepted.append(contract)
        level.story_flags[CONTRACTS.flag(String(contract.id),"accepted")]=true
        for objective in contract.objectives:
            if objective.kind=="enemy":level.story_flags["journal_enemy_"+String(objective.target)]=true
            else:level.visited_rooms[String(objective.target)]=true
    var desk:=preload("res://scripts/field_contract_desk.gd").new();ui.add_child(desk);desk.ui=ui;desk._build();desk.refresh();desk.window.popup_centered()
    var saved_flags:=level.story_flags.duplicate(true)
    desk.ask_batch()
    check(desk.pending.ids.size()==2 and desk.confirm.visible,"native batch confirmation uses actual two ready regional contracts")
    desk.confirm.confirmed.emit()
    check(level.inventory_counts.is_empty() and level.story_flags==saved_flags and level.world_state.calls==1,"failed canonical transaction publishes neither rewards nor claim flags")
    level.world_state.accept_write=true;desk.ask_batch();desk.confirm.confirmed.emit()
    var expected_rewards: Dictionary={}
    for contract in accepted:expected_rewards[contract.reward_item]=int(expected_rewards.get(contract.reward_item,0))+int(contract.reward_amount)
    check(level.inventory_counts==expected_rewards and level.world_state.calls==2,"retry publishes both actual rewards through one successful write")
    check(accepted.all(func(contract):return level.story_flags.get(CONTRACTS.flag(String(contract.id),"claimed"),false)),"successful batch publishes all claim flags together")
    desk._confirm()
    check(level.world_state.calls==2,"duplicate callback cannot pay batch twice")
    ui.free();level.free();finish()
