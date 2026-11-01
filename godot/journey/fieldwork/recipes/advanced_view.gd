extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/recipes/advanced.gd")
var payload: Dictionary = {}
var result: Dictionary = {}
var choices: OptionButton
var output: VBoxContainer


func configure(data: Dictionary) -> void:
    payload = data.get("payload",{}).duplicate(true)
    result = data.get("result",{}).duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self,"从完整枚举中的不可扩展可行组合逐项核对需求。这里不修改已选目标、不自动制作。")
    var options := []
    for i in result.get("maximal",[]).size():
        var row: Dictionary = result.maximal[i]
        options.append({"id":str(i),"name":"组合%d · %d项目标 · 货币%d" % [i+1,row.count,row.currency]})
    choices = UI.pick(self,options)
    UI.button(self,"查看所选组合",_inspect)
    output = UI.column(self)
    _inspect()


func _inspect() -> void:
    UI.clear(output)
    var chosen := UI.chosen(choices)
    if chosen.is_empty():
        UI.label(output,"当前没有可展示的组合。")
        return
    var index := int(chosen)
    if index < 0 or index >= result.maximal.size():
        return
    var subset: Dictionary = result.maximal[index]
    var replay := A.evaluate(payload,result.recipes,int(subset.mask))
    UI.label(output,"组合%d：%d项目标" % [index+1,subset.count],true)
    UI.label(output,"合计货币%d，剩余%d；需求复核%s" % [subset.currency,int(payload.wallet)-int(subset.currency),"通过" if replay==subset else "未通过"])
    for id in subset.ids:
        for recipe in result.recipes:
            if recipe.id==id:
                UI.label(output,"• " + String(recipe.name))
    if subset.ids.is_empty():
        UI.hint(output,"暂缓全部制作是当前可行选择。")
    var ids: Array = subset.materials.keys()
    ids.sort()
    for id in ids:
        var available := int(payload.inventory.get(id,0))
        var cost := int(subset.materials[id])
        UI.label(output,"%s：需求%d / 持有%d / 计划后%d" % [payload.labels.get(id,id),cost,available,available-cost])
        UI.progress(output,cost,maxi(1,available))
    UI.hint(output,"图样等门槛已经在公开配方收录时筛选；当前游戏状态可能在记录后改变，正式制作仍以实时独立报价为准。")
