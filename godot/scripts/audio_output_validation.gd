extends SceneTree
const MODEL:=preload("res://scripts/audio_output_preferences.gd")
const DESK:=preload("res://scripts/audio_output_dialog.gd")
var checks:=0
var failures:=0
var available:=PackedStringArray(["Default","Headphones","Speakers"])
var output:="Default"
var refuse:=false
var route_calls: Array[String]=[]
class Shell extends Control:
    var settings:=Control.new()
    func _ready() -> void:add_child(settings)
    func _button(parent: Node,text: String,point: Vector2,dimensions: Vector2,callback: Callable) -> Button:
        var button:=Button.new();button.text=text;button.position=point;button.size=dimensions
        parent.add_child(button);button.pressed.connect(callback);return button
    func register_text_entry_window(_window: Window) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func fixture():
    var model:=MODEL.new()
    model.devices=func():return available
    model.current=func():return output
    model.route=func(name: String):
        route_calls.append(name)
        if not refuse:output=name
    model.initialize()
    model.store.path="user://fixture_output.json"
    model.store.writer=func(_data: Dictionary):return OK
    return model
func run() -> void:
    for value in [null,4,true,"","line\nfeed","delete"+String.chr(127),"x".repeat(513)]:
        check(not MODEL.valid_name(value),"invalid device identifiers rejected")
    for value in ["Default","USB Headphones","扬声器 · 声卡", "x".repeat(512)]:
        check(MODEL.valid_name(value),"native device display names accepted")
    var model=fixture()
    var initialized_calls:=route_calls.size();model.initialize()
    check(route_calls.size()==initialized_calls,"repeated initialize cannot reset a selected output")
    available=PackedStringArray(["Speakers","Default","Speakers","Bad\nName","Headphones"])
    check(model.choices()==["Default","Speakers","Headphones"],"stable unique list retains system default first")
    var quote:=model.quote("Headphones")
    check(quote.ok and output=="Default","preview does not switch device")
    check(not model.apply("Headphones","").ok and output=="Default","empty confirmation rejected")
    available=PackedStringArray(["Default","Speakers"])
    check(not model.apply("Headphones",quote.fingerprint).ok,"removed device invalidates pending confirmation")
    available.append("Headphones");quote=model.quote("Headphones");output="Speakers"
    check(not model.apply("Headphones",quote.fingerprint).ok and output=="Speakers","external output change invalidates confirmation")
    quote=model.quote("Headphones");refuse=true
    check(not model.apply("Headphones",quote.fingerprint).ok and model.preferred=="Default","backend rejection never saves unconfirmed selection")
    refuse=false;quote=model.quote("Headphones")
    model.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    var result:=model.apply("Headphones",quote.fingerprint)
    check(not result.ok and result.applied and output=="Headphones" and model.dirty,"disk failure reports active but unsaved output")
    check(model.notice.contains("未保存"),"save failure remains visible")
    var written: Array=[]
    model.store.writer=func(data: Dictionary):written.append(data.duplicate(true));return OK
    check(model.save().ok and not model.dirty and written[0].payload=={"device":"Headphones"},"retry persists exact device through atomic auxiliary store")
    var writes:=written.size();model.save()
    check(written.size()==writes,"clean retry performs no additional write")
    available=PackedStringArray(["Default","Speakers"])
    model.refresh()
    check(output=="Default" and model.preferred=="Headphones","hot unplug selects default and retains explicit preference")
    available.append("Headphones");model.refresh()
    check(output=="Default","reconnect never automatically steals audio route")
    quote=model.quote("Headphones");model.apply("Headphones",quote.fingerprint)
    available=PackedStringArray(["Default","Speakers"]);output="Default"
    model.refresh()
    check(model.notice.contains("断开"),"automatic system fallback still explains device loss")
    available.append("Headphones");model.refresh()
    check(output=="Default","automatic fallback does not auto-return on reconnect")
    model.devices=func():return null
    check(model.choices()==["Default"],"invalid backend list keeps default escape route")
    model.devices=func():return available
    output="Missing";refuse=true;model.refresh()
    check(model.notice.contains("未确认"),"failed fallback is not reported successful")
    refuse=false;output="Default"
    model.store.writable=false;quote=model.quote("Speakers")
    result=model.apply("Speakers",quote.fingerprint)
    check(not result.ok and result.applied and model.dirty,"quarantined storage preserves runtime selection without overwriting bytes")
    model.store.writable=true
    # Separate real AudioServer default contract, no physical device required.
    var native:=MODEL.new();native.initialize()
    check(native.choices().has("Default"),"real AudioServer has default option")
    quote=native.quote("Default");native.store.writer=func(_data: Dictionary):return OK
    check(native.apply("Default",quote.fingerprint).ok and AudioServer.output_device=="Default","real AudioServer acknowledges default route")
    # Durable startup and corruption checks use only this runner's isolated userdata.
    var durable:=preload("res://scripts/journey_desk_store.gd").new()
    durable.configure("audio_output","installation")
    check(durable.write({"device":"Speakers"}),"native auxiliary preference reaches disk")
    output="Default"
    var restored=fixture()
    check(output=="Speakers" and restored.preferred=="Speakers","startup restores an available saved route")
    refuse=true;output="Default"
    var rejected_start=fixture()
    check(output=="Default" and rejected_start.notice.contains("未确认"),"startup refusal is not reported as applied")
    refuse=false
    available=PackedStringArray(["Default","Headphones"]);output="Headphones"
    var absent=fixture()
    check(output=="Default" and absent.preferred=="Speakers" and absent.notice.contains("不在此电脑"),"unavailable saved device falls back honestly at startup")
    available.append("Speakers");absent.refresh()
    check(output=="Default","late reconnection does not reapply saved routing")
    var file:=FileAccess.open(durable.path,FileAccess.WRITE)
    file.store_string("{broken device record");file.close()
    var bytes:=FileAccess.get_file_as_bytes(durable.path)
    var damaged=fixture()
    check(not damaged.store.writable and damaged.notice.contains("损坏"),"damaged preference is quarantined with notice")
    check(FileAccess.get_file_as_bytes(durable.path)==bytes,"loading does not replace damaged preference")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(durable.path))
    check(durable.write({"device":"invalid\nname"}),"malformed semantic fixture written")
    var malformed=fixture()
    check(not malformed.store.writable and malformed.notice.contains("无效"),"typed storage still rejects control characters")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(durable.path))
    available=PackedStringArray(["Default","Headphones","Speakers"]);output="Default"
    var shell:=Shell.new();root.add_child(shell);shell.size=Vector2(1280,720)
    DESK.install(shell);DESK.install(shell)
    check(shell.get_child_count()==2,"repeated install owns exactly one desk")
    var desk=shell.get_node("AudioOutputDesk");desk.model=model
    model.store.writer=func(_data: Dictionary):return OK
    output="Default";desk.open();await process_frame
    check(desk.window.visible and desk.options.item_count==3,"native dialog lists available output devices")
    desk.options.select(desk.shown.find("Headphones"));desk.ask()
    check(desk.confirm.visible and output=="Default","native confirmation keeps route unchanged")
    desk.window.hide();desk.commit()
    check(not desk.confirm.visible and output=="Default","closing owner cancels pending route change")
    desk.open();desk.options.select(desk.shown.find("Headphones"));desk.ask()
    available=PackedStringArray(["Default","Speakers"]);desk.commit()
    check(output=="Default","native stale confirmation cannot switch missing device")
    available.append("Headphones");desk.refresh();desk.options.select(desk.shown.find("Headphones"));desk.ask();desk.commit()
    check(output=="Headphones" and not model.dirty,"native confirmed action changes and saves once")
    desk.ask();shell.settings.hide();await process_frame
    check(not desk.window.visible and not desk.confirm.visible,"settings hide closes nested dialogs")
    var before:=route_calls.size();desk.commit();desk.retry_save()
    check(route_calls.size()==before,"hidden callbacks cannot reroute output")
    shell.free();await process_frame
    print("AUDIO_OUTPUT checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
