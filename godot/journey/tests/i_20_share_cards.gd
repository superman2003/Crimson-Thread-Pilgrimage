extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/share_cards/model.gd")
const FEATURE := preload("res://journey/features/i_share_cards.gd")


func run() -> void:
    label = "I20_SHARE_CARDS"
    var context := field_fixture("i20_share_cards")
    await exercise(context, M, FEATURE, "share_cards", "include_counts")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.note = "secret=abc token=def C:\\Users\\name\\save.json person@example.com https://example.com/?token=abc"
    payload.include_note = false
    var public := M.body(payload)
    check(
        not public.has("note") and not public.has("location") and not public.has("inventory"),
        "default share whitelist excludes private and optional fields"
    )
    payload.include_note = true
    var card := M.body(payload)
    check(
        (
            not String(card.note).contains("secret=abc")
            and not String(card.note).contains("person@example.com")
        ),
        "selected note filters common credential and email formats"
    )
    var encoded := M.encode(card)
    check(encoded.ok and M.decode(encoded.code).ok, "UTF-8 canonical share code round trips")
    var corrupted := String(encoded.code).left(6) + "0" + String(encoded.code).substr(7)
    if corrupted == encoded.code:
        corrupted = String(encoded.code).left(6) + "1" + String(encoded.code).substr(7)
    check(not M.decode(corrupted).ok, "tampered checksum cannot be accepted")
    check(
        (
            not M.valid_utf8(PackedByteArray([0xc0, 0xaf]))
            and not M.valid_utf8(PackedByteArray([0xed, 0xa0, 0x80]))
        ),
        "overlong and surrogate UTF-8 rejected"
    )
    var forbidden := card.duplicate(true)
    forbidden["save_path"] = "user://private"
    check(not M.valid_body(forbidden), "unknown private field is outside share schema")

    var exhausted := RECORDS.fresh()
    exhausted.sequence = 100000000
    var incoming := RECORDS.append(RECORDS.fresh(), "independent observation", payload)
    var rejected := RECORDS.merge(exhausted, incoming)
    check(
        not rejected.ok and exhausted.records.is_empty(),
        "exhausted record sequence rejects import atomically before append"
    )
    var partial := RECORDS.append(RECORDS.fresh(), "existing", payload)
    partial.sequence = 99999999
    var two := RECORDS.append(incoming, "another observation", payload)
    var result := RECORDS.merge(partial, two)
    check(
        not result.ok and partial.records.size() == 1 and partial.sequence == 99999999,
        "multi-record import rolls back candidate when second sequence would exceed cap"
    )
