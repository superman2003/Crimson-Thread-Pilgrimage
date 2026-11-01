extends SceneTree
const MARKET:=preload("res://scripts/material_exchange.gd")
const DESK:=preload("res://scripts/material_exchange_desk.gd")
const STATE:=preload("res://scripts/world_state.gd")
const BUILD:=preload("res://scripts/build_system.gd")
var checks:=0
var failures:=0
class Player extends Node:
    var hp:=5
class Level extends Node:
    var world_mode:=true
    var world_loading:=false
    var chapter_transitioning:=false
    var world_save_blocked:=false
    var active_overlay:="build"
    var near:=true
    var config: Dictionary
    var world_state:=STATE.new()
    var build_system:=BUILD.new()
    var inventory_counts: Dictionary={}
    var story_flags: Dictionary={}
    var currency_count: Variant=100
    var player: Node
    var ui_shell: Control
    func is_near_shrine() -> bool:return near
    func _item_display_name(id: String) -> String:return id
class UI extends Control:
    var level: Node
    var build_panel: Control
    func register_text_entry_window(_window: Window) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func run() -> void:
    var level:=Level.new();root.add_child(level);var player:=Player.new();level.add_child(player);level.player=player
    var ui:=UI.new();root.add_child(ui);ui.level=level;ui.build_panel=Control.new();ui.add_child(ui.build_panel);level.ui_shell=ui
    var recipe: Dictionary=MARKET.recipes()[1];var id:=String(recipe.id)
    level.config={"id":recipe.region};level.world_state.data.regions[recipe.target_region]=STATE.fresh_region()
    level.inventory_counts={recipe.requires_item:1,recipe.input:7,recipe.output:0}
    var original:=level.inventory_counts.duplicate(true)
    check(MARKET.maximum(level,id).maximum==2,"maximum respects source-material cost")
    check(level.inventory_counts==original and level.currency_count==100,"maximum preview has no payment or inventory effect")
    level.inventory_counts[recipe.input]=30;level.currency_count=17
    check(MARKET.maximum(level,id).maximum==2,"currency independently limits the maximum")
    level.currency_count=1000;level.inventory_counts[recipe.output]=999998
    check(MARKET.maximum(level,id).maximum==1,"target save capacity limits the maximum")
    level.inventory_counts[recipe.output]=0
    check(MARKET.maximum(level,id).maximum==10,"maximum cannot exceed the canonical ten-batch limit")
    level.inventory_counts[recipe.requires_item]=0
    check(not MARKET.maximum(level,id).ok and MARKET.maximum(level,id).maximum==0,"missing permit prevents maximum selection")
    level.inventory_counts[recipe.requires_item]=1
    for invalid in [true,-1,0.5,NAN,INF,"30"]:
        level.inventory_counts[recipe.input]=invalid
        check(MARKET.maximum(level,id).maximum==0,"invalid material counters cannot produce an affordable maximum")
    level.inventory_counts[recipe.input]=30
    for invalid in [true,-1,0.5,NAN,INF,"100"]:
        level.currency_count=invalid
        check(MARKET.maximum(level,id).maximum==0,"invalid currency counters cannot produce an affordable maximum")
    level.currency_count=100;level.near=false
    check(not MARKET.maximum(level,id).ok,"outside the real bell condition no maximum is offered")
    level.near=true;level.world_state.data.regions.clear()
    check(not MARKET.maximum(level,id).ok,"unknown neighboring regions cannot become exchange options")
    level.world_state.data.regions[recipe.target_region]=STATE.fresh_region();level.currency_count=17
    var desk:=DESK.new();ui.add_child(desk);desk.ui=ui;desk._build();desk.open()
    check(not desk.maximum_button.disabled and desk.detail.text.contains("最多可兑换2份"),"native exchange menu displays the current canonical maximum")
    original=level.inventory_counts.duplicate(true)
    desk.maximum_button.pressed.emit()
    check(desk.amount.value==2 and not desk.review_button.disabled and desk.pending.is_empty(),"maximum button only selects the amount for a later confirmation")
    check(level.inventory_counts==original and level.currency_count==17,"native maximum selection consumes nothing")
    desk.ask();check(desk.confirm.visible and desk.pending.amount==2,"selected maximum still requires the original confirmation")
    level.currency_count=8;desk.maximum_button.pressed.emit()
    check(desk.amount.value==1 and not desk.confirm.visible and desk.pending.is_empty(),"fresh maximum selection closes an obsolete pending confirmation")
    desk.amount.set_value_no_signal(2);desk.refresh()
    check(desk.review_button.disabled and not desk.maximum_button.disabled,"unaffordable manual amount can be corrected to the current maximum")
    desk.maximum_button.pressed.emit();desk.window.hide();var amount:=desk.amount.value;level.currency_count=80;desk.select_maximum()
    check(desk.amount.value==amount,"hidden menu cannot change its pending amount")
    level.world_state.data.regions.clear();desk.open()
    check(desk.rows.is_empty() and desk.maximum_button.disabled and desk.review_button.disabled,"empty public market disables both maximum and exchange actions")
    ui.free();level.free()
    print("MATERIAL_EXCHANGE_MAXIMUM checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
