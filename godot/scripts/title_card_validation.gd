extends SceneTree
const CARD:=preload("res://scripts/title_card.gd")
const PAUSE:=preload("res://scripts/pause_menu.gd")
const LEVEL_HUD:=preload("res://scripts/level_hud.gd")
var checks:=0
var failures:=0
class World extends Node:
    var audio_director:=Node.new()
    var new_journey_dialog:=ConfirmationDialog.new()
    var win_label: Label = null
    var active_overlay:=""
    var locks:=0
    func _ready() -> void:add_child(audio_director);add_child(new_journey_dialog)
    func _sync_ui_input_lock() -> void:locks+=1
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func world() -> World:
    var node:=World.new();root.add_child(node);return node
func run() -> void:
    var level:=world();await process_frame
    var none:=PackedStringArray()
    check(not CARD.wanted(level,"x11",none),"a World instantiated by a harness is not the launched scene")
    current_scene=level
    check(CARD.wanted(level,"x11",none),"a launched World wants the title")
    check(not CARD.wanted(level,"headless",none),"headless launch has no title")
    for argument in ["--skip-title","--new-game","--save-slot=2","--script","-s","--quit-after","--quit-after=30"]:
        check(not CARD.wanted(level,"x11",PackedStringArray([argument])),"automation argument skips the title: "+argument)
    check(CARD.present(level,true)==null and not paused,"this headless run shows nothing and does not pause")
    # Returning journey: three choices, world held, music node kept alive.
    var card: Node=CARD.open(level,true);await process_frame
    check(paused and level.audio_director.process_mode==Node.PROCESS_MODE_ALWAYS,"world held, music keeps processing")
    check(card.process_mode==Node.PROCESS_MODE_ALWAYS and card.buttons.keys()==["continue","new","achievements","quit"],"card stays responsive with its choices")
    check(card.buttons["continue"].text=="继续旅途" and card.buttons["continue"].has_focus(),"continue is focused for keyboard and gamepad")
    check(not CARD.wanted(level,"x11",none),"the title is shown once per run")
    var picked: Array[String]=[]
    card.chosen.connect(func(action: String):picked.append(action))
    card.buttons["continue"].pressed.emit();await process_frame
    check(picked==["continue"] and not paused and not is_instance_valid(card),"continue releases the world and removes the card")
    check(level.audio_director.process_mode==Node.PROCESS_MODE_INHERIT and level.active_overlay=="","continue restores audio processing and opens nothing")
    # New journey goes through the existing confirmation.
    card=CARD.open(level,true);await process_frame
    card.buttons["new"].pressed.emit()
    card.choose("new")
    check(level.locks==1,"a card being removed ignores further presses")
    await process_frame
    check(not paused and level.new_journey_dialog.visible and level.active_overlay=="new_journey","new journey opens the existing confirmation with input locked")
    level.new_journey_dialog.hide()
    # First launch: nothing to replace.
    level.active_overlay=""
    card=CARD.open(level,false);await process_frame
    check(card.buttons.keys()==["continue","achievements","quit"] and card.buttons["continue"].text=="开始旅途","first launch has no journey to replace")
    card.buttons["continue"].pressed.emit();await process_frame
    check(not paused,"start releases the world")
    CARD.shown=false
    # Pause menu holds the world without triggering ui_input_locked (preserving active heals) and restores audio mode.
    var pause_menu: Node=PAUSE.open(level);await process_frame
    check(paused and PAUSE.is_open(level) and level.audio_director.process_mode==Node.PROCESS_MODE_ALWAYS,"pause menu holds world while keeping audio processing")
    check(level.locks==1 and level.active_overlay=="","pause menu does not trigger ui_input_locked or cancel active heals")
    pause_menu.buttons["resume"].pressed.emit();await process_frame
    check(not paused and not PAUSE.is_open(level) and level.audio_director.process_mode==Node.PROCESS_MODE_INHERIT,"resume releases pause menu cleanly")
    # Win banner auto-fades after 6.5s.
    var win := Label.new()
    win.text = "守门者已败"
    win.visible = true
    level.win_label = win
    LEVEL_HUD.tick_win_label(level, 0.1)
    check(win.visible and is_equal_approx(win.modulate.a, 1.0), "win banner stays fully visible immediately")
    LEVEL_HUD.tick_win_label(level, 5.75)
    check(win.visible and win.modulate.a < 0.75 and win.modulate.a > 0.25, "win banner fades smoothly after 5 seconds")
    LEVEL_HUD.tick_win_label(level, 1.0)
    check(not win.visible and is_equal_approx(win.modulate.a, 1.0), "win banner hides after fade completes")
    level.win_label = null
    win.free()
    level.queue_free();await process_frame
    print("TITLE_CARD checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
