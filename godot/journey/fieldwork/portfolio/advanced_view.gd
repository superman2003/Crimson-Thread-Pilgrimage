extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/portfolio/advanced.gd")
var payload: Dictionary = {}
var budget: SpinBox
var output: VBoxContainer


func configure(data: Dictionary) -> void:
    payload = data.get("payload",{}).duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self,"使用已勾选拟合范围和个人权重，临时改变预算比较整数解；不会保存或采用该预算。")
    var controls := UI.row(self)
    budget = UI.spin(controls,float(payload.get("budget",0)),0,1000000,0.01)
    UI.button(controls,"重新拟合",_calculate)
    output = UI.column(self)
    _calculate()


func _calculate() -> void:
    UI.clear(output)
    var candidate := payload.duplicate(true)
    candidate.budget = budget.value
    var result := A.solve(candidate)
    if not result.ok:
        UI.label(output,result.reason)
        return
    UI.label(output,"实际个人等价开销%.3f / 预算%.3f" % [result.spent,candidate.budget],true)
    UI.label(output,"目标误差%.3f；未分配%.3f；约束证书%s" % [result.loss,maxf(0,float(candidate.budget)-float(result.spent)),"通过" if A.certify(candidate,result) else "未通过"])
    UI.hint(output,"保守刻度%.3f；刻度保留上界%.3f；转移%d次。" % [result.unit,result.quantization_bound,result.transitions])
    for row in result.rows:
        var card := UI.card(output)
        UI.label(card,String(row["物资"]),true)
        UI.label(card,"整数%d · 目标%.3f · 最低%d" % [row["整数数量"],row["目标数量"],row["最低储备"]])
        var maximum := maxf(1,maxf(float(row["整数数量"]),float(row["目标数量"])))
        UI.progress(card,float(row["整数数量"]),maximum)
        UI.hint(card,"个人等价开销%.3f" % row["个人等价开销"])
    if result.rows.is_empty():
        UI.hint(output,"未勾选拟合范围；可在候选编辑页选择至多12项。")
