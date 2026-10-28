class_name T06ReleaseAudit
extends RefCounted

func inspect(version: String, save_version: int, required: Array[String]) -> Dictionary:
    var missing: Array[String] = []
    for item in required:
        if item.is_empty(): missing.append(item)
    return {"ready": not version.is_empty() and save_version > 0 and missing.is_empty(), "version": version, "save_version": save_version, "missing": missing}
