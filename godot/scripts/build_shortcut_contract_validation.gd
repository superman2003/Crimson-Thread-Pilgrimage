extends SceneTree
const VALIDATION:=preload("res://scripts/build_shortcut_validation.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
const MODEL:=preload("res://scripts/settings_profiles.gd")
const TRANSFER:=preload("res://scripts/settings_profile_transfer.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")

func check(condition: bool, message: String) -> void:
    checks+=1
    if not condition:
        failures+=1
        push_error(message)

func run() -> void:
    preload("res://scripts/build_shortcut_input.gd").ensure_action()
    await VALIDATION.pure(self)
    var actions:={"contract_first":"第一动作","contract_second":"第二动作","build_menu":"构筑"}
    for pair in [["contract_first",KEY_F17],["contract_second",KEY_F18]]:
        InputMap.add_action(pair[0])
        InputMap.action_add_event(pair[0],VALIDATION.key(pair[1]))
    var bindings:=CODEC.capture(actions)
    var legacy:=bindings.duplicate(true)
    legacy.erase("build_menu")
    var profile:={"values":MODEL.values({}),"bindings":legacy}
    var packet:={"format":TRANSFER.FORMAT,"version":1,"name":"兼容测试","profile":profile}
    var original:=var_to_str([bindings,profile])
    var parsed:=TRANSFER.parse_code(JSON.stringify(packet),actions)
    check(parsed.ok and parsed.profile.bindings.build_menu==bindings.build_menu,"minimal version 1 migration preserves the current build inputs")
    check(var_to_str([CODEC.capture(actions),profile])==original,"migration changes neither live inputs nor the original stored profile")
    var exported:=TRANSFER.export_code("兼容测试",profile,actions)
    check(exported.ok and JSON.parse_string(exported.text).version==2,"legacy profile exports into the complete current protocol")
    packet.version=2
    check(not TRANSFER.parse_code(JSON.stringify(packet),actions).ok,"current protocol cannot omit its build action")
    for pair in [["contract_first",KEY_B],["contract_second",KEY_F9]]:
        var damaged:=profile.duplicate(true)
        damaged.bindings[pair[0]]=[CODEC.encode(VALIDATION.key(pair[1]))]
        packet={"format":TRANSFER.FORMAT,"version":1,"name":"拒绝测试","profile":damaged}
        check(not TRANSFER.parse_code(JSON.stringify(packet),actions).ok,"historical or fixed reserved input is not accepted through migration")
    print("BUILD_SHORTCUT_CONTRACT checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
