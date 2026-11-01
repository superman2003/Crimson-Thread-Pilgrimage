extends RefCounted
## These installation preferences are independent of named/shared input profiles.
const DEFAULTS:={"observation_mode":0,"observation_delay":0.35,"observation_distance":1.0}
const MODES:=["跟随前瞻强度（原行为）","独立主动观察","关闭主动观察"]
static func normalize(values: Dictionary) -> Dictionary:
    var result:=DEFAULTS.duplicate()
    var raw: Variant=values.get("observation_mode",0)
    if (raw is int or raw is float) and is_finite(float(raw)) and float(raw)==floorf(float(raw)) and int(raw) in [0,1,2]:result.observation_mode=int(raw)
    for key in ["observation_delay","observation_distance"]:
        var value: Variant=values.get(key,DEFAULTS[key])
        if (value is float or value is int) and is_finite(float(value)):
            result[key]=clampf(float(value),0.15 if key=="observation_delay" else 0.25,1.0)
    return result
static func strength(values: Dictionary, automatic: float) -> float:
    var normalized:=normalize(values)
    if normalized.observation_mode==2:return 0.0
    var factor:=clampf(automatic,0.0,1.0) if is_finite(automatic) else 0.0
    return float(normalized.observation_distance)*(1.0 if normalized.observation_mode==1 else factor)
static func describe(values: Dictionary, automatic: float) -> String:
    var clean:=normalize(values)
    return "%s\n持续静止按住方向 %.2f 秒后，主动观察最多 %.0f 像素。\n自动前瞻强度 %.0f%%；Boss 禁止方向、落地与菜单限制仍有效。" % [MODES[clean.observation_mode],clean.observation_delay,150.0*strength(clean,automatic),automatic*100.0]
