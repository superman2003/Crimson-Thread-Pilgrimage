extends RefCounted
## Cosmetic clocks only: never controls attacks, tells, hit flashes or audio.
static var enabled := true
const FRAME_SECONDS := 1.0/30.0
const MARGIN := 260.0
var elapsed := 0.0
var redraw_clock := 0.0
var host_id := 0
var properties: Dictionary={}
var player_id:=0
var player_has_hp:=false

func active(actor: Node2D) -> bool:
    if not enabled or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree() or not actor.is_visible_in_tree() or not actor.can_process():return false
    var host:=actor.get_parent()
    if not is_instance_valid(host) or host.is_queued_for_deletion():return false
    if host_id!=host.get_instance_id():
        host_id=host.get_instance_id();properties.clear()
        for info in host.get_property_list():properties[String(info.name)]=true
    for name in ["world_loading","chapter_transitioning"]:
        if properties.has(name) and host.get(name)==true:return false
    if properties.has("active_overlay"):
        var overlay: Variant=host.get("active_overlay")
        if overlay is String and not overlay.is_empty():return false
    if properties.has("player"):
        var player: Variant=host.get("player")
        if is_instance_valid(player):
            if player_id!=player.get_instance_id():
                player_id=player.get_instance_id();player_has_hp=false
                for info in player.get_property_list():
                    if info.name=="hp":player_has_hp=true;break
            if player_has_hp:
                var hp: Variant=player.get("hp")
                if (hp is int or hp is float) and float(hp)<=0:return false
    var viewport:=actor.get_viewport_rect()
    var point:=actor.get_global_transform_with_canvas().origin
    if not point.is_finite() or not viewport.grow(MARGIN).has_point(point):return false
    return true

func step(actor: Node2D, delta: float) -> bool:
    if not is_finite(delta) or delta<=0.0 or not active(actor):
        redraw_clock=0.0
        return false
    # A stalled frame must not produce a large decorative jump on return.
    var advance:=minf(delta,0.1)
    elapsed+=advance
    redraw_clock+=advance
    if redraw_clock<FRAME_SECONDS:return false
    redraw_clock=fmod(redraw_clock,FRAME_SECONDS)
    return true
