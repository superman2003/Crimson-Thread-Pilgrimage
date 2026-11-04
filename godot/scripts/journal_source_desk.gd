extends AcceptDialog
## A detached source reader preserves the original filter, scroll and marks.
const SOURCES := preload("res://scripts/journal_sources.gd")
var host_ref: WeakRef
var chooser: OptionButton
var previous: Button
var next: Button
var heading: Label
var body: RichTextLabel
var origin_key := ""
var origin_hash := ""
var scope := ""
var generation := -1
var rows: Array[Dictionary] = []

func _ready() -> void:
    title = "旅记 · 回看来源"
    min_size = Vector2i(900, 550)
    get_ok_button().text = "返回原文"
    confirmed.connect(_restore_focus)
    canceled.connect(_restore_focus)
    visibility_changed.connect(func():
        if not visible:
            rows.clear()
            origin_key = ""
            origin_hash = ""
            scope = ""
            generation = -1
            if is_instance_valid(body):
                body.text = ""
                heading.text = ""
                chooser.clear())

func ensure_built() -> void:
    if is_instance_valid(body):
        return
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(840, 440)
    column.add_theme_constant_override("separation", 10)
    add_child(column)
    var intro := Label.new()
    intro.text = "只回看本条引用的已知原始记录；关闭后回到原文。不会标为已读或推进委托。"
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(intro)
    var tools := HBoxContainer.new()
    column.add_child(tools)
    previous = Button.new()
    previous.text = "上一条"
    tools.add_child(previous)
    chooser = OptionButton.new()
    chooser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tools.add_child(chooser)
    next = Button.new()
    next.text = "下一条"
    tools.add_child(next)
    chooser.item_selected.connect(select_source)
    previous.pressed.connect(func(): select_source(posmod(chooser.selected - 1, rows.size())) if not rows.is_empty() else refresh_binding())
    next.pressed.connect(func(): select_source(posmod(chooser.selected + 1, rows.size())) if not rows.is_empty() else refresh_binding())
    heading = Label.new()
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(heading)
    body = RichTextLabel.new()
    body.bbcode_enabled = false
    body.selection_enabled = true
    body.custom_minimum_size = Vector2(840, 340)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(body)

func _host() -> Control:
    var host: Control = host_ref.get_ref() if host_ref != null else null
    return host if is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() else null

func _available(host: Control) -> bool:
    return host != null and host.bag.is_visible_in_tree() and host.bag_category == "旅记" and not host.level.world_loading and not host.level.chapter_transitioning

func _bound() -> bool:
    var host := _host()
    return _available(host) and String(host.level.world_save_path) == scope and host.reading_session_generation == generation \
        and String(host.journal_current_document.get("key", "")) == origin_key \
        and String(host.journal_current_document.get("fingerprint", "")) == origin_hash

func refresh_binding() -> void:
    if visible and not _bound():
        hide()

func open_for(host: Control) -> void:
    if visible:
        hide()
    host_ref = weakref(host)
    if not _available(host):
        return
    origin_key = String(host.journal_current_document.get("key", ""))
    rows = SOURCES.links(origin_key, host.level.inventory_counts, host.level.story_flags)
    if rows.is_empty():
        return
    ensure_built()
    origin_hash = String(host.journal_current_document.get("fingerprint", ""))
    scope = String(host.level.world_save_path)
    generation = int(host.reading_session_generation)
    var reading: Variant = host.accessibility.get("subtitle_size", 21)
    var font := clampi(int(reading), 17, 26) if typeof(reading) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(reading)) else 21
    body.add_theme_font_size_override("normal_font_size", font)
    chooser.clear()
    for row in rows:
        chooser.add_item(String(row.title))
    popup_centered()
    select_source(0)
    chooser.grab_focus()

func select_source(index: int) -> void:
    if not visible or not _bound() or index < 0 or index >= rows.size():
        hide()
        return
    # Re-resolve on every selection. A stale popup cannot retain a removed
    # possession, a different slot's source or a withdrawn observation.
    var host := _host()
    var fresh := SOURCES.links(origin_key, host.level.inventory_counts, host.level.story_flags)
    var matches := fresh.filter(func(row): return row.key == rows[index].key)
    if matches.size() != 1:
        hide()
        return
    chooser.select(index)
    var source: Dictionary = matches[0]
    var presentation: Dictionary = host._journal_presentation(source.entry)
    heading.text = "%d / %d · %s · %s" % [index + 1, rows.size(), source.title, presentation.category]
    body.text = String(presentation.text)
    body.scroll_to_line(0)
    previous.disabled = rows.size() <= 1
    next.disabled = previous.disabled

func _restore_focus() -> void:
    var host := _host()
    if _available(host) and not host.bag_pin.disabled:
        host.bag_pin.grab_focus()
