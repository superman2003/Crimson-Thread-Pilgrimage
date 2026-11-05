extends RefCounted
const SOURCES := preload("res://scripts/testimony_sources.gd")

func run(tree: SceneTree, world: Node) -> void:
    var data := SOURCES.catalog()
    tree.check(SOURCES.valid(data), "all six provenance dossiers satisfy their public text contract")
    if data.is_empty():
        return
    tree.check(data.sources.size() == 6, "every original testimony has one source dossier")
    for mask in 64:
        var inventory := {}
        for index in SOURCES.IDS.size():
            if mask & (1 << index):
                inventory[SOURCES.IDS[index]] = 1
        var before := inventory.duplicate(true)
        for id in SOURCES.IDS:
            var result := SOURCES.for_evidence(id, inventory)
            tree.check(result.is_empty() == not inventory.has(id), "all 64 possession sets withhold uncollected source identities")
            if result.is_empty():
                continue
            tree.check(not result.has("cross_checks"), "public dossiers do not expose locked comparison conditions")
            var expected := 0
            for check in data.sources[id].cross_checks:
                var ready := true
                for required in check.evidence_all:
                    ready = ready and inventory.has(required)
                if ready:
                    expected += 1
                tree.check(result.comparisons.has(check.text) == ready, "a comparison requires actual possession of every independent source")
            tree.check(result.comparisons.size() == expected, "comparisons contain no extra or duplicated interpretations")
            tree.check("\n".join(SOURCES.appendix(id, inventory)).contains("仍不能据此断言"), "each visible source preserves the boundary between fact and inference")
        tree.check(inventory == before, "source queries never grant or consume evidence")

    for invalid in [-1, 0, 0.5, true, "1", INF, NAN, {}, [], 1000001]:
        tree.check(SOURCES.for_evidence("testimony_03", {"testimony_03": invalid}).is_empty(), "invalid possession values cannot reveal a source")
    tree.check(not SOURCES.for_evidence("testimony_03", {"testimony_03": 1.0}).is_empty(), "JSON numeric counts retain access after reload")
    tree.check(SOURCES.for_evidence("unknown", {"unknown": 1}).is_empty(), "unknown evidence has no authored authority")
    var copy := SOURCES.for_evidence("testimony_03", {"testimony_03": 1})
    copy.observations.clear()
    tree.check(not SOURCES.for_evidence("testimony_03", {"testimony_03": 1}).observations.is_empty(), "public rows cannot mutate the shared authored source")
    var broken := data.duplicate(true)
    broken.sources.testimony_01.cross_checks[0].evidence_all = ["testimony_01", "testimony_01"]
    tree.check(not SOURCES.valid(broken), "a repeated copy of one source is not independent corroboration")
    broken = data.duplicate(true)
    broken.sources.testimony_01.cross_checks[0].evidence_all.append("unwritten_proof")
    tree.check(not SOURCES.valid(broken), "unknown source identifiers fail the authoring contract")

    var inventory_before: Dictionary = world.inventory_counts.duplicate(true)
    var flags_before: Dictionary = world.story_flags.duplicate(true)
    var ui: Node = world.ui_shell
    world.inventory_counts = {"testimony_03": 1}
    var evidence: Dictionary = world.world_narrative.evaluate_evidence(world.inventory_counts, world.story_flags)
    var entry: Dictionary = evidence.entries[0].merged({"record_kind": "evidence"})
    ui._show_journal_record(entry)
    var detail: String = ui.bag_description.text
    tree.check(detail.contains("证词出处 · 封存书堆") and detail.contains("可确认的实物痕迹"), "the production journal displays the actual artifact and where it was found")
    tree.check(detail.contains("仍不能据此断言") and not detail.contains(String(data.sources.testimony_03.cross_checks[0].text)), "the real reader preserves uncertainty before independent corroboration")
    tree.check(not detail.contains(data.sources.testimony_01.medium), "one collected source cannot disclose another artifact's dossier")
    world.inventory_counts.testimony_01 = 1
    ui._show_journal_record(entry)
    detail = ui.bag_description.text
    tree.check(detail.contains(data.sources.testimony_03.cross_checks[0].text), "a newly acquired independent source updates the same journal entry")
    var presentation: Dictionary = ui._journal_presentation(entry)
    tree.check(presentation.text == detail, "journal search indexes the same provenance text that the reader sees")
    world.inventory_counts.testimony_03 = 0
    world.story_flags.evidence_known_testimony_03 = true
    world.story_flags.evidence_read_testimony_03 = true
    ui._show_journal_record(entry)
    tree.check(not ui.bag_description.text.contains("证词出处"), "knowledge flags and a stale displayed row cannot replace actual possession")
    world.inventory_counts = inventory_before
    world.story_flags = flags_before
    tree.check(world.inventory_counts == inventory_before and world.story_flags == flags_before, "reading sources changes no quest, ending or reward state")
