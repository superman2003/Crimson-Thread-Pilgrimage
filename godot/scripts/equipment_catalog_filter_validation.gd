extends SceneTree
const FILTER = preload("res://scripts/equipment_catalog_filter.gd")
const UI = preload("res://scripts/pilgrimage_interface.gd")
const FIXTURE = preload("res://scripts/build_slots_ui_validation.gd")
var checks := 0
var failures := 0
const SETTINGS := "user://equipment_catalog_filter_fixture.cfg"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL EQUIPMENT_FILTER: " + label)

func entry(id: String, title: String, family: String, unlocked: bool = true) -> Dictionary:
    return {"id":id, "name":title, "slot_family":family,
        "unlocked":unlocked, "description":"已知装备说明", "cost":1}

func slot(family: String, index: int, allowed: Array, unlocked: bool = true) -> Dictionary:
    return {"id":family+str(index), "family":family, "index":index,
        "compatible":allowed, "unlocked":unlocked, "equipped_id":""}

func model_checks() -> void:
    var items := [entry("needle","丝针","thread_skill"), entry("cleave","裂斩","thread_skill"), entry("locked","未解锁线术","thread_skill",false)]
    var before := items.duplicate(true)
    check(FILTER.normalize("　NEEDLE\t \n") == "needle", "public search handles case and full-width whitespace")
    check(FILTER.matches(items[0],"NEEDLE 丝"), "all public name/ID tokens match")
    check(not FILTER.matches(items[0],"NEEDLE 裂"), "all tokens are required")
    items[0]["requires_flag"]="未公开的隐秘终局"
    check(not FILTER.matches(items[0],"隐秘终局"), "hidden requirements never enter public search")
    items = before.duplicate(true)
    var restricted := slot("thread_skill",0,["cleave"])
    var view := FILTER.select(items,"thread_skill",restricted,"",false)
    check(view.entries.size() == 3, "default view preserves all existing choices")
    view = FILTER.select(items,"thread_skill",restricted,"",true)
    check(view.shown == 1 and view.entries[0].id == "cleave", "compatible-only checks actual slot list and unlock state")
    check(view.total == 3 and items == before, "filtering retains source catalog and total count")
    view.entries[0].name="changed outside"
    check(items == before, "returned rows cannot alias live catalog")
    check(FILTER.select(items,"thread_skill",restricted,"丝针",true).shown == 0, "search cannot bypass slot incompatibility")
    check(FILTER.select(items,"thread_skill",slot("thread_skill",0,[],false),"",true).empty_reason.contains("未解锁"), "locked-slot empty state explains the gate")
    check(FILTER.select(items,"thread_skill",slot("thread_skill",0,[]),"",true).shown == 2, "unrestricted slot still excludes locked entries")
    check(FILTER.select(items,"tool",{},"",true).shown == 0, "family mismatch never becomes compatible")
    check(FILTER.select(items,"thread_skill",{},"",true).shown == 2, "legacy layouts remain filterable without inventing lock state")
    check(FILTER.select([null,4,"needle",{}],"tool",{},"needle",false).shown == 0, "malformed non-entries do not become matches")
    var memory := FILTER.new()
    for family in FILTER.FAMILIES:
        memory.remember(family,family,true)
    for family in FILTER.FAMILIES:
        check(memory.page(family).query == family and memory.page(family).only_compatible, "each equipment family retains independent filter state")
    var copy := memory.page("tool")
    copy.query="external edit"
    check(memory.page("tool").query == "tool", "filter memory cannot be changed through returned dictionary")
    memory.remember("unknown","hidden",true)
    check(memory.page("unknown").query == "", "unknown pages do not acquire equipment state")
    memory.remember("tool","x".repeat(200),false)
    check(memory.page("tool").query.length() == FILTER.QUERY_LIMIT, "input work is bounded")

func make_runtime() -> Node:
    var runtime := FIXTURE.MockRuntime.new()
    runtime.player = FIXTURE.MockPlayer.new()
    runtime.add_child(runtime.player)
    runtime.build_system = FIXTURE.MockBuild.new()
    runtime.world_narrative = FIXTURE.MockNarrative.new()
    var skills := [entry("cleave","裂斩","thread_skill"),entry("needle","丝针","thread_skill"),entry("locked","隐线术","thread_skill",false)]
    var tools := [entry("shard","碎片","tool"),entry("mine","线雷","tool")]
    runtime.build_system.snapshot={"at_workstation":true,"slots_used":0,"slots_total":3,
        "skills":skills,"tools":tools,"passive_options":[],"crests":[],
        "slot_layout":{"thread_skill":[slot("thread_skill",0,["cleave","needle"]),slot("thread_skill",1,["cleave"])],
            "tool":[slot("tool",0,["shard","mine"]),slot("tool",1,["mine"])],
            "combat_accessory":[slot("combat_accessory",0,["mender"])],"travel_accessory":[slot("travel_accessory",0,["wayfinder"])]},
        "slot_families":{"thread_skill":{"id":"thread_skill","name":"绯线技","options":skills},
            "tool":{"id":"tool","name":"战具","options":tools},
            "combat_accessory":{"id":"combat_accessory","name":"战斗铭饰","options":[entry("mender","愈线铭饰","combat_accessory")]},
            "travel_accessory":{"id":"travel_accessory","name":"行旅铭饰","options":[entry("wayfinder","引路铭饰","travel_accessory")]}}}
    root.add_child(runtime)
    return runtime

func ids(ui: Node) -> Array[String]:
    var found: Array[String] = []
    for button in ui.build_grid.get_children():
        if button.has_meta("build_id"): found.append(String(button.get_meta("build_id")))
    return found

func query(ui: Node, text: String) -> void:
    ui.equipment_search.text = text
    ui.equipment_search.text_changed.emit(text)

func runtime_checks() -> void:
    var runtime := make_runtime()
    var ui := UI.new()
    ui.accessibility_path = SETTINGS
    runtime.add_child(ui)
    ui.bind(runtime)
    ui.set_process(false)
    ui.build_panel.show()
    ui.build_category="技能"
    ui.refresh_build()
    check(ui.equipment_search.visible and ui.equipment_compatible.visible, "actual equipment page exposes native controls")
    check(ids(ui) == ["cleave","needle","locked"], "default catalog order and locked rows retained")
    ui.equipment_compatible.grab_focus()
    var left:=InputEventJoypadButton.new()
    left.button_index=JOY_BUTTON_DPAD_LEFT
    left.pressed=true
    ui.get_viewport().push_input(left)
    await process_frame
    check(ui.get_viewport().gui_get_focus_owner() == ui.equipment_search, "actual controller direction reaches search from compatibility toggle")
    var target_path: NodePath=ui.equipment_search.focus_neighbor_bottom
    check(not target_path.is_empty() and ui.equipment_search.get_node(target_path).get_meta("build_id","") == "cleave", "filter row leads to enabled first option")
    var original_wallet: Array = [runtime.currency_count,runtime.inventory_counts.duplicate(true)]
    var original_state: Dictionary = runtime.build_system.state.duplicate(true)
    ui.equipment_search.grab_focus()
    query(ui,"丝针")
    check(ids(ui) == ["needle"], "real text signal narrows native option buttons")
    check(ui.get_viewport().gui_get_focus_owner() == ui.equipment_search, "rebuild never steals typing focus")
    check(ui.is_text_entry_focused(), "existing gameplay-input guard recognizes new search")
    var typed:=InputEventKey.new()
    typed.pressed=true
    typed.keycode=KEY_B
    typed.unicode=98
    ui.get_viewport().push_input(typed)
    check(ui.equipment_search.text.contains("b"), "actual keyboard event edits search rather than invoking build shortcut")
    query(ui,"丝针")
    check(runtime.action_calls.is_empty(), "typing cannot equip or spend resources")
    ui.equipment_search.text_submitted.emit("丝针")
    check(ui.get_viewport().gui_get_focus_owner().get_meta("build_id","") == "needle", "submit focuses an enabled result without activating it")
    check(runtime.action_calls.is_empty(), "keyboard submission cannot silently equip")
    query(ui,"")
    ui.equipment_compatible.button_pressed=true
    check(ids(ui) == ["cleave","needle"], "native checkbox excludes unavailable choices")
    ui.build_slot_buttons[1].pressed.emit()
    check(ids(ui) == ["cleave"], "selected slot compatibility controls actual filtered result")
    query(ui,"不存在")
    check(ids(ui).is_empty() and ui.build_detail.text.contains("没有匹配"), "zero results explain recovery instead of showing stale item")
    check(ui.equipment_search.focus_neighbor_bottom.is_empty(), "empty result removes obsolete focus path")
    check(ui.build_heading.text == "没有匹配装备" and ui.build_emblem.texture == null, "zero results clear stale heading and emblem")
    ui.build_tabs[2].pressed.emit()
    check(ui.equipment_search.text == "" and not ui.equipment_compatible.button_pressed, "tool family does not inherit skill query")
    query(ui,"线雷")
    check(ids(ui) == ["mine"], "tool query uses actual tool names")
    ui.build_tabs[1].pressed.emit()
    check(ui.equipment_search.text == "不存在" and ui.equipment_compatible.button_pressed, "returning to family restores its own controls")
    query(ui,"")
    ui.equipment_compatible.button_pressed=false
    check(ids(ui).size() == 3, "clear restores full known category")
    check(not ui.equipment_search.focus_neighbor_bottom.is_empty(), "clearing search installs fresh result focus path")
    ui.build_tabs[3].pressed.emit()
    query(ui,"愈线")
    check(ids(ui) == ["mender"], "combat accessory page supports matching")
    ui.family_selector_buttons[1].pressed.emit()
    check(ui.equipment_search.text == "" and ids(ui) == ["wayfinder"], "travel accessories have independent query and correct options")
    ui.family_selector_buttons[0].pressed.emit()
    check(ui.equipment_search.text == "愈线", "accessory family switching restores its query")
    ui.build_tabs[1].pressed.emit()
    ui.equipment_compatible.button_pressed=true
    runtime.build_system.snapshot.slot_layout.thread_skill[1].unlocked=false
    ui.build_assign_slot=1
    ui.refresh_build()
    check(ids(ui).is_empty() and ui.build_detail.text.contains("未解锁"), "changing build to a locked slot produces recoverable empty state")
    runtime.build_system.snapshot.slot_layout.thread_skill[1].unlocked=true
    ui.refresh_build()
    check(ids(ui) == ["cleave"], "unlocking selected slot refreshes compatibility without resetting search")
    check([runtime.currency_count,runtime.inventory_counts] == original_wallet and runtime.build_system.state == original_state, "all filters and page changes leave wallet and equipment untouched")
    var search_rect := Rect2(ui.equipment_search.position,ui.equipment_search.size)
    check(search_rect.end.y <= ui.equipment_scroll.position.y, "search controls reserve space above list")
    check(search_rect.end.x <= ui.equipment_compatible.position.x, "search and controller checkbox do not overlap")
    check(ui.equipment_scroll.position.y+ui.equipment_scroll.size.y <= 532, "filtered list stays in original panel bounds")
    ui.build_tabs[0].pressed.emit()
    check(not ui.equipment_search.visible and ui.equipment_scroll.position.y == 180, "crest illustration layout remains unchanged")
    runtime.build_system.snapshot.at_workstation=false
    ui.build_category="技能"
    ui.refresh_build()
    check(not ui.equipment_search.visible and not ui.equipment_compatible.visible, "road does not offer backpack reconfiguration through filtering")
    check(ui.build_grid.get_child_count() == 2 and runtime.action_calls.is_empty(), "road still contains only configured skill/tool cycling")
    runtime.queue_free()
    await process_frame
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))

func focus_checks() -> void:
    var grid:=VBoxContainer.new()
    root.add_child(grid)
    var disabled:=Button.new()
    disabled.disabled=true
    grid.add_child(disabled)
    var hidden:=Button.new()
    grid.add_child(hidden)
    hidden.hide()
    var enabled:=Button.new()
    grid.add_child(enabled)
    await process_frame
    check(FILTER.first_enabled(grid) == enabled, "submission skips both locked and hidden choices")
    enabled.grab_focus()
    check(root.gui_get_focus_owner() == enabled, "returned native control can receive real keyboard/controller focus")
    enabled.queue_free()
    check(FILTER.first_enabled(grid) == null, "queued option cannot become late focus target")
    disabled.disabled=false
    check(FILTER.first_enabled(grid) == disabled, "newly enabled choice is immediately focusable")
    grid.queue_free()
    await process_frame

func run() -> void:
    model_checks()
    await runtime_checks()
    await focus_checks()
    print("EQUIPMENT_CATALOG_FILTER checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
