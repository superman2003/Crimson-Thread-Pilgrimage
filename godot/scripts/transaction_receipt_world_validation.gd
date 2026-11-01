extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const MARKET:=preload("res://scripts/material_exchange.gd")
const OWNER:=preload("res://scripts/field_receipt_owner.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func snapshot(world: Node) -> String:
    return var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy,world.player.global_position])
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://transaction_receipt_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    for child in world.get_children():
        if child is Area2D and child.get_meta("kind","")=="save_point":world.player.global_position=child.global_position;break
    await physics_frame;await physics_frame
    world._toggle_build();await process_frame
    var desk: Node=world.ui_shell.get_node("MaterialExchangeDesk")
    world.ui_shell.build_panel.get_node("MaterialExchangeButton").pressed.emit();await process_frame
    var recipe: Dictionary=MARKET.recipes()[1]
    check(world.world_state.capture_region(String(recipe.target_region),{}),"fixture records canonical adjacent region for exchange")
    world.inventory_counts[recipe.requires_item]=1;world.inventory_counts[recipe.input]=30;world.inventory_counts[recipe.output]=0;world.currency_count=100
    check(world._save_world(),"fixture saves actual exchange resources before observing")
    desk.open();var ledger: Variant=OWNER.for_level(world)
    check(ledger.report().rows.is_empty(),"reader initialization cannot fabricate a settlement")
    var quote:=MARKET.quote(world,String(recipe.id),2)
    check(quote.ok and ledger.report().rows.is_empty(),"actual two-batch preview is not a recorded trade")
    var before:=snapshot(world);var disk:=FileAccess.get_file_as_bytes(world.world_save_path)
    world.world_save_failure_injected_for_validation=true
    var failed:=MARKET.perform(world,String(recipe.id),2,String(quote.fingerprint))
    check(not failed.ok and ledger.report().rows.is_empty(),"failed authoritative save creates zero receipts")
    check(snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==disk,"failed write leaves both wallet and disk unchanged")
    world.world_save_failure_injected_for_validation=false
    check(MARKET.perform(world,String(recipe.id),2,String(quote.fingerprint)).ok,"canonical material exchange commits through real field transaction")
    var receipt: Dictionary=ledger.report().rows[0]
    check(ledger.report().rows.size()==1 and receipt.currency_before==100 and receipt.currency_after==84,"one durable trade makes one exact currency receipt")
    var input_change: Dictionary={};var output_change: Dictionary={}
    for item in receipt.items:
        if item.item==recipe.input:input_change=item
        if item.item==recipe.output:output_change=item
    check(input_change.before==30 and input_change.after==24 and output_change.before==0 and output_change.after==2,"receipt matches actual canonical material balances")
    check(not MARKET.perform(world,String(recipe.id),2,String(quote.fingerprint)).ok and ledger.report().rows.size()==1,"stale confirmation cannot create a duplicate receipt")
    var launcher:=desk.window.find_child("FieldReceiptsButton",true,false) as Button
    check(launcher!=null and launcher.is_visible_in_tree(),"actual material window exposes owned receipt entry")
    launcher.pressed.emit();await process_frame
    var dialog: Node=desk.receipts
    check(dialog.visible and dialog.query.has_focus() and world.player.ui_input_locked,"actual reader retains build overlay ownership and keyboard focus")
    check(dialog.rows.size()==1 and dialog.detail.text.contains("100 → 84") and dialog.detail.text.contains(world._item_display_name(String(recipe.input))),"actual UI displays human item names and accepted balances")
    dialog.filter_kind.select(1);dialog.filter_kind.item_selected.emit(1)
    check(dialog.rows.size()==1,"spending filter retains the actual mixed exchange")
    dialog.filter_kind.select(2);dialog.filter_kind.item_selected.emit(2)
    check(dialog.rows.size()==1,"income filter retains the actual received material")
    dialog.query.text=String(recipe.input);dialog.query.text_changed.emit(dialog.query.text)
    check(dialog.rows.is_empty(),"raw inventory ID is not searchable public receipt content")
    dialog.query.text=world._item_display_name(String(recipe.input));dialog.query.text_changed.emit(dialog.query.text)
    check(dialog.rows.size()==1,"public material label restores actual receipt")
    dialog.ask_clear()
    check(dialog.confirm.visible and dialog.confirm.get_cancel_button().has_focus(),"destructive local-only clear defaults to cancel")
    var next:=MARKET.quote(world,String(recipe.id),1)
    check(next.ok and MARKET.perform(world,String(recipe.id),1,String(next.fingerprint)).ok,"second canonical settlement can arrive after clear preview")
    await process_frame
    check(dialog.rows.size()==2 and ledger.report().rows.size()==2,"open viewer refreshes on accepted ledger revision")
    dialog.confirm_clear()
    check(ledger.report().rows.size()==2 and dialog.status.text.contains("新变化"),"stale clear cannot discard newly accepted settlement")
    dialog.ask_clear();dialog.confirm.get_cancel_button().pressed.emit();await process_frame
    check(ledger.report().rows.size()==2 and dialog.pending_clear<0,"native cancel preserves session receipts and retires pending clear")
    var accepted:=snapshot(world);var accepted_disk:=FileAccess.get_file_as_bytes(world.world_save_path)
    dialog.ask_clear();dialog.confirm_clear()
    check(ledger.report().rows.is_empty() and dialog.rows.is_empty(),"fresh confirmed clear affects only local receipt display")
    check(snapshot(world)==accepted and FileAccess.get_file_as_bytes(world.world_save_path)==accepted_disk,"reading filtering and clearing never rewrite accepted gameplay state or bytes")
    desk.window.hide();await process_frame
    check(not dialog.visible and dialog.ledger==null and dialog.detail.text.is_empty(),"closing material owner releases reader snapshot")
    dialog.refresh();check(dialog.ledger==null,"hidden late refresh cannot recreate reader context")
    desk.open();desk.open_receipts();await process_frame
    check(dialog.visible and dialog.query.text.is_empty() and dialog.filter_kind.selected==0,"reopen has fresh explicit filters")
    world._close_overlays();await process_frame
    check(not dialog.visible and not world.player.ui_input_locked,"build close retires child and restores input")
    check(snapshot(world)==accepted and FileAccess.get_file_as_bytes(world.world_save_path)==accepted_disk,"closing cannot undo trade or grant material again")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://transaction_receipt_world.json"+suffix))
    print("TRANSACTION_RECEIPTS_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
