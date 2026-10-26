extends Node
var ui: Control
var ledger:=preload("res://scripts/combat_ledger.gd").new()
var window: AcceptDialog
var list: ItemList
var query: LineEdit
var mode: OptionButton
var detail: RichTextLabel
var live: Label
var hud: Label
var visible_records: Array=[]
var selected:=0
var compare:=false
var player: Node
var energy_before:=0
var elapsed:=0.0

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="CombatDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell;ledger.configure(String(ui.level.world_save_path))
    var button: Button=ui._button(ui.bag,"战斗观察与复盘",Vector2(910,99),Vector2(170,30),open)
    button.name="CombatDeskButton";button.add_theme_font_size_override("font_size",14)
    hud=ui._label(ui,"",Vector2(895,345),Vector2(355,42),13,ui.MUTED)
    hud.clip_text=true

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.name="CombatDeskWindow"
    ui.bag.add_child(window);window.title="战斗观察与复盘";window.bind_overlay(ui,ui.bag)
    window.text(window.column,"手动开始一次观察，记录真实命中、承伤、格挡、疗伤与资源流动。倒下或界面退场结束，最多保留20次。",42)
    var filters: HBoxContainer=window.row(window.column)
    query=window.search(filters,"搜索已记录地区、日期或结束原因",func(_text: String):refresh())
    mode=OptionButton.new();filters.add_child(mode)
    for title_text in ["全部记录","倒下","主动结束","界面退场"]:mode.add_item(title_text)
    mode.item_selected.connect(func(_index: int):selected=0;refresh())
    var columns: HBoxContainer=window.row(window.column)
    list=ItemList.new();list.custom_minimum_size=Vector2(285,270);columns.add_child(list)
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(605,270);columns.add_child(detail)
    list.item_selected.connect(func(index: int):selected=index;_selection())
    live=window.text(window.column,"",42)
    var actions: HBoxContainer=window.row(window.column)
    window.button(actions,"开始观察",start_observation)
    window.button(actions,"结束并保存",func():ledger.finish("主动结束");refresh())
    window.button(actions,"重试保存",func():ledger.retry();refresh())
    window.button(actions,"比较较早一条",func():compare=not compare;_selection())
    window.button(actions,"导出所选复盘",export_selected)
    window.footer()

func open() -> void:
    if not ui.bag.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    refresh();window.popup_centered();query.grab_focus()

func refresh() -> void:
    visible_records=[]
    var token:=query.text.to_lower().strip_edges()
    for record in ledger.history:
        if mode.selected>0 and record.reason!=["","倒下","主动结束","界面退场"][mode.selected]:continue
        var public_text: String=String(record.title)+" "+String(record.date)+" "+String(record.reason)
        if not token.is_empty() and not public_text.to_lower().contains(token):continue
        visible_records.append(record)
    list.clear()
    for record in visible_records:list.add_item("%s · %.0f秒 · %s" % [String(record.title),float(record.seconds),String(record.reason)])
    selected=clampi(selected,0,maxi(0,list.item_count-1))
    if list.item_count>0:list.select(selected)
    _selection()
    live.text="观察中：%.1f秒，针击%d，承伤%d。" % [float(ledger.active.seconds),int(ledger.active.hits),int(ledger.active.incoming)] if not ledger.active.is_empty() else "有待保存复盘，请重试。" if not ledger.pending.is_empty() else "没有正在进行的观察。"
    window.status.text="历史 %d/20 · %s" % [ledger.history.size(),ledger.store.error]

func _selection() -> void:
    if visible_records.is_empty():detail.text="没有符合条件的复盘。开始观察后照常游玩，结束时保存。";return
    var previous: Dictionary=visible_records[selected+1] if compare and selected+1<visible_records.size() else {}
    detail.text=ledger.report(visible_records[selected],previous)

func start_observation() -> void:
    if ui.level.world_loading or not is_instance_valid(ui.level.player) or ui.level.player.hp<=0:window.status.text="等待角色与地区就绪。";return
    var training: Node=ui.get_node_or_null("PracticeDesk")
    if training!=null and not training.curriculum.active.is_empty():window.status.text="先结束训练课程，再开始战斗观察。";return
    var crest: Dictionary=ui.level.build_system.catalog.crests.get(String(ui.level.build_system.state.get("crest","")),{})
    var result: Dictionary=ledger.start(String(ui.level.config.id),String(ui.level.config.get("chapter_name","当前地区")),String(crest.get("name","当前契印")))
    if result.ok:
        _bind_player();window.hide();ui.level._close_overlays()
    else:window.status.text=String(result.reason)

func export_selected() -> void:
    if visible_records.is_empty():window.status.text="请选择一条已有复盘。";return
    var path: String=ledger.store.path.get_basename()+"_report.txt"
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null:window.status.text="复盘导出失败。";return
    file.store_string(ledger.report(visible_records[selected]));file.flush()
    var result:=file.get_error();file.close()
    window.status.text="已导出："+ProjectSettings.globalize_path(path) if result==OK else "复盘导出失败。"

func _bind_player() -> void:
    if player==ui.level.player:return
    if is_instance_valid(player):
        for pair in [["combat_observed",_contact],["energy_changed",_energy],["heal_state_changed",_heal],["skill_cast",_cast],["player_respawned",_respawn]]:
            if player.is_connected(pair[0],pair[1]):player.disconnect(pair[0],pair[1])
    player=ui.level.player
    if is_instance_valid(player):
        energy_before=int(player.energy)
        player.combat_observed.connect(_contact);player.energy_changed.connect(_energy);player.heal_state_changed.connect(_heal);player.skill_cast.connect(_cast);player.player_respawned.connect(_respawn)

func _collecting() -> bool:
    if ledger.active.is_empty() or not is_instance_valid(player) or ui.level.world_loading:return false
    var training: Node=ui.get_node_or_null("PracticeDesk")
    return training==null or training.curriculum.active.is_empty()

func _contact(data: Dictionary) -> void:
    if _collecting():ledger.contact(data)
func _energy(value: int,_maximum: int) -> void:
    if _collecting():ledger.energy(energy_before,value)
    energy_before=value
func _heal(state: String) -> void:
    if _collecting():ledger.heal(state)
func _cast(id: String) -> void:
    if _collecting():
        var skill: Dictionary=ui.level.build_system.catalog.skills.get(id,{})
        ledger.cast(String(skill.get("name","当前线术")))
func _respawn() -> void:
    if not ledger.active.is_empty():ledger.finish("复生")

func _process(delta: float) -> void:
    if not is_instance_valid(ui) or not ui.construction_complete:return
    _bind_player()
    if _collecting() and String(ui.level.active_overlay).is_empty():ledger.tick(delta)
    hud.visible=not ledger.active.is_empty() and String(ui.level.active_overlay).is_empty()
    if hud.visible:hud.text="观察中 %.0fs · 针击%d · 承伤%d" % [float(ledger.active.seconds),int(ledger.active.hits),int(ledger.active.incoming)]
    elapsed+=delta
    if elapsed>=0.5:
        elapsed=0.0
        if is_instance_valid(window) and window.visible:refresh()

func _exit_tree() -> void:
    if not ledger.active.is_empty():ledger.finish("界面退场")
