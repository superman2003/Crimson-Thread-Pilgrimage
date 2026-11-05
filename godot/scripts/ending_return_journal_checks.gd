extends RefCounted
const GUIDE := preload("res://scripts/ending_return_journal.gd")
const CONTACTS := preload("res://scripts/quest_contacts.gd")

func pure(tree: SceneTree) -> void:
    tree.check(GUIDE.valid(GUIDE.catalog()), "optional return context covers exactly five accepted relationships and three endings")
    var narrative := CONTACTS.narrative()
    for ending in GUIDE.ENDINGS:
        var ended := {"ending_chosen": ending}
        tree.check(GUIDE.records({}, ended).is_empty(), "finishing the main line does not reveal unaccepted optional quests")
        for quest in narrative.story_data.quests:
            var id := String(quest.id)
            var active := ended.merged({String(quest.started_flag): true})
            var before := active.duplicate(true)
            var rows := GUIDE.rows({}, active)
            tree.check(rows.size() == 1 and rows[0].stage == "active", "each ending retains the actual unfinished promise")
            tree.check(rows[0].source_key == "quest:" + id and rows[0].context == GUIDE.catalog().quests[id][ending].active, "only the accepted task and selected ending supply context")
            tree.check(rows[0].guidance == CONTACTS.for_quest(id, {}, active).label, "return guidance uses the first unfinished production objective")
            var complete := ended.merged({String(quest.complete_flag): true})
            rows = GUIDE.rows({}, complete)
            tree.check(rows.size() == 1 and rows[0].stage == "reward", "legacy completed quests settle their unclaimed original reward before a reunion")
            complete[String(quest.reward_flag)] = true
            rows = GUIDE.rows({}, complete)
            tree.check(rows.size() == 1 and rows[0].stage in ["confirm", "ready"], "a paid quest does not imply that extra unlocks and migrations were saved")
            var owner := String(CONTACTS.catalog().quests[id].return_to)
            for coda in narrative.entries[owner].states:
                if coda.get("quest_coda") != id or coda.get("ending") != ending:
                    continue
                var ready := ended.duplicate(true)
                for flag in coda.flags_all:
                    ready[String(flag)] = true
                rows = GUIDE.rows({}, ready)
                tree.check(rows.size() == 1 and rows[0].stage == "ready", "the actual resolver confirms all fifteen available personal reunions")
                tree.check(rows[0].place == CONTACTS.for_quest(id, {}, ready).place, "ready reunions follow the actual saved NPC destination")
                var record: Dictionary = GUIDE.records({}, ready)[0]
                for line in coda.lines:
                    tree.check(not record.description.contains(line), "the guide never quotes the unheard personal conversation")
                for requirement in coda.flags_all:
                    if String(requirement).ends_with("_done"):
                        continue
                    var missing := ready.duplicate(true)
                    missing.erase(String(requirement))
                    var remaining := GUIDE.rows({}, missing)
                    tree.check(remaining.is_empty() or remaining[0].stage != "ready", "a missing reward, quest, unlock or migration cannot promise a ready reunion")
                ready[String(coda.grant_flags[0])] = true
                rows = GUIDE.rows({}, ready)
                tree.check(rows[0].stage == "seen", "the committed personal marker distinguishes a heard reunion")
                var restored: Dictionary = JSON.parse_string(JSON.stringify(ready))
                tree.check(GUIDE.records({}, restored) == GUIDE.records({}, ready), "existing World JSON reconstructs the overview without a new save schema")
            tree.check(active == before, "reading return options does not mutate the accepted task or ending")
            tree.check(GUIDE.rows({}, {"ending_chosen": ending, String(quest.started_flag): "true"}).is_empty(), "a truthy string cannot invent an accepted relationship")
        # Every accepted-quest subset must expose exactly that subset of links.
        for mask in 32:
            var flags := ended.duplicate(true)
            var keys: Array[String] = []
            for index in narrative.story_data.quests.size():
                var quest: Dictionary = narrative.story_data.quests[index]
                if mask & (1 << index):
                    flags[String(quest.started_flag)] = true
                    keys.append("quest:" + String(quest.id))
            var records := GUIDE.records({}, flags)
            tree.check(records.is_empty() if keys.is_empty() else records[0].journal_source_keys == keys, "all 96 ending and acceptance subsets withhold unseen quest links")
    tree.check(GUIDE.records({}, {"quest_root_rescue_started": true}).is_empty(), "pre-ending journeys do not gain an epilogue checklist")
    var ambiguous := {"quest_root_rescue_started": true, "ending_a_done": true, "ending_b_done": true}
    tree.check(GUIDE.records({}, ambiguous).is_empty(), "ambiguous legacy endings do not invent a selected aftermath")
    ambiguous.erase("ending_b_done")
    tree.check(GUIDE.rows({}, ambiguous).size() == 1, "the canonical unique legacy ending still restores its accepted promises")
    var lantern := {"ending_chosen": "ending_b", "quest_lantern_watch_started": true}
    for invalid in [0, -1, 0.5, true, "1", INF, NAN]:
        tree.check(GUIDE.rows({"silent_order": invalid}, lantern)[0].guidance == "取得军册或黑曜证词", "malformed inventory cannot skip an unfinished return objective")
    var broken := GUIDE.catalog()
    broken.quests.root_rescue.ending_b["grant_flags"] = ["fake"]
    tree.check(not GUIDE.valid(broken), "presentation data cannot add progress side effects")
    tree.check(GUIDE.valid(GUIDE.catalog()), "caller changes cannot poison the cached read-only catalogue")

func live(tree: SceneTree, world: Node) -> void:
    var flags: Dictionary = world.story_flags.duplicate(true)
    var items: Dictionary = world.inventory_counts.duplicate(true)
    var wallet: int = world.currency_count
    var disk := FileAccess.get_file_as_bytes(world.world_save_path)
    var guide := GUIDE.records(items, flags)
    tree.check(guide.size() == 1 and GUIDE.rows(items, flags).filter(func(row): return row.id == "root_rescue" and row.stage == "seen").size() == 1, "the real rescued prisoner and saved coda appear as a confirmed optional return")
    if guide.is_empty():
        return
    var ui: Control = world.ui_shell
    ui.journal_filter = "guide"
    ui._refresh_journal()
    tree.check(ui.journal_documents.filter(func(doc): return doc.key == "guide:ending_return_contacts").size() == 1, "the production journal includes the derived return guide under its existing manual filter")
    ui._show_journal_record(guide[0])
    tree.check(ui.bag_category_label.text == "结局之后 · 可选回访" and ui.bag_description.text.contains("温室西门"), "the production reader explains optional status and the current saved destination")
    tree.check(not ui.bag_description.text.contains("npc_") and not ui.bag_description.text.contains("demo_"), "the reader contains localized places instead of internal route keys")
    tree.check(world.story_flags == flags and world.inventory_counts == items and world.currency_count == wallet, "reading the actual return guide neither grants items nor advances dialogue")
    tree.check(FileAccess.get_file_as_bytes(world.world_save_path) == disk, "reading optional returns leaves the saved ending checkpoint unchanged")
