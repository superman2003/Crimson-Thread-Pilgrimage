extends RefCounted
## Completion share and play time shown on the save slots. Play time lives in a
## small record beside the save: the save file itself is never touched, so a
## journey written by this version still loads in an older one byte for byte.
const ABILITIES := preload("res://scripts/permanent_ability_roles.gd")
const TOTALS_PATH := "res://data/completion_totals.json"
const BOSSES := 6
static var _totals: Dictionary = {}
var store := preload("res://scripts/journey_desk_store.gd").new()
var seconds := 0.0
var saved := -1

## Mean of four shares, each 0..1: abilities, gatekeepers, rooms, pickups.
static func completion(data: Dictionary) -> int:
    var totals:=totals()
    var owned:=0
    for id in ABILITIES.IDS:
        if ABILITIES.owns(data.get("inventory_counts",{}),String(id)):owned+=1
    var bosses:=0;var rooms:=0;var pickups:=0;var all_rooms:=0;var all_pickups:=0
    for region_id in totals:
        var known: Dictionary=totals[region_id]
        all_rooms+=known.rooms.size();all_pickups+=known.pickups.size()
        var region: Variant=data.get("regions",{}).get(region_id)
        if not region is Dictionary:continue
        if region.get("boss_defeated") is bool and region.boss_defeated:bosses+=1
        rooms+=_found(region.get("visited_rooms"),known.rooms)
        pickups+=_found(region.get("collected_ids"),known.pickups)
    if all_rooms==0 or all_pickups==0:return 0
    var share:=(float(owned)/ABILITIES.IDS.size()+float(mini(bosses,BOSSES))/BOSSES+float(rooms)/all_rooms+float(pickups)/all_pickups)/4.0
    # 100 only when everything is found; 99.6 must not round up.
    return 100 if share>=1.0 else clampi(int(floor(share*100.0)),0,99)

static func _found(have: Variant, known: Array) -> int:
    if not have is Dictionary:return 0
    var count:=0
    for id in known:
        if have.get(id) is bool and have[id]:count+=1
    return count

static func totals() -> Dictionary:
    if _totals.is_empty():
        var file:=FileAccess.open(TOTALS_PATH,FileAccess.READ)
        var parsed: Variant=JSON.parse_string(file.get_as_text()) if file!=null else null
        if parsed is Dictionary and parsed.get("regions") is Dictionary:_totals=parsed.regions
    return _totals

static func clock_text(total: int) -> String:
    return "%d:%02d" % [total/3600,(total%3600)/60]

## Seconds recorded beside `save_path`; 0 when nothing was recorded.
static func recorded(save_path: String) -> int:
    var reader:=new();reader.attach(save_path,true)
    return int(reader.seconds)

func attach(save_path: String, resume: bool) -> void:
    store.configure("playtime",save_path)
    seconds=0.0;saved=-1
    if not resume:return
    var payload:=store.read()
    var value: Variant=payload.get("seconds")
    if payload.size()==1 and typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0:
        seconds=float(value);saved=int(seconds)

func tick(delta: float) -> void:
    if is_finite(delta) and delta>0.0:seconds+=minf(delta,1.0)

## Called after the journey itself was saved.
func flush() -> void:
    if int(seconds)==saved:return
    if store.write({"seconds":int(seconds)}):saved=int(seconds)
