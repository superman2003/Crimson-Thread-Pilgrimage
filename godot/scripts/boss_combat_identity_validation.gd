extends SceneTree
const ENEMY:=preload("res://scripts/enemy_actor.gd")
const STYLE:=preload("res://scripts/boss_combat_style.gd")
const ART:=preload("res://scripts/hand_drawn_assets.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures:=0

class Stage extends Node2D:
    var chapter_terrain: Node=null

class Target extends CharacterBody2D:
    var hp:=100
    var ui_input_locked:=false
    func take_damage(amount: int,_source: Vector2,_blockable: bool=true) -> bool:
        hp-=amount;return true

class ProbeEnemy extends "res://scripts/enemy_actor.gd":
    var emissions: Array=[]
    var contacts: Array=[]
    var release_count:=0
    func _effect(effect_kind: String,point: Vector2,velocity_value: Vector2,command: Dictionary,warning: float,lifetime: float) -> Node2D:
        emissions.append({"kind":effect_kind,"point":point,"velocity":velocity_value,"warning":warning,"lifetime":lifetime,"command":command.duplicate(true)})
        return null
    func _try_damage_player(_command: Dictionary,_previous_position: Vector2=Vector2.INF) -> void:
        contacts.append({"progress":attack_elapsed/float(active_attack.active),"direction":attack_direction,"sprite_flipped":animated_sprite.flip_h})
    func _play_attack_sfx(phase: String) -> void:
        if phase=="active":release_count+=1

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)

func command(actor: Node,id: String) -> Dictionary:
    for value in actor.ai_commands:
        if String(value.id)==id:return value
    return {}

func run() -> void:
    var stage:=Stage.new();root.add_child(stage)
    var target:=Target.new();target.position=Vector2(600,350);target.add_to_group("player");stage.add_child(target)
    var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var actors:={};var signatures:={};var patterns:={}
    for kind in STYLE.catalog.bosses:
        var actor:=ProbeEnemy.new()
        actor.configure({"kind":kind,"id":"identity_"+kind,"hp":999},"",true,profiles[kind])
        actor.position=Vector2(350,350);stage.add_child(actor);actor.set_physics_process(false)
        actor.arena_min_x=100;actor.arena_max_x=1000
        actors[kind]=actor
        check(actor.ai_commands.size()==4,kind+" has four authored attacks")
        check(String(actor.ai_profile.combat_identity)==String(STYLE.catalog.bosses[kind].identity),kind+" receives its combat identity after species and encounter defaults")
        var signature: Array=[]
        for move in actor.ai_commands:
            var pattern:=String(move.get("boss_pattern",""))
            check(not pattern.is_empty() and not patterns.has(pattern),kind+" owns a unique move pattern")
            patterns[pattern]=true
            check(float(move.windup)>=.55 and float(move.recover)>=.6,pattern+" has a readable tell and punishable recovery")
            signature.append(pattern)
        signatures[",".join(signature)]=true
    check(signatures.size()==6 and patterns.size()==24,"six distinct kits and 24 identified attack patterns")

    var moss: Node=actors.rust_crown_guardian
    moss.attack_target=target.global_position-Vector2(0,42);moss.attack_direction=1
    moss._spawn_command_effects(command(moss,"boss_moss_spores"),false)
    check(moss.emissions.size()==5,"canopy rain emits five distinct shots")
    for emission in moss.emissions:
        check(emission.velocity.y<0 and float(emission.command.gravity)>0,"canopy spores rise then fall instead of copying a straight fan")
    moss.emissions.clear();moss._spawn_command_effects(command(moss,"boss_moss_roots"),true)
    check(moss.emissions.size()==4,"root chase has four committed marks")
    check(moss.emissions[0].point.x<moss.emissions[3].point.x and moss.emissions[0].warning<moss.emissions[3].warning,"root chase advances in space and time")

    var garden: Node=actors.broken_string_gardener
    garden.attack_target=target.global_position-Vector2(0,42);garden.attack_direction=1
    garden._spawn_command_effects(command(garden,"boss_bishop_roots"),true)
    check(garden.emissions[0].point.x<garden.emissions[2].point.x and garden.emissions[1].point.x>garden.emissions[3].point.x,"garden roots enter from the outside toward separate inner lanes")
    garden.emissions.clear();garden._spawn_command_effects(command(garden,"boss_bishop_cage"),true)
    for emission in garden.emissions:
        check(absf(emission.point.x-garden.attack_target.x)>=125,"root cage leaves the indicated central exit")

    var shears: Node=actors.sunken_hammer_smith
    shears.attack_target=target.global_position-Vector2(0,42);shears.attack_direction=1
    shears._spawn_command_effects(command(shears,"boss_shears_knots"),true)
    check(shears.emissions.size()==3,"shears lay three forward knots")
    check(shears.emissions[0].point.x>shears.global_position.x and shears.emissions[2].point.x>shears.emissions[0].point.x,"shear knots seal a forward row rather than copying player-centered pools")

    var crown: Node=actors.silent_crown_core
    crown.attack_target=target.global_position-Vector2(0,42);crown.attack_direction=1
    crown._spawn_command_effects(command(crown,"boss_key_gate"),true)
    check(crown.emissions.size()==2,"crown gate places two separate gates")
    check(crown.emissions[0].point.x<crown.attack_target.x and crown.emissions[1].point.x>crown.attack_target.x,"gate corridor has a committed safe center")
    for emission in crown.emissions:
        check(emission.velocity==Vector2.DOWN and bool(emission.command.remote_origin),"gates use vertical authored beam geometry at their own source")

    var mirror: Node=actors.silent_pilgrim_commander
    mirror.direction=1;mirror.boss_target_history.assign([Vector2(450,308),Vector2(480,308),Vector2(520,308),Vector2(550,308),Vector2(580,308)])
    var blink:=command(mirror,"boss_bride_mirror")
    mirror._begin_attack(blink)
    var planned: Vector2=mirror.boss_blink_destination
    var arrival:=mirror.get_node_or_null("BossCommittedArrival")
    check(arrival!=null and arrival.global_position.is_equal_approx(planned),"blink arrival is painted at the actual committed destination")
    target.position.x+=180
    mirror._update_windup(float(blink.windup))
    check(mirror.global_position.is_equal_approx(planned),"dodging after the tell does not drag the blink destination along with the player")
    mirror.emissions.clear();mirror._spawn_command_effects(command(mirror,"boss_bride_pools"),true)
    check(mirror.emissions.size()==3,"mirror echoes replay three captured positions")
    check(mirror.emissions[0].point.x>mirror.emissions[2].point.x and mirror.emissions[0].warning<mirror.emissions[2].warning,"echo positions and delays follow the captured history")

    var judge: Node=actors.saltwhite_contract_judge
    var flurry:=command(judge,"boss_mantis_flurry")
    judge.direction=1;judge._begin_attack(flurry);judge._update_windup(float(flurry.windup))
    for frame in 130:judge._update_active(minf(1.0/120.0,maxf(0,judge.state_timer)))
    check(judge.release_count==3,"three-beat flurry owns exactly three release events")
    var directions:={};var beat_count:={}
    for contact in judge.contacts:
        var beat:=STYLE.combo_stage(flurry,float(contact.progress))
        check(bool(beat.contact),"inter-beat pauses cannot apply contact damage")
        check(bool(contact.sprite_flipped)==(int(contact.direction)<0),"strike artwork faces the same committed side as its collision")
        beat_count[int(beat.index)]=true;directions[int(beat.index)]=int(contact.direction)
    check(beat_count.size()==3,"all three real strike windows execute")
    check(directions.get(0)==1 and directions.get(1)==-1 and directions.get(2)==1,"duel slashes alternate committed sides")
    check(judge.state=="recover" and judge.state_timer>1.1,"flurry leaves its authored full recovery after the third beat")

    var imp:=ProbeEnemy.new()
    imp.configure({"kind":"ash_banner_imp","id":"regular_combo","hp":99},"",false)
    imp.position=Vector2(350,350);stage.add_child(imp);imp.set_physics_process(false);actors["regular_combo"]=imp
    var minor_combo:=command(imp,"imp_flurry")
    imp._begin_attack(minor_combo)
    check(imp.active_attack.has("combo_beats"),"registered regular-enemy flurry receives real strike beats")
    var scheduled: int=imp.active_attack.combo_beats.size()
    imp._update_windup(float(minor_combo.windup))
    for frame in ceili(float(minor_combo.active)*120):imp._update_active(minf(1.0/120.0,maxf(0,imp.state_timer)))
    check(imp.release_count==scheduled,"regular-enemy swings, sounds and contact windows count the same beats")
    for contact in imp.contacts:
        check(bool(STYLE.combo_stage(imp.active_attack,float(contact.progress)).contact),"regular combo has no damaging inter-beat hold")
        check(int(contact.direction)==imp.combo_origin_direction,"regular flurry keeps its advertised forward facing")

    moss.contacts.clear();var sweep:=command(moss,"boss_moss_scythe")
    moss._begin_attack(sweep);moss._update_windup(float(sweep.windup))
    for frame in ceili(float(sweep.active)*120):moss._update_active(minf(1.0/120.0,maxf(0,moss.state_timer)))
    check(not moss.contacts.is_empty(),"painted scythe has a real contact window")
    for contact in moss.contacts:check(float(contact.progress)>=float(sweep.contact_window[0]) and float(contact.progress)<=float(sweep.contact_window[1]),"pre-release and return-to-guard poses cannot deal scythe contact damage")

    for actor in actors.values():actor._cancel_attack_effects()
    RETIRE.retire_tree(root);stage.queue_free();actors.clear();moss=null;garden=null;shears=null;crown=null;mirror=null;judge=null;target=null;imp=null
    ART.frame_cache.clear();ART.textures.clear()
    await process_frame;await process_frame
    check(await RETIRE.drain(self),"identity fixture retires native audio")
    print("BOSS_COMBAT_IDENTITY checks=%d failures=%d bosses=6 patterns=24" % [checks,failures])
    quit(0 if failures==0 else 1)
