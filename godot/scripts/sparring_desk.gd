extends Node
const POLICY := preload("res://scripts/sparring_policy.gd")
var ui: Control
var window: AcceptDialog
var list: ItemList
var detail: Label
var rows: Array=[]
var confirm: ConfirmationDialog
var pending: Dictionary={}
var arena: Node2D
var history: Array=[]
var store:=preload("res://scripts/journey_desk_store.gd").new()

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="SparringDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell;store.configure("sparring",String(ui.level.world_save_path))
    var saved:=store.read()
    if saved.get("history") is Array:
        for record in saved.history.slice(0,20):
            if record is Dictionary and record.get("title") is String and record.get("complete") is bool and typeof(record.get("seconds")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(record.seconds)) and float(record.seconds)>=0 and float(record.seconds)<=301:history.append(record)
    var button: Button=ui._button(ui.build_panel,"实战陪练场",Vector2(220,535),Vector2(175,30),open)
    button.name="SparringButton";button.add_theme_font_size_override("font_size",14)

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.title="实战陪练场";ui.build_panel.add_child(window);window.bind_overlay(ui,ui.build_panel)
    window.text(window.column,"只复演旅途中已击败的敌人。复制当前构筑与已得能力；练习资源独立，结束恢复原旅途。五分钟上限，无掉落、图鉴登记或通关奖励。",62)
    list=ItemList.new();list.custom_minimum_size=Vector2(880,220);window.column.add_child(list)
    list.item_selected.connect(func(_index: int):_selection())
    detail=window.text(window.column,"",110)
    window.button(window.column,"确认开始所选复演",ask);window.footer()
    confirm=ConfirmationDialog.new();confirm.title="准备进入陪练";window.add_child(confirm);ui.register_text_entry_window(confirm)
    confirm.confirmed.connect(start)
    window.visibility_changed.connect(func():
        if not window.visible:confirm.hide();pending={})

func open() -> void:
    if not ui.build_panel.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    rows=POLICY.available(ui.level);list.clear()
    for row in rows:list.add_item(String(row.title)+" · "+str(row.waves.size())+"轮")
    if not rows.is_empty():list.select(0)
    _selection();window.popup_centered()
    window.status.text="最近记录："+(String(history[0].title)+" · "+String(history[0].reason) if not history.is_empty() else "尚无记录")

func _selection() -> void:
    detail.text="击败本区敌人后，对应轮战才会出现；未知敌人不提前展示。"
    if not list.get_selected_items().is_empty():
        var row: Dictionary=rows[list.get_selected_items()[0]]
        detail.text=String(row.title)+"\n"+("重演原 Boss 招式。" if row.boss else "第一轮单敌，第二轮双敌。")+"\n使用当前装备的独立副本；普通攻击、技能、战具和缝补均可使用。"

func ask() -> void:
    if list.get_selected_items().is_empty():return
    var row: Dictionary=rows[list.get_selected_items()[0]]
    var quote:=POLICY.quote(ui.level,String(row.id))
    if not quote.ok:window.status.text=quote.reason;return
    pending={"id":row.id,"fingerprint":quote.fingerprint}
    confirm.dialog_text=String(row.title)+"：暂停旅途，进入独立练习。Esc 或返回按钮结束；原生命、能量、弹药及库存原样保留。"
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func start() -> void:
    if pending.is_empty() or not window.visible:return
    var quote:=POLICY.quote(ui.level,String(pending.id))
    if not quote.ok or quote.fingerprint!=pending.fingerprint:pending={};window.status.text="状态已变化，请重新选择。";return
    var plan: Dictionary=quote.bout;pending={};ui.level._close_overlays()
    arena=preload("res://scripts/sparring_arena.gd").new();get_tree().root.add_child(arena);arena.begin(ui.level,plan,_returned)

func _returned(record: Dictionary) -> void:
    history.push_front(record);history=history.slice(0,20)
    var saved: bool=store.write({"history":history})
    arena=null
    ui.level._toast("陪练结束，原旅途已恢复。"+("复盘记录未写入，仍保留本次内存记录。" if not saved else ""))
