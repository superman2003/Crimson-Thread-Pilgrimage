extends RefCounted
const CONTACTS := preload("res://scripts/quest_contacts.gd")
const NARRATIVE := preload("res://scripts/world_narrative.gd")

func run(tree: SceneTree, world: Node) -> void:
    var data := CONTACTS.catalog()
    tree.check(CONTACTS.valid(data), "all five quests have bounded authored next-step context")
    if data.is_empty():
        return
    var narrative := NARRATIVE.new()
    for quest in narrative.story_data.quests:
        var id := String(quest.id)
        tree.check(CONTACTS.for_quest(id, {}, {}).is_empty(), "an unaccepted optional quest reveals no contact or destination")
        var inventory := {}
        var flags := {String(quest.started_flag): true}
        for index in quest.journal_steps.size():
            var before := [inventory.duplicate(true), flags.duplicate(true)]
            var context := CONTACTS.for_quest(id, inventory, flags)
            tree.check(not context.is_empty() and context.step == index, "the first canonical unfinished step determines the next destination")
            if not context.is_empty():
                tree.check(context.phase == "next" and not context.place.contains("demo_"), "public context is localized and distinguished from reward or reunion")
                tree.check(not context.has("steps") and not context.has("flags_all"), "future authored steps and conditions are not exposed in a public row")
                var text := "\n".join(CONTACTS.appendix(id, inventory, flags))
                tree.check(text.contains(context.place) and text.contains(context.why), "each objective explains both where to go and why")
            tree.check(before == [inventory, flags], "looking up a contact neither advances steps nor changes resources")
            var step: Dictionary = quest.journal_steps[index]
            for flag in step.get("flags_all", []):
                flags[String(flag)] = true
            var items: Array = step.get("items_any", [])
            if not items.is_empty():
                inventory[String(items[0])] = 1
            for ability in step.get("abilities_all", []):
                inventory[String(ability)] = 1
        var pending := CONTACTS.for_quest(id, inventory, flags)
        tree.check(not pending.is_empty() and pending.phase == "reward", "a completed legacy quest with no claim marker points to its actual reward owner")
        tree.check(pending.npc == data.quests[id].return_to, "the return contact matches the authored one-time reward owner")
        flags[String(quest.reward_flag)] = true
        var reunion := CONTACTS.for_quest(id, inventory, flags)
        tree.check(reunion.phase == "reunion", "a paid quest offers reunion without promising another reward")
        var restored: Dictionary = JSON.parse_string(JSON.stringify(flags))
        tree.check(CONTACTS.for_quest(id, inventory, restored) == reunion, "existing JSON save flags reconstruct the same contact without new save fields")
        tree.check(CONTACTS.for_quest(id, inventory, {String(quest.started_flag): "true"}).is_empty(), "truthy strings cannot invent accepted quests")

    var root_flags := {"quest_root_rescue_started": true, "quest_root_rescue_complete": true, "reward_root_rescue_claimed": true}
    var root := CONTACTS.for_quest("root_rescue", {}, root_flags)
    tree.check(root.room == "root_vault", "quest completion alone does not invent an unsaved migration")
    root_flags.npc_root_prisoner_at_west_gate = true
    root = CONTACTS.for_quest("root_rescue", {}, root_flags)
    tree.check(root.room == "west_gate" and root.place.contains("温室西门"), "saved prisoner relocation moves the reunion target to the real west gate")
    root_flags.npc_root_prisoner_at_west_gate = "true"
    tree.check(CONTACTS.for_quest("root_rescue", {}, root_flags).room == "root_vault", "a malformed migration marker cannot move a public contact")
    var deserter_flags := {"quest_deserter_order_complete": true, "reward_deserter_order_claimed": true}
    tree.check(CONTACTS.for_quest("deserter_order", {}, deserter_flags).room == "war_graves", "unmoved flagbearer still belongs to his authored starting room")
    deserter_flags.npc_deserter_at_camp = true
    tree.check(CONTACTS.for_quest("deserter_order", {}, deserter_flags).room == "pilgrim_camp", "saved flagbearer migration points to the actual camp")
    var lantern_flags := {"quest_lantern_watch_started": true}
    var lantern := CONTACTS.for_quest("lantern_watch", {"silent_order": 1}, lantern_flags)
    tree.check(lantern.room == "pilgrim_camp", "lantern acquisition guidance uses the production acquisition plan rather than the boss arena")
    for invalid in [-1, 0, 0.5, true, "1", INF, NAN]:
        var next := CONTACTS.for_quest("lantern_watch", {"silent_order": invalid}, lantern_flags)
        tree.check(next.step == 0, "invalid item counts cannot skip the document objective")
    var wax_flags := {"quest_wax_lamps_started": true}
    tree.check(CONTACTS.for_quest("wax_lamps", {"pollen_wax": 1.0}, wax_flags).npc == "npc_beeswax_vendor", "a real saved material count advances to the merchant contact")
    tree.check(CONTACTS.for_quest("unknown", {}, {}).is_empty(), "unknown quests have no invented route")
    var copy := CONTACTS.catalog()
    copy.quests.root_rescue.steps.clear()
    tree.check(CONTACTS.catalog().quests.root_rescue.steps.size() == 2, "callers cannot erase cached quest context")
    var broken := CONTACTS.catalog()
    broken.quests.root_rescue.steps[0]["npc"] = "npc_root_prisoner"
    tree.check(not CONTACTS.valid(broken), "an objective cannot ambiguously name both an ability and an NPC")

    var inventory_before: Dictionary = world.inventory_counts.duplicate(true)
    var flags_before: Dictionary = world.story_flags.duplicate(true)
    var overlay_before: String = world.active_overlay
    world.inventory_counts = {"thorn_downstrike": 1}
    world.story_flags = {"quest_root_rescue_started": true}
    var record: Dictionary = narrative.quest_journal(world.inventory_counts, world.story_flags)[0].merged({"record_kind": "quest"})
    world.ui_shell._show_journal_record(record)
    var text: String = world.ui_shell.bag_description.text
    tree.check(text.contains("联系谁：根笼囚徒") and text.contains("断弦温室 · 根库"), "the real journal places the active rescue at the current NPC's room")
    tree.check(not text.contains("奖励已领取") and world.active_overlay == overlay_before, "reading the contact does not claim a reward or open a gameplay modal")
    world.story_flags = {"quest_root_rescue_complete": true, "reward_root_rescue_claimed": true, "npc_root_prisoner_at_west_gate": true}
    record = narrative.quest_journal(world.inventory_counts, world.story_flags)[0].merged({"record_kind": "quest"})
    world.ui_shell._show_journal_record(record)
    tree.check(world.ui_shell.bag_description.text.contains("温室西门") and world.ui_shell.bag_description.text.contains("接下来 · 重逢"), "the same production reader follows a saved reunion instead of the old root cage")
    world.inventory_counts = inventory_before
    world.story_flags = flags_before

func migrated_reader(tree: SceneTree, world: Node) -> void:
    var rows: Array = world.world_narrative.quest_journal(world.inventory_counts, world.story_flags)
    for row in rows:
        if row.id != "root_rescue":
            continue
        world.ui_shell._show_journal_record(row.merged({"record_kind": "quest"}))
        tree.check(world.ui_shell.bag_description.text.contains("温室西门"), "a real successful rescue transaction immediately updates the production reunion destination")
        tree.check(CONTACTS.for_quest("root_rescue", world.inventory_counts, world.story_flags).phase == "reunion", "the actual rescued NPC and paid reward share one contact state")
        return
    tree.check(false, "a committed rescue remains present in the quest journal")
