extends "res://scripts/preference_file_transaction.gd"
## Compare the displaced original while the existing per-path lock is held.
## Base installation restores that original if this guard refuses replacement.
var expected_hash:="missing"
var installed_hash:=""

func _place(source: String, target: String) -> int:
    var original:=target+BACKUP_SUFFIX
    var observed:=FileAccess.get_sha256(original) if FileAccess.file_exists(original) else "missing"
    if observed!=expected_hash:return ERR_BUSY
    var candidate:=FileAccess.get_sha256(source)
    if candidate.is_empty():return ERR_CANT_OPEN
    var result:=super._place(source,target)
    if result==OK:installed_hash=candidate
    return result
