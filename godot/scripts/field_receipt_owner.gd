extends RefCounted
const LEDGER:=preload("res://scripts/transaction_receipt_ledger.gd")
const KEY:="field_transaction_receipts"
static func capture(level: Node) -> Dictionary:
    return {"currency":level.currency_count,"items":level.inventory_counts.duplicate(true)}
static func for_level(level: Node,create: bool=true) -> RefCounted:
    if not is_instance_valid(level) or level.is_queued_for_deletion() or level.world_state==null:return null
    var scope:=str(level.world_state.get_instance_id())+":"+String(level.world_save_path)
    var cached: Variant=level.get_meta(KEY,{})
    if cached is Dictionary and cached.get("scope")==scope and cached.get("ledger") is LEDGER:return cached.ledger
    if not create:return null
    var ledger:=LEDGER.new();level.set_meta(KEY,{"scope":scope,"ledger":ledger});return ledger
static func committed(level: Node,before: Dictionary) -> void:
    var ledger: Variant=for_level(level)
    if ledger==null:return
    ledger.record(before,capture(level),String(level.config.get("name","当前地区")))
