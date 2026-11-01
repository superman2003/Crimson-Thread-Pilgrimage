extends ConfirmationDialog
## The interact path previews a choice; only an explicit second action commits it.
const JOURNEY := preload("res://scripts/narrative_journey.gd")
const NAME := "EndingStoryDesk"
var host_ref: WeakRef
var gate_ref: WeakRef
var ending := ""
var region := ""
var fingerprint := ""
var phase := "preview"
var pages: Array = []
var page := 0
var reader: RichTextLabel

func _ready() -> void:
    dialog_hide_on_ok = false
    min_size = Vector2i(650, 440)
    reader = RichTextLabel.new()
    reader.custom_minimum_size = Vector2(590, 325)
    reader.add_theme_font_size_override("normal_font_size", 20)
    reader.bbcode_enabled = false
    reader.scroll_active = true
    add_child(reader)
    confirmed.connect(_confirm)
    canceled.connect(hide)
    close_requested.connect(hide)
    visibility_changed.connect(_visibility_changed)

static func open(level: Node, gate: Area2D) -> void:
    if not level.world_mode or level.world_narrative == null:
        level._activate_ending_gate(gate)
        return
    if not level._can_interact_with_world() or not is_instance_valid(gate):
        return
    var selected := String(level.world_narrative.restored_ending_flags(level.story_flags).get("ending_chosen", ""))
    var requested := String(gate.get_meta("ending", ""))
    if not selected.is_empty() and selected != requested:
        level._activate_ending_gate(gate)
        return
    var desk = level.get_node_or_null(NAME)
    if desk == null:
        desk = load("res://scripts/ending_story_desk.gd").new()
        desk.name = NAME
        desk.theme = level.ui_shell.theme
        level.add_child(desk)
        level.ui_shell.register_text_entry_window(desk)
    desk.host_ref = weakref(level)
    desk.gate_ref = weakref(gate)
    desk.ending = requested
    desk.region = String(level.config.get("id", ""))
    level.active_overlay = "ending_story"
    level._sync_ui_input_lock()
    if selected == requested:
        desk._show_epilogue(level)
    else:
        desk._show_preview(level)
    desk.popup_centered()
    desk.get_cancel_button().grab_focus()

func _quote(level: Node) -> Dictionary:
    var result: Dictionary = level.world_narrative.evaluate_ending(ending, level.inventory_counts, level.story_flags)
    result["fingerprint"] = var_to_str([result.get("available"), result.get("missing"), result.get("already_chosen"), result.get("message")]).sha256_text()
    return result

func _show_preview(level: Node, notice: String = "") -> void:
    phase = "preview"
    var quote := _quote(level)
    fingerprint = String(quote.fingerprint)
    title = "抉择 · " + String(quote.get("title", "结局"))
    var lines: Array[String] = []
    if not notice.is_empty():
        lines.append(notice + "\n")
    if bool(quote.get("available", false)):
        var choice := JOURNEY.decision(ending)
        lines.append(String(choice.get("action", "")))
        lines.append("\n留下什么\n" + String(choice.get("promise", "")))
        lines.append("\n承担什么\n" + String(choice.get("cost", "")))
        lines.append("\n" + String(choice.get("question", "")))
        lines.append("\n确认后将写入这次旅途；取消可以继续探索。")
    else:
        lines.append("此门尚未回应。你仍可以离开，寻找已知线索。")
        for requirement in quote.get("known_missing", []):
            lines.append(String(requirement.get("label", "")))
            if not String(requirement.get("hint", "")).is_empty():
                lines.append(String(requirement.hint))
        if int(quote.get("hidden_missing_count", 0)) > 0:
            lines.append("仍有尚未发现的证言。")
    reader.text = "\n".join(lines)
    reader.scroll_to_line(0)
    get_ok_button().text = "确认承担这一结果"
    get_ok_button().disabled = not bool(quote.get("available", false))
    get_cancel_button().text = "继续探索"

func _show_epilogue(level: Node) -> void:
    phase = "epilogue"
    pages = JOURNEY.epilogue(ending, level.story_flags)
    page = 0
    _show_page()

func _show_page() -> void:
    if pages.is_empty():
        hide()
        return
    var scene: Dictionary = pages[page]
    title = "尾声 · %s（%d / %d）" % [String(scene.title), page + 1, pages.size()]
    reader.text = String(scene.text) + "\n\n巡礼者 · " + String(scene.response)
    reader.scroll_to_line(0)
    get_ok_button().disabled = false
    get_ok_button().text = "下一幕" if page + 1 < pages.size() else "回到六城"
    get_cancel_button().text = "回到六城"

func _confirm() -> void:
    var level = host_ref.get_ref() if host_ref != null else null
    if not is_instance_valid(level) or level.active_overlay != "ending_story":
        hide()
        return
    if phase == "epilogue":
        if page + 1 >= pages.size():
            hide()
        else:
            page += 1
            _show_page()
        return
    var gate = gate_ref.get_ref() if gate_ref != null else null
    if not is_instance_valid(gate) or gate.is_queued_for_deletion() or gate.get_parent() != level or String(gate.get_meta("ending", "")) != ending or String(level.config.get("id", "")) != region or level.world_loading or level.chapter_transitioning or level.player == null or level.player.hp <= 0 or level.player.global_position.distance_to(gate.global_position) > level.INTERACTION_REACH:
        hide()
        return
    var fresh := _quote(level)
    if String(fresh.fingerprint) != fingerprint or not bool(fresh.get("available", false)):
        _show_preview(level, "证词或世界状态已变化，请重新核对。")
        get_cancel_button().grab_focus()
        return
    # Reuse the production transaction, including rollback on failed writes.
    level.active_overlay = ""
    level._activate_ending_gate(gate)
    level.active_overlay = "ending_story"
    level._sync_ui_input_lock()
    if String(level.story_flags.get("ending_chosen", "")) == ending:
        _show_epilogue(level)
    else:
        _show_preview(level, "归途记录未写入，选择尚未生效。可以重试或取消。")

func _visibility_changed() -> void:
    if visible:
        return
    var level = host_ref.get_ref() if host_ref != null else null
    if is_instance_valid(level) and level.active_overlay == "ending_story":
        level.active_overlay = ""
        level._sync_ui_input_lock()
