extends RefCounted
## G02 late-game remote recovery. After REQUIRED_BOSSES region guardians fall,
## resting at any shrine offers to draw the return knot (dropped currency)
## back from wherever it lies, keeping only KEEP_RATIO of it. Walking to the
## knot still recovers everything, so the shrine is a convenience with a price.
## Never automatic: respawning or resting only offers, and cancel is focused.
const REQUIRED_BOSSES := 3
const KEEP_RATIO := 0.6
const DIALOG := "DeathRecallDialog"

static func bosses_defeated(flags: Dictionary) -> int:
    var count := 0
    for index in range(1,7):
        var value: Variant=flags.get("boss_down_ch%02d" % index,false)
        if value is bool and value:count+=1
    return count

static func quote(level: Node) -> Dictionary:
    if not level.world_mode or level.world_state == null: return {"ok": false, "reason": "world"}
    var cache: Dictionary = level.world_state.data.get("death_cache", {})
    if not preload("res://scripts/world_state.gd")._valid_death_cache(cache):return {"ok":false,"reason":"invalid_knot"}
    var amount := int(cache.get("currency", 0))
    if cache.is_empty() or amount <= 0: return {"ok": false, "reason": "no_knot"}
    if bosses_defeated(level.story_flags) < REQUIRED_BOSSES: return {"ok": false, "reason": "locked"}
    return {"ok": true, "amount": amount, "kept": int(floor(amount * KEEP_RATIO)), "region_id": String(cache.get("region_id", "")),"fingerprint":var_to_str([cache,level.currency_count]).sha256_text()}

static func setup(level: Node) -> void:
    if not level.world_mode or level.get_node_or_null(DIALOG) != null: return
    var dialog := ConfirmationDialog.new()
    dialog.name = DIALOG
    dialog.theme = level.ui_shell.theme.duplicate()
    dialog.theme.set_font("title_font", "Window", preload("res://assets/fonts/GlobalTypeface.otf"))
    dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialog.get_label().custom_minimum_size = Vector2(430, 90)
    # Join the tree before any text: shaping outside it costs ~4 ms per string.
    level.add_child(dialog)
    dialog.dialog_hide_on_ok=false
    if level.ui_shell.has_method("register_text_entry_window"):level.ui_shell.register_text_entry_window(dialog)
    dialog.title = "钟龛 · 召回归途结"
    dialog.ok_button_text = "召回"
    dialog.cancel_button_text = "亲自去取"
    var host: WeakRef = weakref(level)
    dialog.confirmed.connect(func():
        var owner: Variant = host.get_ref()
        if is_instance_valid(owner):
            var fresh:=quote(owner)
            if not fresh.get("ok",false):dialog.dialog_text="归途结已经变化，请关闭后重新安坐。";dialog.get_ok_button().disabled=true;return
            if String(fresh.fingerprint)!=String(dialog.get_meta("knot_fingerprint","")):
                offer(owner);dialog.dialog_text="归途结或钱包已变化，请重新核对后再次确认。\n"+dialog.dialog_text;return
            var result:=recall(owner)
            if result.get("ok",false):owner._close_overlays()
            else:dialog.dialog_text="尚未召回，碎钱与归途结保持原状。请重试或亲自去取。")
    dialog.canceled.connect(func():
        var owner: Variant = host.get_ref()
        if is_instance_valid(owner): owner._close_overlays())

static func offer(level: Node) -> bool:
    var quoted := quote(level)
    var dialog: ConfirmationDialog = level.get_node_or_null(DIALOG)
    if not quoted.ok or dialog == null or level.world_save_blocked or not level.is_near_shrine():return false
    dialog.set_meta("knot_fingerprint",quoted.fingerprint)
    dialog.get_ok_button().disabled=false
    var where := "本区" if quoted.region_id == String(level.config.get("id", "")) else "远处"
    dialog.dialog_text = "%s的归途结里留着%d枚碎钱。\n在钟龛召回只能收回%d枚（六成）；亲自去取可全数收回。" % [where, quoted.amount, quoted.kept]
    level.active_overlay = "recall"
    level._sync_ui_input_lock()
    dialog.popup_centered(Vector2i(480, 200))
    dialog.get_cancel_button().grab_focus()
    return true

static func recall(level: Node) -> Dictionary:
    var quoted := quote(level)
    if not quoted.ok: return quoted
    if level.world_loading or level.world_save_blocked or level.player==null or level.player.hp<=0 or level.active_overlay!="recall" or not level.is_near_shrine():return {"ok":false,"reason":"shrine"}
    var result: Dictionary=level._persist_world_change({"currency":level.currency_count+int(quoted.kept),"death_cache":{}})
    if not result.ok:return result
    level.world_state.data=result.candidate
    level.currency_count=int(result.candidate.currency)
    if is_instance_valid(level.death_cache_area):level.death_cache_area.queue_free()
    level.death_cache_area=null
    level._refresh_hud()
    level._toast("钟声把归途结引了回来：收回%d枚碎钱。" % int(quoted.kept))
    return quoted
