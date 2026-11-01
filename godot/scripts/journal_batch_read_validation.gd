extends SceneTree
const CATALOG := preload("res://scripts/journal_catalog.gd")
const DIALOG := preload("res://scripts/journal_batch_read.gd")
var checks:=0
var failures:=0
var writes:=0
class Owner extends Control:
    var journal_catalog: RefCounted
    var documents: Array=[]
    var available:=true
    var results: Array=[]
    func _journal_batch_available() -> bool:return available
    func _journal_batch_documents() -> Array:return documents
    func _journal_preference_result(value: Dictionary) -> void:results.append(value)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func doc(catalog: RefCounted,id: String,text: String="正文") -> Dictionary:return catalog.document(id,"标题"+id,"证据",text)
func run() -> void:
    var model:=CATALOG.new();model.path="user://journal_batch_contract.json";model.configure("batch_slot")
    model.writer=func(_data):writes+=1;return OK
    var docs: Array=[doc(model,"a"),doc(model,"b"),doc(model,"c")]
    var snapshot:=docs.duplicate(true)
    var hidden:=doc(model,"not_in_filter")
    var quote: Dictionary=model.batch_quote(docs)
    check(quote.ok and quote.count==3 and writes==0,"quoting disclosed documents does not write or mark anything")
    var applied: Dictionary=model.mark_read_batch(docs,quote.fingerprint)
    check(applied.ok and applied.persisted and applied.changed_count==3 and writes==1,"one confirmed batch uses one durable writer call")
    check(docs.all(func(value):return model.is_read(value)) and not model.is_read(hidden),"only explicitly selected documents become read")
    check(docs==snapshot and model.profiles[model.scope].stars.is_empty(),"batch reading changes no story documents or favorites")
    check(not model.batch_quote(docs).ok,"already read results need no duplicate batch")
    for invalid in [[],[docs[0],docs[0]],[{}],[true],[{"key":"bad","fingerprint":"bad"}]]:
        check(not model.batch_quote(invalid).ok,"invalid or duplicate selection cannot form a batch")
    var many: Array=[]
    for i in 257:many.append(doc(model,"many"+str(i)))
    check(not model.batch_quote(many).ok,"a batch cannot exceed reading-history capacity")
    var target: Array=[doc(model,"pending")]
    quote=model.batch_quote(target);model.toggle_star("a")
    check(not model.mark_read_batch(target,quote.fingerprint).ok and not model.is_read(target[0]),"preference changes invalidate the confirmation snapshot")
    quote=model.batch_quote(target);var changed: Array=[doc(model,"pending","更新正文")]
    check(not model.mark_read_batch(changed,quote.fingerprint).ok,"changed public content requires review again")
    quote=model.batch_quote(target);model.configure("other_slot")
    check(not model.mark_read_batch(target,quote.fingerprint).ok,"a confirmation cannot cross save scopes")
    model.configure("batch_slot");quote=model.batch_quote(target)
    model.writer=func(_data):return ERR_CANT_CREATE
    applied=model.mark_read_batch(target,quote.fingerprint)
    check(applied.ok and not applied.persisted and model.is_read(target[0]) and model.dirty,"failed persistence follows existing retryable session-reading policy")
    model.writer=Callable();check(model.flush().persisted,"normal retry persists the confirmed latest state")
    var restored:=CATALOG.new();restored.path=model.path;restored.configure("batch_slot")
    check(restored.is_read(target[0]) and restored.is_read(docs[1]),"actual disk restart restores batch preferences")
    var owner:=Owner.new();owner.journal_catalog=model;owner.documents=[doc(model,"native_one"),doc(model,"native_two")];root.add_child(owner)
    var popup:=DIALOG.new();owner.add_child(popup)
    check(popup.open_for(owner).ok and popup.visible and popup.dialog_text.contains("2条"),"native confirmation describes the current unread selection")
    popup.hide();check(not model.is_read(owner.documents[0]),"cancelling confirmation leaves reading state unchanged")
    popup.open_for(owner);owner.documents=[doc(model,"native_three")];popup.apply()
    check(popup.visible and not model.is_read(owner.documents[0]) and popup.dialog_text.contains("重新核对"),"changing the filter refreshes confirmation without applying it")
    popup.apply();check(not popup.visible and model.is_read(owner.documents[0]) and owner.results.size()==1,"second explicit confirmation applies the reviewed filter")
    owner.documents=[doc(model,"native_four")];popup.open_for(owner);owner.available=false;popup.apply()
    check(not popup.visible and not model.is_read(owner.documents[0]),"leaving the journal invalidates its native callback")
    owner.available=true;popup.open_for(owner);model.configure("different_live_slot");popup.apply()
    check(not popup.visible and not model.is_read(owner.documents[0]),"native confirmation closes on a slot change")
    model.configure("batch_slot");popup.open_for(owner);model.mark_read(owner.documents[0],true);popup.apply()
    check(popup.get_ok_button().disabled,"a now-fully-read selection disables redundant confirmation")
    popup.hide();owner.documents=[doc(model,"native_five")];popup.open_for(owner)
    check(not popup.get_ok_button().disabled,"a later valid request re-enables confirmation")
    popup.reparent(root);owner.free();popup.apply()
    check(not popup.visible,"retired owner callback is ignored without retaining the old UI")
    popup.free()
    print("JOURNAL_BATCH_READ checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
