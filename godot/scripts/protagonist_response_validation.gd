extends RefCounted
const NARRATIVE := preload("res://scripts/world_narrative.gd")
func run(narrative: RefCounted,check: Callable) -> void:
    var total := 0
    var modes := {}
    for entry in narrative.entries.values():
        for state in entry.get("states",[]):
            if String(state.get("response","")).is_empty():continue
            total += 1
            modes[String(state.get("response_mode",""))]=true
            var before: Dictionary = state.duplicate(true)
            var last: int = state.get("lines",[]).size()-1
            var response := NARRATIVE.completion_response(state,last,{})
            check.call(response.begins_with("巡礼者 · ") and response.length()<=54,"authored response is brief and identifies its speaker")
            check.call(NARRATIVE.completion_response(state,last-1,{}).is_empty(),"an incomplete conversation cannot present a protagonist response")
            var committed := {}
            for flag in NARRATIVE.completion_outcome(state,last,{}).flags:committed[flag]=true
            check.call(NARRATIVE.completion_response(state,last,committed).is_empty(),"revisiting a committed conversation cannot repeat its response")
            check.call(state==before,"response evaluation never changes dialogue data")
    check.call(total==11 and modes.size()==3,"six-region key conversations cover speech, gesture and resonance responses")
    var malformed := {"response":"长".repeat(49),"lines":["end"],"grant_flags":["test"]}
    check.call(NARRATIVE.completion_response(malformed,0,{}).is_empty(),"long responses cannot turn into an unsolicited monologue")
    malformed.response="短句"
    malformed.response_mode="unknown"
    check.call(NARRATIVE.completion_response(malformed,0,{}).is_empty(),"undefined response mode is not presented")
