extends RefCounted
## Compare two stored snapshots. No InputMap capture/restore, application or writes.
const PROFILES:=preload("res://scripts/settings_profiles.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
const COMFORT:=preload("res://scripts/controller_preferences.gd")
const PROMPT:=preload("res://scripts/input_prompt_bindings.gd")
const EXTRA_LABELS:={"npc_landmarks":"NPC声音地标","tutorial_hints":"探索提示","navigation_assist":"导航辅助"}

static func shown(value: Variant, present: bool) -> String:
    if not present:return "未记录（旧方案）"
    if value is bool:return "开启" if value else "关闭"
    return str(value)

static func events(raw: Array, device: int) -> Dictionary:
    var encoded: Array=[]
    var labels: Array[String]=[]
    for value in raw:
        var event:=CODEC.decode(value)
        if event==null:return {"ok":false}
        var joy: bool=event is InputEventJoypadButton or event is InputEventJoypadMotion
        if device==2 and joy or device==3 and not joy:continue
        encoded.append(CODEC.encode(event))
        var label:=PROMPT.binding_label(event)
        if label.is_empty():return {"ok":false}
        labels.append(label)
    return {"ok":true,"encoded":encoded,"text":" / ".join(labels) if not labels.is_empty() else "此设备未记录输入"}

static func row(group: String, id: String, label: String, before: String, after: String, changed: bool) -> Dictionary:
    return {"group":group,"id":id,"label":label,"before":before,"after":after,"changed":changed,"search":(label+" "+before+" "+after).to_lower()}

static func compare(left: Variant, right: Variant, actions: Dictionary, device: int=0) -> Dictionary:
    if device not in [0,1,2,3]:return {"ok":false,"reason":"比较范围无效。"}
    for profile in [left,right]:
        var problem:=PROFILES.profile_error(profile)
        if not problem.is_empty():return {"ok":false,"reason":problem+"；保存记录保留，未比较。"}
        for action in profile.bindings:
            if not actions.has(action):return {"ok":false,"reason":"方案含当前未知动作；未比较或改写。"}
    var result: Array=[]
    if device in [0,1]:
        for key in PROFILES.VISUAL+PROFILES.CONTROLLER+PROFILES.EXTRA:
            var a: bool=left.values.has(key)
            var b: bool=right.values.has(key)
            var before: Variant=left.values.get(key)
            var after: Variant=right.values.get(key)
            var label:=String(COMFORT.LABELS.get(key,EXTRA_LABELS.get(key,"设置")))
            result.append(row("设置",key,label,shown(before,a),shown(after,b),a!=b or a and before!=after))
    if device in [0,2,3]:
        for action in actions:
            var a: bool=left.bindings.has(action)
            var b: bool=right.bindings.has(action)
            var before:=events(left.bindings.get(action,[]),device)
            var after:=events(right.bindings.get(action,[]),device)
            if not before.ok or not after.ok:return {"ok":false,"reason":"方案输入标签不可读取，未比较。"}
            # Omission is never filled with this machine's current binding.
            var different: bool=a!=b or a and before.encoded!=after.encoded
            result.append(row("按键",String(action),String(actions[action]),String(before.text) if a else shown(null,false),String(after.text) if b else shown(null,false),different))
    var changed:=0
    for entry in result:
        if entry.changed:changed+=1
    return {"ok":true,"rows":result,"changed":changed,"same":result.size()-changed}

static func select(report: Dictionary, query: String="", changed_only: bool=true) -> Array:
    var result: Array=[]
    if not report.get("ok",false):return result
    var tokens:=query.left(80).to_lower().replace("　"," ").replace("\t"," ").split(" ",false)
    for entry in report.rows:
        if changed_only and not entry.changed:continue
        var matches:=true
        for token in tokens:
            if not String(entry.search).contains(token):matches=false;break
        if matches:result.append(entry.duplicate(true))
    return result

static func describe(report: Dictionary, query: String="", changed_only: bool=true) -> String:
    if not report.get("ok",false):return String(report.get("reason","暂不可比较。"))
    var rows:=select(report,query,changed_only)
    var lines: Array[String]=["此范围不同%d项，相同%d项；当前筛选显示%d项。" % [report.changed,report.same,rows.size()]]
    for entry in rows:lines.append("\n%s · %s%s\n左：%s\n右：%s" % [entry.group,entry.label," · 不同" if entry.changed else " · 相同",entry.before,entry.after])
    if rows.is_empty():lines.append("没有符合筛选的项目。可清除搜索或显示相同项。")
    lines.append("\n只比较两套保存值，不读取或应用当前输入。未记录不是默认值；应用仍须返回原来的预览确认。")
    return "\n".join(lines)
