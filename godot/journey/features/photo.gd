extends "res://journey/core/feature.gd"
const SESSION := preload("res://journey/photo/session.gd")
const ARCHIVE := preload("res://journey/photo/archive.gd")
var session: Node
var favorites_only := false
var page := 0
var preset := "natural"
var pending_delete := ""
var deletion_identity := ""
var pending_record: Dictionary = {}
var pending_records: Array = []
const PAGE_SIZE := 6

func descriptor() -> Dictionary:
    return {"id":"photo", "name":"巡礼拍照", "summary":"暂停世界、画面重构图、色调调节、照片收藏与校验相册"}

func initial() -> Dictionary:
    return ARCHIVE.fresh()

func valid(candidate: Dictionary) -> bool:
    return ARCHIVE.valid(candidate)

func _directory() -> String:
    return context.store.directory.path_join(context.store.scope).path_join("photos")

func draw(parent: Control) -> void:
    header(parent, "从当前实际显示画面重构图。镜头不会越出进入拍照前的可见范围，也不移动角色或揭开地图。")
    var preset_picker := UI.pick(parent, ARCHIVE.presets(), preset)
    preset_picker.item_selected.connect(func(_index: int):preset = UI.chosen(preset_picker))
    UI.hint(parent, "预设仅影响拍照画面，退出拍照后不会改变游戏画面设置。")
    UI.button(parent, "进入拍照模式", _start, is_instance_valid(session) and session.active)
    UI.hint(parent, "拍照时当前世界暂停，角色界面隐藏；退出恢复原镜头、处理模式与界面。最多40张、总量128MiB，不自动删除照片。")
    if not pending_record.is_empty():
        UI.label(parent, "照片已写入，但相册索引暂未保存。图片文件仍在，可重试登记。")
        UI.button(parent, "重试保存相册索引", _retry_records)
    UI.divider(parent)
    UI.label(parent, "此存档槽的相册", true)
    var row := UI.row(parent)
    var query := UI.edit(row, "搜索地区、房间或照片手记", search)
    UI.button(row, "搜索", func():search = query.text;page = 0;context.refresh())
    UI.toggle(row, "仅收藏", favorites_only, func(value: bool):favorites_only = value;page = 0;context.refresh())
    var photos := ARCHIVE.records(data, search, favorites_only)
    page = clampi(page, 0, maxi(0, (photos.size() - 1) / PAGE_SIZE))
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():page -= 1;context.refresh(), page == 0)
    UI.label(navigation, "第%d页 · %d张" % [page + 1, photos.size()])
    UI.button(navigation, "下一页", func():page += 1;context.refresh(), (page + 1) * PAGE_SIZE >= photos.size())
    for index in range(page * PAGE_SIZE, mini(photos.size(), (page + 1) * PAGE_SIZE)):
        _photo_card(parent, photos[index])
    if photos.is_empty():
        UI.hint(parent, "尚无符合条件的照片。照片不会自动上传或分享。")
    UI.button(parent, "导出相册索引与手记", func():export_document("巡礼相册索引.txt", ARCHIVE.report(data)))

func _start() -> void:
    if not pending_records.is_empty():
        context.tell("请先重试登记已拍照片，再继续拍照。")
        return
    var owner: Node = context.level()
    if owner == null:
        return
    var snapshot: Dictionary = context.snapshot()
    context.finish()
    await owner.get_tree().process_frame
    if not is_instance_valid(owner) or not context.editable():
        return
    if is_instance_valid(session):
        shutdown()
    session = SESSION.new()
    session.options = ARCHIVE.camera_options(preset)
    session.directory = _directory()
    owner.get_tree().root.add_child(session)
    session.captured.connect(_captured)
    session.finished.connect(func():
        if is_instance_valid(session):
            session.queue_free()
        session = null)
    var outcome: Dictionary = session.begin(owner, snapshot)
    announce(outcome)
    if not outcome.get("ok", false):
        session.queue_free()
        session = null

func _captured(photo: Dictionary) -> void:
    if not pending_records.any(func(record: Dictionary): return record.path == photo.path):
        pending_records.append(photo.duplicate(true))
    _retry_records()

func _retry_records() -> void:
    while not pending_records.is_empty():
        var photo: Dictionary = pending_records[0]
        if data.photos.any(func(record: Dictionary): return record.path == photo.path):
            pending_records.pop_front()
            continue
        var candidate := ARCHIVE.add(data, photo)
        if candidate == data:
            context.tell("相册记录已满；照片与待登记队列已保留，请先整理索引。")
            break
        if not commit(candidate):
            break
        pending_records.pop_front()
    pending_record = pending_records[0].duplicate(true) if not pending_records.is_empty() else {}
    if is_instance_valid(session):
        session.capture_allowed = pending_records.is_empty()
    context.refresh()


func _photo_card(parent: Control, photo: Dictionary) -> void:
    var card := UI.card(parent)
    UI.label(card, ("★ " if photo.favorite else "") + String(photo.get("region", "旅途画面")))
    UI.hint(card, VALUES.date(int(photo.created)) + " · %d×%d" % [photo.width, photo.height])
    var inspection := ARCHIVE.inspect(photo, _directory())
    if inspection.get("ok", false):
        var image := Image.load_from_file(String(photo.path))
        if not image.is_empty():
            var preview := TextureRect.new()
            preview.texture = ImageTexture.create_from_image(image)
            preview.custom_minimum_size = Vector2(450, 230)
            preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            card.add_child(preview)
        UI.hint(card, "文件校验一致 · %.1f KiB" % (float(inspection.bytes) / 1024.0))
    else:
        UI.hint(card, String(inspection.reason))
    var path := String(photo.path)
    var note := UI.memo(card, String(photo.note), 70)
    var actions := UI.row(card)
    UI.button(actions, "保存手记", func():commit(ARCHIVE.annotate(data, path, note.text, bool(photo.favorite))))
    UI.button(actions, "取消收藏" if photo.favorite else "收藏", func():commit(ARCHIVE.annotate(data, path, note.text, not bool(photo.favorite))))
    UI.button(actions, "整理此照片", func():pending_delete = path;deletion_identity = String(photo.sha256);context.refresh())
    if pending_delete == path:
        UI.hint(card, "可仅移除索引，或在再次校验后删除这张照片文件。")
        var confirmation := UI.row(card)
        UI.button(confirmation, "保留", func():pending_delete = "";context.refresh())
        UI.button(confirmation, "仅移除相册索引", func():commit(ARCHIVE.remove(data, path));pending_delete = "")
        UI.button(confirmation, "确认删除照片文件", func():_delete_photo(photo))

func _delete_photo(photo: Dictionary) -> void:
    var inspection := ARCHIVE.inspect(photo, _directory(), true)
    if not inspection.get("ok", false) or String(photo.sha256) != deletion_identity:
        context.tell("照片身份已变化或无法复核；保留文件。")
        return
    var candidate := ARCHIVE.remove(data, String(photo.path))
    if not commit(candidate):
        return
    if DirAccess.remove_absolute(String(photo.path)) != OK:
        context.tell("索引已整理，但文件无法删除；可在用户目录手动整理。")
    else:
        context.tell("已删除经复核的照片文件。")
    pending_delete = ""

func release() -> void:
    # The workbench closes before a photo session begins. An active session
    # owns restoration and survives the hidden workbench window independently.
    pass

func shutdown() -> void:
    var previous := session
    session = null
    if is_instance_valid(previous):
        previous.end()
        previous.queue_free()

func restorable() -> bool:
    return not is_instance_valid(session) and pending_record.is_empty()
