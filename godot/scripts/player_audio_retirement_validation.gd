extends RefCounted
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
# Exercise inherited production playback under headless CI as well: only the
# display-based muting predicate differs from the ordinary Player scene.
class AudiblePlayer:
    extends "res://scripts/player_controller.gd"
    func _should_play_sfx() -> bool:return true

func run(tree: SceneTree,check: Callable) -> void:
    var player: Node=load("res://scenes/Player.tscn").instantiate()
    player.set_script(AudiblePlayer)
    tree.root.add_child(player)
    player.set_physics_process(false)
    player.set_process(false)
    for cycle in 4:
        await tree.create_timer(1.0).timeout
        player._play_sfx("land_soft")
        player._play_footstep()
        var count := _one_shots(player)
        check.call(count>0,"actual Player creates one-shot audio before simulated region retirement")
        RETIRE.retire_tree(player)
        await tree.process_frame
        await tree.process_frame
        check.call(_one_shots(player)==0,"interrupted one-shot players are freed, not accumulated on the persistent Player")
    await tree.create_timer(1.0).timeout
    player._start_wall_slide_loop()
    check.call(is_instance_valid(player.wall_slide_audio) and player.wall_slide_audio.playing,"actual reusable wall audio starts")
    var loop_id: int=player.wall_slide_audio.get_instance_id()
    RETIRE.retire_tree(player)
    await tree.process_frame
    check.call(is_instance_valid(player.wall_slide_audio) and player.wall_slide_audio.get_instance_id()==loop_id and player.wall_slide_audio.stream==null,"retirement keeps the reusable wall player and releases its stream")
    await tree.create_timer(1.0).timeout
    player._start_wall_slide_loop()
    check.call(player.wall_slide_audio.get_instance_id()==loop_id and player.wall_slide_audio.playing and player.wall_slide_audio.stream!=null,"wall loop reloads its stream and reuses its player after region retirement")
    RETIRE.retire_tree(player)
    player.queue_free()
    await tree.process_frame
    await tree.process_frame
    AUDIO._stream_cache.clear()
    check.call(await RETIRE.drain(tree),"player audio fixture releases native playback resources")
    print("PLAYER_AUDIO_RETIREMENT checks=12")

func _one_shots(player: Node) -> int:
    var count := 0
    for child in player.get_children():
        if child is AudioStreamPlayer2D and (String(child.name).begins_with("Sfx_") or String(child.name).begins_with("SfxStep")):count+=1
    return count
