extends Node
var ui: Control
var curriculum:=preload("res://scripts/practice_curriculum.gd").new()
var window: AcceptDialog
var list: ItemList
var search: LineEdit
var completion_filter: OptionButton
var start_button: Button
var detail: RichTextLabel
var progress_label: Label
var hud: Label
var available: Array=[]
var selected:=""
var origin:=Vector2.ZERO
var region:=""
var player: Node
var elapsed:=0.0

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="PracticeDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell;curriculum.configure(String(ui.level.world_save_path))
    var button: Button=ui._button(ui.build_panel,"分阶段训练课程",Vector2(450,103),Vector2(175,30),open)
    button.name="PracticeDeskButton";button.add_theme_font_size_override("font_size",14)
    hud=ui._label(ui,"",Vector2(372,155),Vector2(510,60),14,ui.GOLD)
    hud.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud.clip_text=true

func near_rack() -> Node2D:
    if not is_instance_valid(ui.level.player):return null
    for target in get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(target) or not target is Node2D or not (target.has_meta("seal_training_target") or target.has_meta("tool_training_target")):continue
        if target.has_method("world_residency_active") and not target.world_residency_active():continue
        if target.global_position.distance_to(ui.level.player.global_position)<=520.0:return target
    return null

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.name="PracticeDeskWindow"
    ui.build_panel.add_child(window);window.title="分阶段训练课程";window.bind_overlay(ui,ui.build_panel)
    window.text(window.column,"十二项单项/组合课程随已获能力开放。需在真实练习架520像素范围内开始；离场、倒下或五分钟超时会结束。",48)
    var filters: HBoxContainer=window.row(window.column)
    search=window.search(filters,"搜索已开放课程与操作说明",func(_value: String):refresh())
    completion_filter=OptionButton.new();filters.add_child(completion_filter)
    for title_text in ["全部已开放","尚未完成","已有完成记录"]:completion_filter.add_item(title_text)
    completion_filter.item_selected.connect(func(_index: int):refresh())
    var columns: HBoxContainer=window.row(window.column)
    list=ItemList.new();list.custom_minimum_size=Vector2(310,275);columns.add_child(list)
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(580,275);columns.add_child(detail)
    list.item_selected.connect(func(index: int):selected=String(available[index].id);_selection())
    progress_label=window.text(window.column,"",52)
    var controls: HBoxContainer=window.row(window.column)
    start_button=window.button(controls,"开始所选课程",start_selected)
    window.button(controls,"结束本次训练",func():curriculum.finish(false,"主动结束");refresh())
    window.button(controls,"重试保存记录",func():curriculum.retry();refresh())
    window.footer()

func open() -> void:
    if not ui.build_panel.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    refresh();window.popup_centered();list.grab_focus()

func refresh() -> void:
    available=curriculum.browse(ui.level.inventory_counts,search.text,completion_filter.selected)
    list.clear()
    for index in available.size():
        var course: Dictionary=available[index]
        var best: float=curriculum.best(String(course.id))
        list.add_item(String(course.title)+( " · %.1f秒" % best if best<INF else " · 未完成"))
        if selected==course.id:list.select(index)
    if list.get_selected_items().is_empty() and not available.is_empty():selected=String(available[0].id);list.select(0)
    if available.is_empty():selected=""
    start_button.disabled=selected.is_empty()
    _selection()
    progress_label.text=curriculum.progress()
    window.status.text="符合筛选%d / 已开放%d。" % [available.size(),curriculum.available(ui.level.inventory_counts).size()]+("附近有可用练习架。" if near_rack()!=null else "附近没有练习架；本页可先阅读，前往练习区后开始。")+curriculum.store.error

func _selection() -> void:
    var keys:={}
    for action in ui.REMAPPABLE_ACTIONS:keys[action]=ui._short_binding(action)
    detail.text="没有符合筛选的已开放课程；清空搜索或切换完成状态。"
    for course in available:
        if course.id!=selected:continue
        var lines: Array[String]=[String(course.title),String(course.hint).format(keys),"\n训练顺序"]
        for stage in course.stages:lines.append("· %s × %d" % [String(stage.label),int(stage.count)])
        lines.append("\n只统计实际接受的动作；失败施放、格挡架势和中断疗伤不算完成。课程不补充生命、绯线、战具，不授予校习资格。")
        var recent: Array=curriculum.recent(selected,ui.level.inventory_counts)
        lines.append("\n"+preload("res://scripts/practice_attempt_review.gd").summary(curriculum.history,selected))
        lines.append("\n最近已保存的训练记录" if not recent.is_empty() else "\n尚无已保存的训练记录。")
        for record in recent:
            lines.append("· %s · %.1f秒 · %s" % ["完成" if record.complete else "未完成",float(record.seconds),String(record.reason)])
            lines.append(preload("res://scripts/practice_attempt_review.gd").describe(record))
        detail.text="\n".join(lines)

func start_selected() -> void:
    if selected.is_empty() or not available.any(func(course):return course.id==selected):
        window.status.text="请先选择符合筛选的已开放课程。";return
    var rack:=near_rack()
    if rack==null:window.status.text="请先到真实练习架附近。";return
    var result: Dictionary=curriculum.start(selected,ui.level.inventory_counts)
    if result.ok:
        origin=rack.global_position;region=String(ui.level.config.id)
        window.hide();ui.level._close_overlays()
    else:window.status.text=String(result.reason)

func _bind_player() -> void:
    if player==ui.level.player:return
    if is_instance_valid(player):
        if player.ability_action.is_connected(_ability):player.ability_action.disconnect(_ability)
        if player.heal_state_changed.is_connected(_heal):player.heal_state_changed.disconnect(_heal)
        if player.skill_cast.is_connected(_skill):player.skill_cast.disconnect(_skill)
    player=ui.level.player
    if is_instance_valid(player):
        player.ability_action.connect(_ability);player.heal_state_changed.connect(_heal);player.skill_cast.connect(_skill)

func _eligible() -> bool:
    return is_instance_valid(player) and not curriculum.active.is_empty() and String(ui.level.active_overlay).is_empty() and not ui.level.world_loading and player.hp>0 and player.global_position.distance_to(origin)<=520.0

func _ability(id: String, _point: Vector2, _direction: Vector2) -> void:
    if not _eligible():return
    if id=="bell_guard" and not player.guard_refunded:return
    _accept(id)

func _heal(state: String) -> void:
    if _eligible() and state=="completed":_accept("heal")

func _skill(_id: String) -> void:
    if _eligible():_accept("skill")

func _accept(action: String) -> void:
    if not curriculum.accept(action,Engine.get_physics_frames()):return
    if curriculum.active.is_empty():ui.level._toast("课程完成。记录已保存，可在训练课程查看。" if curriculum.pending.is_empty() else "课程完成，记录未写入；请打开训练课程重试保存。")

func _process(delta: float) -> void:
    if not is_instance_valid(ui) or not ui.construction_complete:return
    _bind_player()
    if not curriculum.active.is_empty() and is_instance_valid(player):
        if player.hp<=0:curriculum.finish(false,"倒下")
        elif String(ui.level.config.id)!=region or player.global_position.distance_to(origin)>520.0:curriculum.finish(false,"离开练习范围")
        elif float(curriculum.active.seconds)>=300.0:curriculum.finish(false,"训练超时")
        elif _eligible():curriculum.tick(delta)
    hud.visible=not curriculum.active.is_empty() and String(ui.level.active_overlay).is_empty()
    if hud.visible:hud.text=curriculum.progress()
    elapsed+=delta
    if elapsed>=0.25:
        elapsed=0.0
        if is_instance_valid(window) and window.visible:progress_label.text=curriculum.progress()

func _exit_tree() -> void:
    if not curriculum.active.is_empty():curriculum.finish(false,"练习界面退场")
