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
    for key in flags:
        if String(key).begins_with("boss_down_") and bool(flags[key]): count += 1
    return count

static func quote(level: Node) -> Dictionary:
    if not level.world_mode or level.world_state == null: return {"ok": false, "reason": "world"}
    var cache: Dictionary = level.world_state.data.get("death_cache", {})
    var amount := int(cache.get("currency", 0))
    if cache.is_empty() or amount <= 0: return {"ok": false, "reason": "no_knot"}
    if bosses_defeated(level.story_flags) < REQUIRED_BOSSES: return {"ok": false, "reason": "locked"}
    return {"ok": true, "amount": amount, "kept": int(floor(amount * KEEP_RATIO)), "region_id": String(cache.get("region_id", ""))}

static func setup(level: Node) -> void:
    if not level.world_mode or level.get_node_or_null(DIALOG) != null: return
    var dialog := ConfirmationDialog.new()
    dialog.name = DIALOG
    dialog.theme = level.ui_shell.theme.duplicate()
    dialog.theme.set_font("title_font", "Window", preload("res://assets/fonts/NotoSansSC.ttf"))
    dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialog.get_label().custom_minimum_size = Vector2(430, 90)
    dialog.title = "钟龛 · 召回归途结"
    dialog.ok_button_text = "召回"
    dialog.cancel_button_text = "亲自去取"
    level.add_child(dialog)
    var host: WeakRef = weakref(level)
    dialog.confirmed.connect(func():
        var owner: Variant = host.get_ref()
        if is_instance_valid(owner):
            recall(owner)
            owner._close_overlays())
    dialog.canceled.connect(func():
        var owner: Variant = host.get_ref()
        if is_instance_valid(owner): owner._close_overlays())

static func offer(level: Node) -> bool:
    var quoted := quote(level)
    var dialog: ConfirmationDialog = level.get_node_or_null(DIALOG)
    if not quoted.ok or dialog == null: return false
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
    level._add_currency(int(quoted.kept))
    level.world_state.capture_global({"death_cache": {}})
    if level.death_cache_area != null and is_instance_valid(level.death_cache_area):
        level.death_cache_area.queue_free()
    level.death_cache_area = null
    level._save_world()
    level._refresh_hud()
    level._toast("钟声把归途结引了回来：收回%d枚碎钱。" % int(quoted.kept))
    return quoted
