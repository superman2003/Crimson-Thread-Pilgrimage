extends RefCounted
const VOICE:=preload("res://scripts/protagonist_voice.gd")

func run(main: Node,tree: SceneTree,check: Callable) -> void:
    var abilities:=["thread_dash","silk_wall_grip","double_thread_jump","echo_hook","bell_guard","thorn_downstrike","lantern_phase","crown_resonance"]
    var entries: Array=VOICE.catalogue()
    var authored: Array=[]
    for entry in entries:authored.append(String(entry.ability))
    abilities.sort()
    authored.sort()
    check.call(authored==abilities,"eight reflections cover exactly the production permanent-ability identities")
    check.call(VOICE.records({}).is_empty(),"unearned reflections reveal no titles or ability identities")
    for invalid in [true,false,"1",-1,0,0.5,NAN,INF,1000001]:
        check.call(VOICE.records({"thread_dash":invalid}).is_empty(),"malformed or unearned inventory cannot reveal a reflection: %s" % str(invalid))
    var counts: Dictionary={}
    for index in abilities.size():
        counts[abilities[index]]=1
        # Combination reflections join once every required ability is held.
        var rows: Array=VOICE.records(counts).filter(func(row: Dictionary):return not String(row.id).begins_with("voice_combo_"))
        check.call(rows.size()==index+1 and String(rows.back().record_kind)=="voice","each distinct earned ability adds one reflection without requiring exploration order")
    var all_rows: Array=VOICE.records(counts)
    counts.thread_dash=3
    check.call(VOICE.records(counts)==all_rows and all_rows.size()>=8,"duplicate ability copies never duplicate the journal note")
    var restored: Dictionary=JSON.parse_string(JSON.stringify(counts))
    check.call(VOICE.records(restored)==VOICE.records(counts),"existing JSON inventory alone reconstructs reflections without a new save field")
    var private_rows: Array=VOICE.catalogue()
    private_rows[0].text="changed"
    check.call(VOICE.catalogue()[0].text!="changed","catalogue callers cannot overwrite shared authored reflections")
    var short:=true
    for row in VOICE.records(counts):short=short and String(row.description).length()<80
    check.call(short,"all reflections remain short and require no modal interruption")
    var original_inventory: Dictionary=main.inventory_counts.duplicate(true)
    var original_flags: Dictionary=main.story_flags.duplicate(true)
    var ui: Node=main.ui_shell
    main._toggle_backpack()
    ui.bag_category="旅记"
    ui.journal_filter_buttons.voice.pressed.emit()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count()==0 and ui.bag_name.text=="尚无自述","new-game voice category withholds unearned notes")
    # Explicit component inventory fixture, not a natural acquisition route.
    main.inventory_counts["silk_wall_grip"]=1
    ui.refresh_inventory()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count()==1 and ui.bag_name.text=="攀住裂口" and ui.bag_category_label.text.contains("自述"),"production journal displays only the owned ability's reflection")
    check.call(main.story_flags==original_flags and main.active_overlay=="backpack","reading voice notes creates neither story flags nor an interrupting dialogue")
    main.inventory_counts=original_inventory
    ui.refresh_inventory()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count()==0,"removing fixture ownership removes the derived reflection")
    main._close_overlays()
