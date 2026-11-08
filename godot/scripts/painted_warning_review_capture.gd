extends SceneTree
## Native pixel review of painted hazards, without geometric range rims.
const ENEMY:=preload("res://scripts/enemy_actor.gd")
const CURRENT:=preload("res://scripts/enemy_attack_effect.gd")
const ART:=preload("res://scripts/hand_drawn_assets.gd")
var output:=""

class Stage extends Node2D:
    var chapter_terrain: Node=null

func _initialize() -> void:call_deferred("run")
func label(parent: Node,text: String,position: Vector2,size: int=16) -> void:
    var node:=Label.new();node.text=text;node.position=position
    node.add_theme_font_override("font",load("res://assets/fonts/GlobalTypeface.otf"))
    node.add_theme_font_size_override("font_size",size);parent.add_child(node)

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--output="):output=String(argument).trim_prefix("--output=")
    if output.is_empty() or DisplayServer.get_name()=="headless":quit(1);return
    root.size=Vector2i(1280,720);RenderingServer.set_default_clear_color(Color(.055,.085,.09))
    var old: Script=load("res://scripts/combat_warning_legacy_fixture.gd")
    var stage:=Stage.new();root.add_child(stage)
    label(stage,"原预警 · 美术外叠线圈",Vector2(30,18),24)
    label(stage,"新版 · 美术材质直接预警",Vector2(670,18),24)
    var examples:=[
        ["sunken_hammer_smith","boss_shears_knots","pool",false],
        ["sunken_hammer_smith","boss_shears_thread","beam",false],
        ["broken_string_gardener","boss_bishop_cage","pool",false],
        ["silent_pilgrim_commander","boss_bride_pools","pool",false],
        ["silent_crown_core","boss_key_gate","beam",false],
        ["broken_string_gardener","boss_bishop_cage","pool",true]
    ]
    var profiles: Dictionary=ART.manifest("res://data/original_creature_combat.json")
    for row in examples.size():
        var example: Array=examples[row]
        var actor:=ENEMY.new();actor.configure({"kind":example[0],"id":"warning_review","hp":999},"",true,profiles[example[0]])
        stage.add_child(actor);actor.set_physics_process(false);actor.visible=false
        var command: Dictionary={}
        for entry in actor.ai_commands:
            if String(entry.id)==String(example[1]):command=entry
        var y:=125.0+row*96.0
        for side in 2:
            label(stage,String(example[1])+(" · 有效段" if bool(example[3]) else " · 前摇"),Vector2(30+side*640,y-49),14)
            var effect: Node2D=old.new() if side==0 else CURRENT.new()
            effect.effect_kind=String(example[2]);effect.owner_actor=actor;effect.boss_command_id=String(example[1])
            effect.skin=String(command.get("skin","thorn"));effect.radius=31;effect.length=260
            effect.heading=Vector2.RIGHT;effect.arm_delay=1.0;effect.duration=2.0;effect.age=1.22 if bool(example[3]) else .65
            effect.position=Vector2(305+side*640-(130 if effect.effect_kind=="beam" else 0),y)
            stage.add_child(effect);effect.set_physics_process(false)
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output)
    stage.queue_free();await process_frame;await process_frame
    ART.frame_cache.clear();ART.textures.clear()
    print("PAINTED_WARNING_REVIEW_PASS samples=6")
    quit()
