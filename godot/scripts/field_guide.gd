extends RefCounted
## Read-only teaching notes. Numbers come from the current Player heal quote.
static func records(heal: Dictionary, bindings: Dictionary, recall_available: bool=false, inventory: Dictionary={}) -> Array[Dictionary]:
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
    var equipment:=preload("res://scripts/equipment_field_notes.gd").records(inventory,bindings)
    for note in equipment:
        var page:=0 if String(note.id).begins_with("equipment_guide_skills_") else 1
        result[page].description+="\n\n"+String(note.title)+"\n"+String(note.description)
    result.append_array(ability_records(inventory,bindings))
    return result

## An earned manual uses the same inventory gate as the protagonist's voice.
## Keep unknown ability names and control combinations out of public records.
static func ability_records(inventory: Dictionary, bindings: Dictionary) -> Array[Dictionary]:
    var keys: Dictionary={}
    for action in ["jump","dash","move_left","move_right","aim_up","aim_down","attack","hook","bell_guard","lantern_phase","crown_resonance"]:
        keys[action]=String(bindings.get(action,"未设置"))
    var notes:={
        "thread_dash":["绯线突进", "按 {dash} 向面朝方向突进；先用 {move_left} / {move_right} 调整朝向。\n\n先看落脚处，再出手。突进有收势间隔，受伤会中断位移。"],
        "silk_wall_grip":["贴墙与蹬墙", "下落时按住朝向墙面的移动键（{move_left} / {move_right}）贴墙缓降，再按 {jump} 蹬离墙面。\n\n需要接触真实墙面；装饰、背景和空中的边缘不能攀附。"],
        "double_thread_jump":["空中第二跳", "离地后再次按 {jump}，可使用一次额外跳跃；落地后恢复。\n\n先松开再按跳跃键，持续按住不会连续消耗第二跳。"],
        "echo_hook":["回声钩索", "面向可见钩环按 {hook}。用 {aim_up} / {aim_down} 调整瞄准方向；拉向钩环时按 {jump} 可松开。\n\n只会抓取范围内、未被地形挡住的钩环。没有合适钩环时，按键仍执行原有的掷钩攻击。"],
        "bell_guard":["钟壳格挡", "面向来袭方向按 {bell_guard}，短暂展开钟壳。\n\n格挡消耗绯线，不能一直保持。及时接住可格挡的攻击有少量返还；身后攻击和不可格挡危险仍需躲避。"],
        "thorn_downstrike":["荆棘下劈", "在空中按住 {aim_down} 并按 {attack}，向脚下出针。\n\n可作用于相应的脆弱地形；普通针击也能借可反弹尖刺起跳。留意下方落点，装饰裂纹不一定是通路。"],
        "lantern_phase":["灯影相位", "按住 {lantern_phase} 进入相位，松开结束。启动与维持都消耗绯线。\n\n相位只允许通过对应灯影门，并不能穿过普通岩壁。入门前留足绯线并确认出口；受击或绯线耗尽会结束相位。"],
        "crown_resonance":["王冠共鸣", "按 {crown_resonance} 消耗绯线，向周围释放共鸣。\n\n可回应对应的共鸣设施，也能用于战斗；需要等待收势后再次使用。共鸣不会代替其它能力开启所有门。"]}
    var result: Array[Dictionary]=[]
    for ability in notes:
        var value: Variant=inventory.get(ability,0)
        if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<=0.0 or float(value)>1000000.0 or float(value)!=floor(float(value)):continue
        var entry: Dictionary={"id":"field_ability_"+ability,"title":String(notes[ability][0]),"description":String(notes[ability][1]).format(keys),"record_kind":"guide","acquired":true}
        result.append(preload("res://scripts/permanent_ability_roles.gd").annotate(entry,ability,inventory))
    return result
