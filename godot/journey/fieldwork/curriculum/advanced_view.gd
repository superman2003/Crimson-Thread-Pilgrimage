extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/curriculum/advanced.gd")
var payload: Dictionary = {}
var result: Dictionary = {}
var cursor := 0
var output: VBoxContainer
var slider: HSlider
var previous: Button
var next: Button


func configure(data: Dictionary) -> void:
    payload = data.get("payload",{}).duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self,"逐步阅读排程，明确区分等待、补休和动作。它不会计时执行、发出按键或触发角色动作。")
    result = A.schedule(payload)
    if not result.ok:
        UI.label(self,result.reason)
        return
    var row := UI.row(self)
    previous = UI.button(row,"上一步",func(): _move(-1))
    next = UI.button(row,"下一步",func(): _move(1))
    slider = HSlider.new()
    slider.min_value = 0
    slider.max_value = maxi(0,result.rows.size()-1)
    slider.step = 1
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.value_changed.connect(func(value: float): cursor=int(value); _show_step())
    add_child(slider)
    output = UI.column(self)
    _show_step()


func _move(delta: int) -> void:
    cursor = clampi(cursor+delta,0,maxi(0,result.rows.size()-1))
    slider.set_value_no_signal(cursor)
    _show_step()


func _show_step() -> void:
    UI.clear(output)
    previous.disabled = cursor==0
    next.disabled = cursor+1>=result.rows.size()
    if result.rows.is_empty():
        UI.hint(output,"课程没有动作或休息步骤。")
        return
    var step: Dictionary = result.rows[cursor]
    var labels := {"action":"动作","cooldown":"冷却等待","rest":"轮间休息","recovery":"补充个人休息"}
    UI.label(output,"第%d / %d步 · %s" % [cursor+1,result.rows.size(),labels.get(step.kind,step.kind)],true)
    UI.label(output,String(step["动作"]))
    UI.label(output,"第%d轮 / 第%d动作；%.3f → %.3f秒" % [step["轮次"],step["步骤"],step["开始秒"],step["结束秒"]])
    UI.label(output,"假设能量 %.3f → %.3f" % [step["能量前"],step["能量后"]])
    UI.progress(output,float(step["能量后"]),maxf(1,maxf(float(step["能量前"]),float(step["能量后"]))))
    UI.hint(output,"完整排程复核：" + ("通过" if A.certify(payload,result) else "未通过"))
