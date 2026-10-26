extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/k_trials/k14_turnaround/profile.gd")
const ENGINE := preload("res://journey/k_trials/engine.gd")
const FEATURE := preload("res://journey/features/k14_turnaround.gd")

func baseline() -> Dictionary:
    return {
        "slot":"fixture-slot",
        "region":"moss",
        "room":"entry",
        "wallet":100,
        "inventory":{"silk":3},
        "exploring":true,
        "at_shrine":false,
        "player":{
            "hp":2,
            "energy":70,
            "alive":true,
            "grounded":true,
            "position":[0, 0],
            "velocity":[0, 0],
        },
    }

func run() -> void:
    label = "K14_TURNAROUND"
    var context := fixture("k14_turnaround")
    check(MODEL.valid(MODEL.fresh()), "fresh record is valid")
    var source := baseline()
    source["unrelated_catalog"] = {"secret":"must not be retained"}
    var before := source.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), source)
    check(not active.is_empty() and active.state == "active", "start creates an active observation")
    check(source == before, "start never mutates production-like snapshot")
    check(not active.initial.has("unrelated_catalog") and not active.previous.has("unrelated_catalog"), "large unrelated context data is never retained by sessions")
    active.previous.room = "changed"
    check(source == before, "run snapshots are deep copies")
    active = MODEL.start(MODEL.fresh(), source)
    var cancelled := ENGINE.cancel(active)
    check(active.state == "active" and cancelled.state == "cancelled", "cancel is immutable and never passes")
    var recorded := MODEL.append(MODEL.fresh(), cancelled, 100)
    check(MODEL.valid(recorded) and recorded.records.size() == 1, "terminal observation publishes a valid history candidate")
    check(MODEL.append(MODEL.fresh(), active, 100) == MODEL.fresh(), "active observations cannot be persisted as complete")
    check(MODEL.records(recorded, "", "passed").is_empty(), "success filter excludes cancellation")
    check(MODEL.records(recorded, "moss", "cancelled").size() == 1, "location and state filter compose")
    check(MODEL.records(recorded, "absent", "all").is_empty(), "search excludes unmatched records")
    check(MODEL.document(recorded, "", "passed").find("cancelled") == -1, "export uses the visible state filter")
    check(MODEL.document(recorded).contains("cancelled"), "export contains the actual terminal state")
    var old := recorded.duplicate(true)
    var rows := MODEL.records(recorded)
    rows[0].reason = "changed"
    check(recorded == old, "history results cannot mutate stored data")
    for index in MODEL.HISTORY_LIMIT + 5:
        recorded = MODEL.append(recorded, cancelled, index)
    check(recorded.records.size() == MODEL.HISTORY_LIMIT and MODEL.valid(recorded), "old attempts are bounded without corrupting schema")
    var paused := source.duplicate(true)
    paused.exploring = false
    var held := ENGINE.step(active, paused, 0.2)
    check(held.elapsed == 0 and held.progress == 0, "menus pause elapsed time and scoring")
    var resumed := ENGINE.step(held, source, 0.2)
    check(resumed.elapsed == 0, "first resumed sample only establishes a baseline")
    var gap := ENGINE.step(active, source, 2.0)
    check(gap.elapsed == 0 and gap.gaps == 1, "long frame gaps do not invent elapsed training")
    var slot := source.duplicate(true)
    slot.slot = "another-slot"
    check(ENGINE.step(active, slot, 0.2).state == "interrupted", "slot changes cannot complete another slot's attempt")
    var dead := source.duplicate(true)
    dead.player.alive = false
    dead.player.hp = 0
    check(ENGINE.step(active, dead, 0.2).state == "failed", "death cannot produce a passing attempt")
    check(MODEL.start(MODEL.fresh(), dead).is_empty(), "dead snapshots cannot start")
    check(ENGINE.step(cancelled, source, 0.2) == cancelled, "terminal observations remain immutable")
    for value in [true, NAN, INF, -1, 0.5, MODEL.MAXIMUM + 1]:
        check(not MODEL.target_valid(value), "invalid target rejected: " + str(value))
        check(MODEL.configure(MODEL.fresh(), value) == MODEL.fresh(), "invalid target cannot change persisted settings")
    check(MODEL.valid(MODEL.configure(MODEL.fresh(), MODEL.MINIMUM)), "minimum target round-trips")
    check(MODEL.valid(MODEL.configure(MODEL.fresh(), MODEL.MAXIMUM)), "maximum target round-trips")
    rejects_missing_slot()
    rejects_empty_slot()
    rejects_slot_bool()
    rejects_missing_region()
    rejects_region_number()
    rejects_missing_room()
    rejects_room_array()
    rejects_exploring_number()
    rejects_shrine_string()
    rejects_negative_wallet()
    rejects_fractional_wallet()
    rejects_boolean_wallet()
    rejects_inventory_array()
    rejects_negative_item()
    rejects_fractional_item()
    rejects_boolean_item()
    rejects_player_array()
    rejects_missing_hp()
    rejects_negative_hp()
    rejects_fractional_hp()
    rejects_boolean_hp()
    rejects_energy_nan()
    rejects_energy_infinite()
    rejects_energy_negative()
    rejects_alive_string()
    rejects_grounded_number()
    rejects_position_missing()
    rejects_position_nan()
    rejects_position_wrong_size()
    rejects_velocity_infinite()
    teleport_does_not_finish()
    scoring_scenario()
    await feature_checks(context)
    finish()

func feature_checks(context: RefCounted) -> void:
    context.latest = baseline()
    var feature := FEATURE.new()
    feature.setup(context)
    check(feature.valid(feature.data), "feature loads a valid per-module record")
    var box := node_container()
    feature.draw(box)
    check(box.get_child_count() >= 10, "native controls expose goals, status, filters and history")
    feature.start()
    check(not feature.run.is_empty(), "native start uses the bound snapshot")
    var first := feature.run.duplicate(true)
    feature.start()
    check(feature.run == first, "repeated start cannot discard an active attempt")
    feature.cancel_attempt()
    check(feature.pending and feature.run.state == "cancelled", "native stop marks pending unsuccessful history")
    feature.tick(context.latest, 0.2)
    check(not feature.pending and feature.data.records.size() == 1, "completed auxiliary write clears pending state")
    feature.tick(context.latest, 0.2)
    check(feature.data.records.size() == 1, "published attempt is not saved twice")
    var reload := FEATURE.new()
    reload.setup(context)
    check(same_records(reload.data.records, feature.data.records), "fresh feature restores persisted history")
    check(reload.run.is_empty(), "restart never resumes an unverified active session")
    var stable: Dictionary = context.latest.duplicate(true)
    reload.release()
    check(context.latest == stable, "closing the page never mutates gameplay state")
    box.free()

func rejects_missing_slot() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.erase("slot")
    check(not ENGINE.sample_valid(s), "missing_slot: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "missing_slot: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "missing_slot: active observation fails closed")
    check(active.state == "active" and active.previous == original, "missing_slot: rejected sample leaves source session unchanged")


func rejects_empty_slot() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.slot = ""
    check(not ENGINE.sample_valid(s), "empty_slot: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "empty_slot: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "empty_slot: active observation fails closed")
    check(active.state == "active" and active.previous == original, "empty_slot: rejected sample leaves source session unchanged")


func rejects_slot_bool() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.slot = true
    check(not ENGINE.sample_valid(s), "slot_bool: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "slot_bool: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "slot_bool: active observation fails closed")
    check(active.state == "active" and active.previous == original, "slot_bool: rejected sample leaves source session unchanged")


func rejects_missing_region() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.erase("region")
    check(not ENGINE.sample_valid(s), "missing_region: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "missing_region: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "missing_region: active observation fails closed")
    check(active.state == "active" and active.previous == original, "missing_region: rejected sample leaves source session unchanged")


func rejects_region_number() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.region = 4
    check(not ENGINE.sample_valid(s), "region_number: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "region_number: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "region_number: active observation fails closed")
    check(active.state == "active" and active.previous == original, "region_number: rejected sample leaves source session unchanged")


func rejects_missing_room() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.erase("room")
    check(not ENGINE.sample_valid(s), "missing_room: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "missing_room: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "missing_room: active observation fails closed")
    check(active.state == "active" and active.previous == original, "missing_room: rejected sample leaves source session unchanged")


func rejects_room_array() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.room = []
    check(not ENGINE.sample_valid(s), "room_array: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "room_array: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "room_array: active observation fails closed")
    check(active.state == "active" and active.previous == original, "room_array: rejected sample leaves source session unchanged")


func rejects_exploring_number() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.exploring = 1
    check(not ENGINE.sample_valid(s), "exploring_number: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "exploring_number: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "exploring_number: active observation fails closed")
    check(active.state == "active" and active.previous == original, "exploring_number: rejected sample leaves source session unchanged")


func rejects_shrine_string() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.at_shrine = "yes"
    check(not ENGINE.sample_valid(s), "shrine_string: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "shrine_string: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "shrine_string: active observation fails closed")
    check(active.state == "active" and active.previous == original, "shrine_string: rejected sample leaves source session unchanged")


func rejects_negative_wallet() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.wallet = -1
    check(not ENGINE.sample_valid(s), "negative_wallet: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "negative_wallet: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "negative_wallet: active observation fails closed")
    check(active.state == "active" and active.previous == original, "negative_wallet: rejected sample leaves source session unchanged")


func rejects_fractional_wallet() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.wallet = 0.5
    check(not ENGINE.sample_valid(s), "fractional_wallet: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "fractional_wallet: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "fractional_wallet: active observation fails closed")
    check(active.state == "active" and active.previous == original, "fractional_wallet: rejected sample leaves source session unchanged")


func rejects_boolean_wallet() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.wallet = true
    check(not ENGINE.sample_valid(s), "boolean_wallet: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "boolean_wallet: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "boolean_wallet: active observation fails closed")
    check(active.state == "active" and active.previous == original, "boolean_wallet: rejected sample leaves source session unchanged")


func rejects_inventory_array() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.inventory = []
    check(not ENGINE.sample_valid(s), "inventory_array: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "inventory_array: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "inventory_array: active observation fails closed")
    check(active.state == "active" and active.previous == original, "inventory_array: rejected sample leaves source session unchanged")


func rejects_negative_item() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.inventory = {"silk":-1}
    check(not ENGINE.sample_valid(s), "negative_item: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "negative_item: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "negative_item: active observation fails closed")
    check(active.state == "active" and active.previous == original, "negative_item: rejected sample leaves source session unchanged")


func rejects_fractional_item() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.inventory = {"silk":0.5}
    check(not ENGINE.sample_valid(s), "fractional_item: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "fractional_item: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "fractional_item: active observation fails closed")
    check(active.state == "active" and active.previous == original, "fractional_item: rejected sample leaves source session unchanged")


func rejects_boolean_item() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.inventory = {"silk":true}
    check(not ENGINE.sample_valid(s), "boolean_item: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "boolean_item: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "boolean_item: active observation fails closed")
    check(active.state == "active" and active.previous == original, "boolean_item: rejected sample leaves source session unchanged")


func rejects_player_array() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player = []
    check(not ENGINE.sample_valid(s), "player_array: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "player_array: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "player_array: active observation fails closed")
    check(active.state == "active" and active.previous == original, "player_array: rejected sample leaves source session unchanged")


func rejects_missing_hp() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.erase("hp")
    check(not ENGINE.sample_valid(s), "missing_hp: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "missing_hp: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "missing_hp: active observation fails closed")
    check(active.state == "active" and active.previous == original, "missing_hp: rejected sample leaves source session unchanged")


func rejects_negative_hp() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.hp = -1
    check(not ENGINE.sample_valid(s), "negative_hp: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "negative_hp: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "negative_hp: active observation fails closed")
    check(active.state == "active" and active.previous == original, "negative_hp: rejected sample leaves source session unchanged")


func rejects_fractional_hp() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.hp = 1.5
    check(not ENGINE.sample_valid(s), "fractional_hp: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "fractional_hp: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "fractional_hp: active observation fails closed")
    check(active.state == "active" and active.previous == original, "fractional_hp: rejected sample leaves source session unchanged")


func rejects_boolean_hp() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.hp = true
    check(not ENGINE.sample_valid(s), "boolean_hp: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "boolean_hp: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "boolean_hp: active observation fails closed")
    check(active.state == "active" and active.previous == original, "boolean_hp: rejected sample leaves source session unchanged")


func rejects_energy_nan() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.energy = NAN
    check(not ENGINE.sample_valid(s), "energy_nan: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "energy_nan: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "energy_nan: active observation fails closed")
    check(active.state == "active" and active.previous == original, "energy_nan: rejected sample leaves source session unchanged")


func rejects_energy_infinite() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.energy = INF
    check(not ENGINE.sample_valid(s), "energy_infinite: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "energy_infinite: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "energy_infinite: active observation fails closed")
    check(active.state == "active" and active.previous == original, "energy_infinite: rejected sample leaves source session unchanged")


func rejects_energy_negative() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.energy = -1
    check(not ENGINE.sample_valid(s), "energy_negative: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "energy_negative: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "energy_negative: active observation fails closed")
    check(active.state == "active" and active.previous == original, "energy_negative: rejected sample leaves source session unchanged")


func rejects_alive_string() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.alive = "true"
    check(not ENGINE.sample_valid(s), "alive_string: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "alive_string: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "alive_string: active observation fails closed")
    check(active.state == "active" and active.previous == original, "alive_string: rejected sample leaves source session unchanged")


func rejects_grounded_number() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.grounded = 1
    check(not ENGINE.sample_valid(s), "grounded_number: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "grounded_number: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "grounded_number: active observation fails closed")
    check(active.state == "active" and active.previous == original, "grounded_number: rejected sample leaves source session unchanged")


func rejects_position_missing() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.erase("position")
    check(not ENGINE.sample_valid(s), "position_missing: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "position_missing: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "position_missing: active observation fails closed")
    check(active.state == "active" and active.previous == original, "position_missing: rejected sample leaves source session unchanged")


func rejects_position_nan() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.position = [NAN, 0]
    check(not ENGINE.sample_valid(s), "position_nan: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "position_nan: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "position_nan: active observation fails closed")
    check(active.state == "active" and active.previous == original, "position_nan: rejected sample leaves source session unchanged")


func rejects_position_wrong_size() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.position = [0]
    check(not ENGINE.sample_valid(s), "position_wrong_size: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "position_wrong_size: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "position_wrong_size: active observation fails closed")
    check(active.state == "active" and active.previous == original, "position_wrong_size: rejected sample leaves source session unchanged")


func rejects_velocity_infinite() -> void:
    var s := baseline()
    var original := s.duplicate(true)
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.velocity = [INF, 0]
    check(not ENGINE.sample_valid(s), "velocity_infinite: sample boundary rejects malformed input")
    check(MODEL.start(MODEL.fresh(), s).is_empty(), "velocity_infinite: invalid start cannot run")
    var outcome := ENGINE.step(active, s, 0.2)
    check(outcome.state == "interrupted", "velocity_infinite: active observation fails closed")
    check(active.state == "active" and active.previous == original, "velocity_infinite: rejected sample leaves source session unchanged")

func scoring_scenario() -> void:
    var data := MODEL.configure(MODEL.fresh(), MODEL.MINIMUM)
    var s := baseline()
    var active := MODEL.start(data, s)
    check(ENGINE.step(active, s, 0.2).state != "passed", "unchanged first sample does not invent completion")
    for x in [500, 1000, 500, 0]:
        s.player.position = [x, 0]
        active = ENGINE.step(active, s, 0.2)
    check(active.state == "passed", "authored positive trace completes this specific challenge")
    check(active.progress >= active.target, "completion requires the full requested goal")
    check(MODEL.valid(MODEL.append(data, active, 123)), "positive trace produces a schema-valid report")
    var terminal := active.duplicate(true)
    var dead := baseline()
    dead.player.alive = false
    check(ENGINE.step(active, dead, 0.2) == terminal, "later death cannot rewrite an already completed observation")

func same_records(left: Array, right: Array) -> bool:
    if left.size() != right.size():
        return false
    for index in left.size():
        var a: Dictionary = left[index]
        var b: Dictionary = right[index]
        if a.size() != b.size():
            return false
        for key in a:
            if not b.has(key):
                return false
            if VALUES.number(a[key]) and VALUES.number(b[key]):
                if not is_equal_approx(float(a[key]), float(b[key])):
                    return false
            elif a[key] != b[key]:
                return false
    return true

func teleport_does_not_finish() -> void:
    var s := baseline()
    var active := MODEL.start(MODEL.fresh(), s)
    s.player.position = [1500, 0]
    active = ENGINE.step(active, s, 0.2)
    s.player.position = [0, 0]
    active = ENGINE.step(active, s, 0.2)
    check(active.state == "active" and active.progress == 0, "teleport-like discontinuities cannot complete turnaround")
    check(active.peak_distance == 0 and active.gaps == 2, "discontinuous samples do not establish a distance peak")
