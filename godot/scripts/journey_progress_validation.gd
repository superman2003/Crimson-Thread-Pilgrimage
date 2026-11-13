extends SceneTree
const MODEL:=preload("res://scripts/journey_progress.gd")
const ABILITIES:=preload("res://scripts/permanent_ability_roles.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func journey(share: float) -> Dictionary:
    var totals:=MODEL.totals()
    var data:={"inventory_counts":{},"regions":{}}
    for index in int(round(ABILITIES.IDS.size()*share)):data.inventory_counts[ABILITIES.IDS[index]]=1
    var order:=totals.keys();order.sort()
    for index in order.size():
        var known: Dictionary=totals[order[index]]
        var region:={"visited_rooms":{},"collected_ids":{},"boss_defeated":index<int(round(order.size()*share))}
        for position in int(round(known.rooms.size()*share)):region.visited_rooms[known.rooms[position]]=true
        for position in int(round(known.pickups.size()*share)):region.collected_ids[known.pickups[position]]=true
        data.regions[order[index]]=region
    return data
func run() -> void:
    var totals:=MODEL.totals()
    check(totals.size()==6,"six regions have totals")
    var rooms:=0;var pickups:=0
    for known in totals.values():rooms+=known.rooms.size();pickups+=known.pickups.size()
    check(rooms>=150 and pickups>=100,"totals list the authored rooms and pickups")
    check(MODEL.completion({})==0 and MODEL.completion(journey(0.0))==0,"an empty journey is 0%")
    check(MODEL.completion(journey(1.0))==100,"everything found is 100%")
    var half:=MODEL.completion(journey(0.5))
    check(half>=45 and half<=55,"half of each share is about half: %d" % half)
    var almost:=journey(1.0)
    var first: String=totals.keys()[0]
    almost.regions[first].collected_ids.erase(totals[first].pickups[0])
    check(MODEL.completion(almost)==99,"one missing pickup never rounds up to 100%")
    # Ids the game no longer authors, wrong types and extra regions cannot inflate the share.
    var padded:=journey(0.0)
    padded.regions[first].visited_rooms={"not_a_room":true,totals[first].rooms[0]:"yes"}
    padded.regions[first].collected_ids={"not_a_pickup":true}
    padded.regions["retired_region"]={"boss_defeated":true,"visited_rooms":{"x":true},"collected_ids":{"y":true}}
    check(MODEL.completion(padded)==0,"unknown ids, wrong types and unknown regions count for nothing")
    check(MODEL.clock_text(0)=="0:00" and MODEL.clock_text(59)=="0:00" and MODEL.clock_text(3725)=="1:02" and MODEL.clock_text(360000)=="100:00","hours and minutes")
    # Play time: beside the save, resumed, restarted, never past one second per frame.
    var path:="user://progress_fixture.json"
    var clock:=MODEL.new();clock.attach(path,false)
    check(clock.seconds==0.0 and MODEL.recorded(path)==0,"a new journey starts at zero")
    for index in 90:clock.tick(1.0/60.0)
    clock.tick(30.0);clock.tick(-5.0);clock.tick(NAN)
    check(int(clock.seconds)==2,"a stalled frame adds at most one second; bad deltas add nothing")
    clock.flush()
    check(MODEL.recorded(path)==2,"saved with the journey")
    var writes:=FileAccess.get_modified_time(clock.store.path);var bytes:=FileAccess.get_file_as_bytes(clock.store.path)
    clock.tick(0.2);clock.flush()
    check(FileAccess.get_file_as_bytes(clock.store.path)==bytes and FileAccess.get_modified_time(clock.store.path)==writes,"an unchanged second is not rewritten")
    var resumed:=MODEL.new();resumed.attach(path,true)
    check(int(resumed.seconds)==2,"continuing resumes the recorded time")
    var other:=MODEL.new();other.attach("user://other_slot.json",true)
    check(other.seconds==0.0,"another slot has its own time")
    var restarted:=MODEL.new();restarted.attach(path,false);restarted.tick(1.0);restarted.flush()
    check(MODEL.recorded(path)==1,"a new journey in the same slot replaces the old time")
    var file:=FileAccess.open(clock.store.path,FileAccess.WRITE);file.store_string('{"version":1,"payload":{"seconds":-4}}');file.close()
    check(MODEL.recorded(path)==0,"an invalid record reads as zero")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(clock.store.path))
    print("JOURNEY_PROGRESS checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
