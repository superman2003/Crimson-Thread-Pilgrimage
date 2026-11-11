extends SceneTree
const BRAIN = preload("res://scripts/boss_behavior_brain.gd")
const ART = preload("res://scripts/hand_drawn_assets.gd")
const RETIRE = preload("res://scripts/audio_retirement.gd")
const ACTION = preload("res://scripts/boss_behavior_action.gd")
const AUDIO = preload("res://scripts/enemy_combat_audio.gd")
const DIRECTOR = preload("res://scripts/audio_director.gd")
const SKILL = preload("res://scripts/boss_skill_art.gd")
var checks := 0
var failures := 0

class NativeSoundBoss extends "res://scripts/enemy_actor.gd":
    # Exercise the same voice/cache ownership with the runner's Dummy audio
    # driver, including when this suite runs without a display server.
    func _should_play_sfx() -> bool:return true

class Terrain extends Node:
    func floor_height(_x: float, _y: float, _depth: float) -> float:return 340.0
class Stage extends Node2D:
    var chapter_terrain: Node
class Target extends CharacterBody2D:
    var ui_input_locked := false
    var attack_timer := 0.0
    var heal_timer := 0.0
    var dash_timer := 0.0
    var current_attack := "attack_1"
    var current_attack_direction := Vector2.LEFT
    var facing := -1
    func take_damage(_amount: int, _from: Vector2, _blockable: bool = true) -> bool:return true

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("BOSS_BEHAVIOR: " + label)

func run() -> void:
    var stage := Stage.new()
    stage.chapter_terrain = Terrain.new()
    stage.add_child(stage.chapter_terrain)
    root.add_child(stage)
    var target := Target.new()
    target.position = Vector2(620,300)
    target.add_to_group("player")
    stage.add_child(target)
    var signatures := {}
    var report: Array = []
    var debugger: Node = root.get_node("BeehaveGlobalDebugger")
    for kind: String in BRAIN.catalog.bosses:
        target.position=Vector2(620,300)
        target.velocity=Vector2.ZERO
        target.heal_timer=0.0
        target.attack_timer=0.0
        var actor := NativeSoundBoss.new()
        actor.configure({"id":"behavior_"+kind,"kind":kind,"hp":9999},"",true)
        actor.position = Vector2(500,300)
        stage.add_child(actor)
        actor.set_physics_process(false)
        actor.arena_min_x = 100
        actor.arena_max_x = 1100
        var brain: Node = actor.boss_brain
        check(brain != null and brain.tree is BeehaveTree,kind+" uses real Beehave")
        check(not brain.tree.is_physics_processing() and not brain.tree.is_processing(),kind+" has only the actor's gated clock")
        check(debugger._registered_trees.has(brain.tree.get_instance_id()),kind+" debugger registers")
        var branch_names: Array = []
        for branch: Dictionary in brain.kit.branches:branch_names.append(branch.id)
        signatures[JSON.stringify(branch_names)] = true

        # Actual production asset bindings, not just file existence counts.
        var manifest := ART.manifest(actor.asset_path)
        var expanded := String(manifest.get("generation_record","")) == "motion_v8_generation.json"
        check(expanded or actor.asset_path.ends_with("boss_behavior_manifest.json"),kind+" production/prewarm select defensive atlas")
        for name in ["backstep","ready_guard","ready_settle"]:
            check(actor.animated_sprite.sprite_frames.has_animation(name),kind+"/"+name+" is authored")
            var expected: int = 12 if name == "backstep" else 6
            if expanded:expected*=2
            check(actor.animated_sprite.sprite_frames.get_frame_count(name)==expected,kind+"/"+name+" source poses")
        for move: Dictionary in actor.ai_commands:
            check(SKILL.matches(actor,move),kind+"/"+move.id+" has painted warning/execution data")
            var family := AUDIO.release_family(kind,actor.locomotion,move)
            check(ResourceLoader.exists(AUDIO.path(family,1)),kind+"/"+move.id+" has release sound")
            check(ResourceLoader.exists(AUDIO.path(AUDIO.preparation_family(family),1)),kind+"/"+move.id+" has preparation sound")

        # No reaction to a newly exposed action before the configured delay.
        actor.last_player_command = "heal"
        brain.observe(.01,target)
        check(brain.sensed.is_empty(),kind+" cannot instantly read healing")
        brain.observe(float(brain.kit.reaction_seconds)-.02,target)
        check(brain.sensed.is_empty(),kind+" waits full reaction delay")
        brain.observe(.03,target)
        check(brain.sensed.get("action")=="heal",kind+" delayed observation becomes available")
        actor.last_player_command = "jump"
        brain.observe(.01,target)
        check(brain.sensed.get("action")=="heal",kind+" keeps the old observation until the new one matures")

        # Repeats and starvation with every move eligible; phase/range/cooldown
        # restrictions must still win over starvation protection.
        actor.battle_phase = 2
        var ids: Array = []
        for move: Dictionary in actor.ai_commands:ids.append(move.id)
        var tally := {}
        for i in 40:
            actor.cooldowns.clear()
            var move: Dictionary = brain.select_command(ids)
            check(not move.is_empty(),kind+" selection remains live")
            if move.is_empty():break
            brain.record_attack(move)
            tally[move.id] = int(tally.get(move.id,0))+1
            if brain.history.size()>=3:
                check(not (brain.history[-1]==brain.history[-2] and brain.history[-2]==brain.history[-3]),kind+" caps consecutive repeats with alternatives")
        check(tally.size()==4,kind+" gives all eligible moves an opportunity")
        actor.battle_phase=1
        for move: Dictionary in actor.ai_commands:
            actor.cooldowns[move.id]=10.0
            brain.neglected[move.id]=100
        check(brain.select_command(ids).is_empty(),kind+" memory never bypasses cooldowns")
        actor.cooldowns.clear()
        for move: Dictionary in brain.eligible_commands():check(int(move.get("phase",1))==1,kind+" memory respects phase locks")
        target.position.x=1500
        brain.sensed={"position":target.position,"action":"heal"}
        check(brain.select_command(ids).is_empty(),kind+" memory respects range")

        # Backstep faces the target and arena bounds remain authoritative.
        target.position=Vector2(620,300)
        brain.sensed={"position":target.position,"action":"idle"}
        actor.position=Vector2(500,300)
        brain.target=target
        brain.perform_stance("backstep",.1)
        check(actor.position.x<500 and actor.direction==1,kind+" backsteps while facing the player")
        actor.position.x=100
        brain.perform_stance("backstep",.1)
        check(actor.position.x>=100,kind+" cannot backstep through arena wall")

        # The leaf owns all recovery. A hit cannot replace an ongoing Boss pose.
        actor.reset_for_respawn()
        actor.position=Vector2(500,300)
        brain.target=target
        brain.sensed={"position":target.position,"action":"idle"}
        var leaf := ACTION.new()
        leaf.specification={"moves":ids}
        leaf.before_run(actor,brain.tree.blackboard)
        check(leaf.tick(actor,brain.tree.blackboard)==BeehaveNode.RUNNING,kind+" attack leaf starts executor")
        var serial: int=actor.attack_execution_serial
        var pose: String=actor.animated_sprite.animation
        actor.take_hit(1,-1)
        check(String(actor.animated_sprite.animation)==pose,kind+" nonlethal hit keeps committed attack pose")
        actor._update_windup(float(actor.active_attack.windup)+.001)
        actor._update_active(float(actor.active_attack.active)+.001)
        check(actor.state=="recover",kind+" enters real authored recovery")
        check(leaf.tick(actor,brain.tree.blackboard)==BeehaveNode.RUNNING,kind+" no follow-up during recovery")
        actor._update_recover(float(actor.state_timer)-.01)
        check(actor.attack_completed_serial!=serial,kind+" recovery cannot complete early")
        # Disable autonomous branch selection for this exact manual deadline.
        var commands: Array=actor.ai_commands
        actor.ai_commands=[]
        actor._update_recover(.02)
        check(actor.attack_completed_serial==serial,kind+" completion serial follows full recovery")
        check(leaf.tick(actor,brain.tree.blackboard)==BeehaveNode.SUCCESS,kind+" leaf completes only after executor")
        actor.ai_commands=commands
        leaf.before_run(actor,brain.tree.blackboard)
        check(leaf.tick(actor,brain.tree.blackboard)==BeehaveNode.RUNNING,kind+" can begin another action")
        actor.reset_for_respawn()
        check(leaf.tick(actor,brain.tree.blackboard)==BeehaveNode.FAILURE,kind+" stale action cannot continue after respawn")
        leaf.free()

        # Live actor -> tree -> executor, with changing player decisions.
        actor.reset_for_respawn()
        actor.position=Vector2(500,300)
        var used := {}
        var branches := {}
        var starts := 0
        var previous_serial: int=actor.attack_execution_serial
        for frame in 4200:
            var mode := (frame/360)%4
            target.position=Vector2(clampf(actor.position.x+([120,310,420,160][mode]),110,1080),300)
            target.velocity=Vector2(0,-160 if mode==1 else 0)
            target.heal_timer=.8 if mode==2 else 0.0
            target.attack_timer=.2 if mode==3 else 0.0
            if frame==2100:actor.hp=4000
            actor._physics_process(1.0/60)
            if not brain.last_branch.is_empty():branches[brain.last_branch]=true
            if actor.attack_execution_serial!=previous_serial:
                starts+=1
                used[actor.last_attack_id]=true
                previous_serial=actor.attack_execution_serial
                check(float(actor.active_attack.get("windup",0))>=.55,kind+" autonomous attack retains full warning")
            if frame%120==0:await process_frame
        check(starts>=12,kind+" live AI stays active through both phases")
        check(used.size()==4,kind+" live AI reaches all four skills")
        check(branches.size()>=3,kind+" live AI changes tactical branches")
        var clock_before: float=brain.clock
        var serial_before: int=actor.attack_execution_serial
        target.ui_input_locked=true
        actor._physics_process(.5)
        check(brain.clock==clock_before and actor.attack_execution_serial==serial_before,kind+" UI pause freezes the entire decision clock")
        target.ui_input_locked=false
        actor.set_meta("world_residency_active",false)
        actor._physics_process(.5)
        check(brain.clock==clock_before,kind+" unloaded residency freezes sensing")
        actor.remove_meta("world_residency_active")
        actor.reset_for_respawn()
        check(brain.history.is_empty() and brain.sensed.is_empty() and brain.tree.status==-1,kind+" respawn clears plan/memory/tree status")
        report.append({"kind":kind,"attacks":starts,"skills":used.size(),"branches":branches.keys()})
        var tree_id: int=brain.tree.get_instance_id()
        RETIRE.retire_tree(actor)
        actor.queue_free()
        await process_frame
        await process_frame
        check(not debugger._registered_trees.has(tree_id),kind+" removal unregisters debugger references")
    check(signatures.size()==6,"each Boss owns a distinct tactical graph")
    RETIRE.retire_tree(stage)
    stage.queue_free()
    await process_frame
    await process_frame
    check(RETIRE.observed>0,"Boss actions exercise actual native playback")
    check(not DIRECTOR._stream_cache.is_empty(),"Boss actions exercise decoded stream caching")
    # Session caches deliberately outlive actors. Release this fixture's final
    # strong stream owner before checking AudioServer playback retirement.
    DIRECTOR._stream_cache.clear()
    check(await RETIRE.drain(self),"all test audio retires")
    print("BOSS_BEHAVIOR_REPORT "+JSON.stringify(report))
    print("BOSS_BEHAVIOR checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
