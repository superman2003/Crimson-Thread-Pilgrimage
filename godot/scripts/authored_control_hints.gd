extends RefCounted
## Render authored instructions before inserting live labels. Never run this on
## an already formatted HUD/dialogue string: a remapped F may mean another action.
const PROMPTS:=preload("res://scripts/input_prompt_bindings.gd")
const LEGACY:={"K":"hook","Q":"bell_guard","R":"crown_resonance","F":"interact","M":"map","J":"attack","H":"heal","L":"skill_1"}
const ACTIONS:=["hook","bell_guard","crown_resonance","lantern_phase","interact","map","attack","heal","skill_1","aim_down"]
static var patterns: Dictionary={}

static func template(text: String) -> String:
    if patterns.is_empty():
        for key in LEGACY:
            var expression:=RegEx.new()
            expression.compile("按 "+key+"(?![A-Za-z0-9_])")
            patterns[key]=expression
        var hold:=RegEx.new();hold.compile("长按 E(?![A-Za-z0-9_])")
        patterns["hold"]=hold
    var result: String=patterns.hold.sub(text,"按住 {key:lantern_phase}",true)
    for key in LEGACY:result=patterns[key].sub(result,"按 {key:"+String(LEGACY[key])+"}",true)
    return result

static func render(text: String) -> String:
    var result:=template(text)
    for action in ACTIONS:result=result.replace("{key:"+action+"}",PROMPTS.action_label(action))
    return result

static func gate_instruction(action: String) -> String:
    var text: String={
        "echo_hook":"面向钩环按 {key:hook}，牵引检修闩。",
        "bell_guard":"在门前按 {key:bell_guard}，拨开封蜡闩。",
        "lantern_phase":"在门前按住 {key:lantern_phase} 进入相位，留足绯线。",
        "crown_resonance":"在门前按 {key:crown_resonance}，以共鸣回应钟门。",
        "thorn_downstrike":"空中按住 {key:aim_down} 并按 {key:attack}，向下破开脆弱地形。"}.get(action,"")
    return render(text)
