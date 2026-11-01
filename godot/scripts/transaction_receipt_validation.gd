extends SceneTree
const LEDGER:=preload("res://scripts/transaction_receipt_ledger.gd")
const OWNER:=preload("res://scripts/field_receipt_owner.gd")
class Level extends Node:
    var world_state: RefCounted=RefCounted.new()
    var world_save_path:="user://slot_a.json"
    var currency_count:=20
    var inventory_counts:={"copper":3}
    var config:={"name":"已到地区"}
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func wallet(money: Variant,items: Dictionary={}) -> Dictionary:return {"currency":money,"items":items}
func run() -> void:
    var model:=LEDGER.new();var before:=wallet(20,{"copper":3});var after:=wallet(12,{"copper":1,"powder":1})
    var original:=var_to_str([before,after])
    check(model.record(before,after,"已到地区"),"confirmed changed wallet creates one receipt")
    var receipt: Dictionary=model.report().rows[0]
    check(receipt.currency_before==20 and receipt.currency_after==12 and receipt.currency_delta==-8,"currency receipt keeps before after and signed delta")
    check(receipt.items.size()==2 and receipt.items[0].delta==-2 and receipt.items[1].delta==1,"mixed material spending and receipt stay separate without unit summation")
    check(var_to_str([before,after])==original,"recording cannot alter authoritative wallet inputs")
    var report:=model.report();report.rows[0].items.clear()
    check(model.report().rows[0].items.size()==2,"published report is detached from private record state")
    check(not model.record(after,after,"已到地区") and model.entries.size()==1,"unchanged resource settlement does not make a phantom receipt")
    var rows:=LEDGER.browse(model.report(),func(id: String):return "碎铜" if id=="copper" else "灰粉")
    check(rows.size()==1 and rows[0].spent and rows[0].received,"mixed receipt participates in both truthful direction filters")
    check(LEDGER.browse(model.report(),Callable(),"",1).size()==1 and LEDGER.browse(model.report(),Callable(),"",2).size()==1,"spending and income scopes retain mixed transaction")
    check(LEDGER.describe(rows[0]).contains("20 → 12") and LEDGER.describe(rows[0]).contains("碎铜：3 → 1"),"readable statement uses exact accepted balances")
    check(LEDGER.browse(model.report(),func(id: String):return "碎铜" if id=="copper" else "灰粉","已到 碎铜").size()==1,"public name and region tokens intersect")
    check(LEDGER.browse(model.report(),Callable(),"copper").is_empty(),"private item ID is not a public search term")
    check(LEDGER.browse(model.report(),func(id: String):return id)[0].items[0].name=="已结算物品","raw ID name fallback remains undisclosed")
    var revision: int=model.generation
    check(not model.clear(revision-1).ok and model.entries.size()==1,"stale clear cannot remove unseen latest receipt")
    check(model.record(wallet(1),wallet(2),"已到地区"),"later successful settlement advances revision")
    check(not model.clear(revision).ok and model.entries.size()==2,"new settlement invalidates a pending clear quote")
    check(model.clear(model.generation).ok and model.entries.is_empty(),"explicit current revision clears only local record state")
    check(model.next_sequence==3,"clearing cannot recycle old record identities")
    for index in LEDGER.LIMIT+3:model.record(wallet(index),wallet(index+1),"已到地区")
    check(model.entries.size()==LEDGER.LIMIT and model.dropped==3,"bounded session ledger reports every evicted older entry")
    check(model.entries[0].sequence>model.entries[-1].sequence,"newest sequence remains first")
    var preserved:=var_to_str(model.entries)
    check(not model.record(wallet(true),wallet(3),"地区") and var_to_str(model.entries)==preserved,"bad currency type cannot replace valid older receipts")
    check(not model.problem.is_empty(),"unreadable committed change is explicit rather than partial or fabricated")
    check(not model.record(wallet(3,{"bad":1.5}),wallet(2),"地区"),"fractional inventory is not rounded into a receipt")
    check(not model.record(wallet(-1),wallet(2),"地区"),"negative wallet is rejected")
    var large: Dictionary={}
    for index in LEDGER.MAX_CHANGES+1:large["item_"+str(index)]=1
    check(not model.record(wallet(0),wallet(0,large),"地区") and var_to_str(model.entries)==preserved,"over-limit differences do not produce truncated complete statements")
    var first:=Level.new();var second:=Level.new();root.add_child(first);root.add_child(second)
    check(OWNER.for_level(first,false)==null,"reader can observe absence without creating an owner ledger")
    var owner: Variant=OWNER.for_level(first)
    check(owner==OWNER.for_level(first) and owner!=OWNER.for_level(second),"different runtime owners cannot share session receipts")
    var captured:=OWNER.capture(first);first.currency_count=12;first.inventory_counts={"copper":1}
    OWNER.committed(first,captured)
    check(owner.report().rows.size()==1 and owner.report().rows[0].currency_delta==-8,"owner publishes exact captured pre-commit versus accepted current wallet")
    first.world_save_path="user://slot_b.json"
    check(OWNER.for_level(first)!=owner and OWNER.for_level(first).report().rows.is_empty(),"slot identity changes detach old session ledger")
    var previous: Variant=OWNER.for_level(first);first.world_state=RefCounted.new()
    check(OWNER.for_level(first)!=previous,"new world state identity cannot inherit another journey's receipts")
    first.queue_free();second.queue_free();await process_frame
    print("TRANSACTION_RECEIPTS checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
