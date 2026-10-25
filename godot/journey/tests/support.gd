extends SceneTree
const VALUES := preload("res://journey/core/values.gd")
const STORE := preload("res://journey/core/store.gd")
const BUILD := preload("res://scripts/build_system.gd")
const CONTEXT := preload("res://journey/core/context.gd")
const UI := preload("res://journey/core/ui.gd")
const REGION := "demo_ch01_moss_bell_court"
var checks := 0
var failures := 0
var fake: RefCounted
var label := "CORE"

class FakeContext extends "res://journey/core/context.gd":
    func editable() -> bool:
        return true

class PhotoWorld extends Node2D:
    var initial_region_ready := true
    var active_overlay := "settings"
    var world_loading := false
    var chapter_transitioning := false
    var player: CharacterBody2D
    var ui_shell: Control
    func _ready() -> void:
        player = CharacterBody2D.new()
        add_child(player)
        var camera := Camera2D.new()
        camera.name = "Camera2D"
        player.add_child(camera)
        camera.make_current()
        ui_shell = Control.new()
        add_child(ui_shell)

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("JOURNEY_" + label + ": " + message)

func fixture(name: String) -> RefCounted:
    var context := FakeContext.new()
    context.store.directory = "user://journey_validation_" + name
    context.store.configure("user://journey_validation_" + name + ".json")
    DirAccess.make_dir_recursive_absolute(context.store.directory)
    for file in DirAccess.get_files_at(context.store.directory):
        if file.ends_with(".json") or file.contains(".pending_"):
            DirAccess.remove_absolute(context.store.directory.path_join(file))
    var build := BUILD.new()
    var config := VALUES.read_json("res://data/demo_ch01_moss_bell_court.json", 4194304)
    context.latest = {
        "slot":context.store.scope,
        "save_path":context.store.directory.path_join("primary.json"),
        "region":REGION,
        "region_name":"苔钟庭",
        "room":"entry_bell",
        "inventory":{},
        "flags":{},
        "regions":{},
        "wallet":100,
        "config":config,
        "catalog":build.catalog.duplicate(true),
        "build_state":build.state.duplicate(true),
        "build":build.get_snapshot(),
        "player":{"hp":5, "energy":100, "position":[200, 300], "velocity":[0, 0], "grounded":true, "alive":true},
        "exploring":true,
        "at_shrine":false,
        "timestamp":int(Time.get_unix_time_from_system())
    }
    fake = context
    return context

func node_container() -> VBoxContainer:
    var box := VBoxContainer.new()
    box.size = Vector2(900, 620)
    root.add_child(box)
    return box

func finish() -> void:
    if fake != null:
        for file in DirAccess.get_files_at(fake.store.directory):
            if file.ends_with(".json") or file.contains(".pending_"):
                DirAccess.remove_absolute(String(fake.store.directory).path_join(file))
    print("JOURNEY_%s checks=%d failures=%d" % [label, checks, failures])
    quit(1 if failures else 0)

func run() -> void:
    finish()
