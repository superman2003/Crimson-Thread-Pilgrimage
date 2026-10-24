extends RefCounted
## Read-only teaching notes. Numbers come from the current Player heal quote.
static func records(heal: Dictionary, bindings: Dictionary, recall_available: bool=false) -> Array[Dictionary]:
    var recovery:="费用、恢复量和打断损失会随契印与装备改变，请看战斗 HUD 的当前提示。"
    var valid:=true
    for field in ["cost","amount","duration"]:
        var value: Variant=heal.get(field)
        if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0.0:valid=false
    if valid:
        recovery="当前疗伤：消耗 %d 绯线，恢复 %d 生命，引导 %.2f 秒。" % [int(heal.cost),int(heal.amount),float(heal.duration)]
        if heal.has("interrupt_loss"):recovery+="打断损失 %d 绯线。" % int(heal.interrupt_loss)
    var lost:="倒下后，一半碎钱留在归途结；亲自回到结处可找回。再次倒下会替换旧结。首领战的结留在场外检查点，重试前可以取回。"
    if recall_available:lost+="\n已解锁钟龛召回：安坐后可选择召回，只收回六成；亲自去取仍可全数找回。"
    var descriptions: Array[String]=[
        "%s 跳跃，%s 普攻，%s 疗伤，%s 线术。\n\n普通针击命中可回充绯线；疗伤与线术共用资源。移动、起跳、冲刺或受击会打断疗伤；可否空中疗伤依当前契印规则。\n\n%s" % [bindings.get("jump","未设置"),bindings.get("attack","未设置"),bindings.get("heal","未设置"),bindings.get("skill_1","未设置"),recovery],
        "%s 与钟龛互动。休息恢复生命与绯线，但不会免费补满战具。\n\n战具按携带次数使用；先查看补给报价，再确认花碎钱和材料。材料不足时可部分补给。练习房内免费使用的次数带不走。\n\n钟龛可以调整装备、保存与恢复构筑；途中只能切换已经配置的快捷项，恢复方案不会补充资源。" % bindings.get("interact","未设置"),
        "%s 打开地图。地图由各区制图师报价出售，价格随到达顺序变化；绘针和罗盘另行取得。\n\n带绘针安坐钟龛，把途中笔记补到已购地图；长井与大厅按走过的段落记录。罗盘需装备在行旅槽才显示角色位置；设置中的导航辅助可覆盖这条规则。\n\n未知秘密不会提前画出；图上邻室不等于门已开放。已知图钉可从列表查看，跨区查看只移动地图视野。" % bindings.get("map","未设置"),lost]
    var titles: Array[String]=["针击、绯线与疗伤","钟龛、构筑与战具补给","购图、补绘与回访","失落、重试与找回"]
    var result: Array[Dictionary]=[]
    for index in titles.size():result.append({"id":"field_guide_"+str(index),"title":titles[index],"description":descriptions[index],"record_kind":"guide","acquired":true})
    return result
