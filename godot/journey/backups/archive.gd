extends RefCounted
const V := preload("res://journey/core/values.gd")
const WORLD := preload("res://scripts/world_state.gd")
const MAX_BUNDLE := 33554432
const MAX_COMPONENT := 2097152
const MAX_COMPONENTS := 16
const MAX_BUNDLES := 20
var directory := "user://journey_workbench/bundles"
var error := ""
var writable := true

func _read(path: String, maximum: int) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok":false, "reason":"文件不存在。"}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > maximum:
        return {"ok":false, "reason":"文件无法读取或超出大小上限。"}
    var bytes := file.get_buffer(file.get_length())
    file.close()
    if not utf8_valid(bytes):
        return {"ok":false, "reason":"记录包含无效UTF8字节，原文件保留。"}
    var raw := bytes.get_string_from_utf8()
    if raw.to_utf8_buffer() != bytes:
        return {"ok":false, "reason":"文件不符合UTF8文本要求。"}
    var hash := FileAccess.get_sha256(path)
    if hash != raw.sha256_text():
        return {"ok":false, "reason":"文件读取期间发生变化。"}
    return {"ok":true, "raw":raw, "sha256":hash, "bytes":bytes.size()}

func sources(store: RefCounted, primary: String) -> Array:
    var result := []
    if FileAccess.file_exists(primary):
        result.append({"id":"primary", "path":primary, "maximum":WORLD.MAX_BYTES})
    var prefix := String(store.scope) + "_"
    if not DirAccess.dir_exists_absolute(String(store.directory)):
        return result
    var auxiliaries := 0
    for name in DirAccess.get_files_at(String(store.directory)):
        if not name.begins_with(prefix) or not name.ends_with(".json"):
            continue
        var id := name.trim_prefix(prefix).trim_suffix(".json")
        if not id.is_valid_identifier():
            continue
        result.append({"id":id, "path":String(store.directory).path_join(name), "maximum":MAX_COMPONENT})
        auxiliaries += 1
        if auxiliaries > MAX_COMPONENTS:
            return []
    result.sort_custom(func(a: Dictionary, b: Dictionary):return String(a.id) < String(b.id))
    return result

func quote(store: RefCounted, primary: String) -> Dictionary:
    error = ""
    var entries := sources(store, primary)
    if entries.is_empty():
        return {"ok":false, "reason":"没有可导出的记录，或辅助模块数量超出上限。"}
    var rows := []
    var total := 0
    for entry in entries:
        var file := FileAccess.open(String(entry.path), FileAccess.READ)
        if file == null or file.get_length() > int(entry.maximum):
            return {"ok":false, "reason":"记录无法读取或单份大小超限。"}
        var bytes := file.get_length()
        file.close()
        total += bytes
        rows.append({"id":entry.id, "path":entry.path, "bytes":bytes, "sha256":FileAccess.get_sha256(String(entry.path))})
    if total > MAX_BUNDLE / 2:
        return {"ok":false, "reason":"原始记录合计超出16MiB预算。"}
    return {"ok":true, "sources":rows, "bytes":total, "scope":store.scope, "fingerprint":V.fingerprint(rows)}

func build(store: RefCounted, primary: String, title: String, expected: String) -> Dictionary:
    var current := quote(store, primary)
    if not current.get("ok", false):
        return current
    if String(current.fingerprint) != expected:
        return {"ok":false, "reason":"记录已变化，请重新核对导出范围。"}
    var components := []
    var primary_record := {}
    for entry in current.sources:
        var loaded := _read(String(entry.path), WORLD.MAX_BYTES if entry.id == "primary" else MAX_COMPONENT)
        if not loaded.get("ok", false):
            return loaded
        if loaded.sha256 != entry.sha256:
            return {"ok":false, "reason":"导出过程中记录身份变化，请重试。"}
        var parsed: Variant = V.parse_json(String(loaded.raw))
        if not parsed is Dictionary:
            return {"ok":false, "reason":"记录JSON无法解析，原文件保留。"}
        if entry.id == "primary":
            var world := WORLD.new()
            if not world.read(primary):
                return {"ok":false, "reason":"主档未通过正式读取校验；不生成可误认的备份。"}
            primary_record = {"raw":loaded.raw, "sha256":loaded.sha256, "summary":summarize_world(world.data)}
        else:
            if parsed.get("version") != 1 or parsed.get("scope") != store.scope or parsed.get("feature") != entry.id or not parsed.get("data") is Dictionary:
                return {"ok":false, "reason":"辅助记录的身份或版本无法复核。"}
            var component_record := {"id":entry.id, "raw":loaded.raw, "sha256":loaded.sha256}
            if not _component_valid(component_record, store.scope):
                return {"ok":false, "reason":"辅助组件内容超过安全边界，未生成导出包。"}
            components.append(component_record)
    var final := quote(store, primary)
    if not final.get("ok", false) or final.fingerprint != current.fingerprint:
        return {"ok":false, "reason":"导出完成前记录再次变化，请重新核对。"}
    var payload := {"version":1, "scope":store.scope, "name":V.text(title, 60), "created":int(Time.get_unix_time_from_system()), "primary":primary_record, "components":components}
    var encoded := JSON.stringify(payload)
    var raw := JSON.stringify({"format":"pilgrimage_journey_bundle", "version":1, "sha256":encoded.sha256_text(), "payload":encoded})
    if raw.to_utf8_buffer().size() > MAX_BUNDLE:
        return {"ok":false, "reason":"导出包编码后超过32MiB上限。"}
    return {"ok":true, "raw":raw, "payload":payload, "sha256":raw.sha256_text(), "reason":"导出包已在内存中完整复核。"}

static func summarize_world(data: Dictionary) -> Dictionary:
    var regions := 0
    var rooms := 0
    var bosses := 0
    for region in data.get("regions", {}).values():
        if not region is Dictionary:
            continue
        regions += 1
        for visited in region.get("visited_rooms", {}).values():
            if visited is bool and visited:
                rooms += 1
        if region.get("boss_defeated") is bool and region.get("boss_defeated", false):
            bosses += 1
    var items := 0
    for count in data.get("inventory_counts", {}).values():
        if V.held(count):
            items += 1
    return {"regions":regions, "rooms":rooms, "bosses":bosses, "items":items, "currency":int(data.get("currency", 0)), "hp":float(data.get("hp", 0)), "energy":float(data.get("energy", 0))}

func install(bundle: Dictionary) -> Dictionary:
    if not writable or not bundle.get("ok", false):
        return {"ok":false, "reason":"导出目录暂不可写。"}
    if list_bundles().size() >= MAX_BUNDLES:
        return {"ok":false, "reason":"已达到20份导出包上限，请先整理已有包。"}
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        return {"ok":false, "reason":"无法建立导出包目录。"}
    var name := "journey_" + str(Time.get_ticks_usec()) + ".json"
    var path := directory.path_join(name)
    var outcome := verified_write(path, String(bundle.raw))
    if not outcome.get("ok", false):
        return outcome
    return {"ok":true, "path":path, "sha256":FileAccess.get_sha256(path), "reason":"已生成 " + ProjectSettings.globalize_path(path)}

func verified_write(path: String, raw: String) -> Dictionary:
    if not writable or raw.to_utf8_buffer().size() > MAX_BUNDLE:
        return {"ok":false, "reason":"内容过大或当前不能写入。"}
    var temporary := path + ".pending_" + str(Time.get_ticks_usec())
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return {"ok":false, "reason":"无法建立候选导出文件。"}
    file.store_string(raw)
    file.flush()
    var status := file.get_error()
    file.close()
    if status != OK or FileAccess.get_file_as_string(temporary) != raw:
        DirAccess.remove_absolute(temporary)
        return {"ok":false, "reason":"候选导出字节校验失败。"}
    if DirAccess.rename_absolute(temporary, path) != OK:
        DirAccess.remove_absolute(temporary)
        return {"ok":false, "reason":"无法安装导出文件。"}
    return {"ok":true, "path":path}

func decode(raw: String) -> Dictionary:
    if raw.to_utf8_buffer().size() > MAX_BUNDLE:
        return {"ok":false, "reason":"导出包超出读取预算。"}
    var envelope: Variant = V.parse_json(raw)
    if not envelope is Dictionary or envelope.get("format") != "pilgrimage_journey_bundle" or envelope.get("version") != 1:
        return {"ok":false, "reason":"无法识别导出包格式。"}
    if not envelope.get("payload") is String or not envelope.get("sha256") is String:
        return {"ok":false, "reason":"导出包缺少内容或校验值。"}
    if String(envelope.payload).sha256_text() != envelope.sha256:
        return {"ok":false, "reason":"导出包校验不一致。"}
    var payload: Variant = V.parse_json(envelope.payload)
    if not payload is Dictionary or payload.get("version") != 1 or not payload.get("scope") is String:
        return {"ok":false, "reason":"导出包内容版本无效。"}
    if not payload.get("name") is String or payload.name.length() > 60 or not V.count(payload.get("created"), 9999999999):
        return {"ok":false, "reason":"导出包名称或时间无效。"}
    if not payload.get("primary") is Dictionary or not payload.get("components") is Array or payload.components.size() > MAX_COMPONENTS:
        return {"ok":false, "reason":"导出包组件无效或过多。"}
    var ids := {}
    for component in payload.components:
        if not component is Dictionary or not component.get("id") is String or not component.id.is_valid_identifier() or ids.has(component.id):
            return {"ok":false, "reason":"辅助组件身份重复或无效。"}
        if not _component_valid(component, String(payload.scope)):
            return {"ok":false, "reason":"辅助组件校验不一致。"}
        ids[component.id] = true
    if not payload.primary.is_empty():
        if not payload.primary.get("raw") is String or String(payload.primary.raw).to_utf8_buffer().size() > WORLD.MAX_BYTES or String(payload.primary.raw).sha256_text() != payload.primary.get("sha256"):
            return {"ok":false, "reason":"主档副本校验不一致。"}
        var schema := primary_schema(String(payload.primary.raw))
        if not schema.get("ok", false):
            return schema
        payload.primary["summary"] = schema.summary
    return {"ok":true, "payload":payload, "reason":"导出包格式与组件校验一致。"}

func _component_valid(component: Dictionary, scope: String) -> bool:
    if not component.get("raw") is String or component.raw.to_utf8_buffer().size() > MAX_COMPONENT:
        return false
    if String(component.raw).sha256_text() != component.get("sha256"):
        return false
    var record: Variant = V.parse_json(component.raw)
    return record is Dictionary and record.get("version") == 1 and record.get("scope") == scope and record.get("feature") == component.id and record.get("data") is Dictionary and V.json_safe(record.data, 0, [V.MAX_ITEMS])

func component(bundle: Dictionary, id: String) -> Dictionary:
    if not bundle.get("ok", false):
        return {}
    for value in bundle.payload.components:
        if value.id == id:
            var envelope: Dictionary = V.parse_json(value.raw)
            return envelope.data.duplicate(true)
    return {}

func list_bundles() -> Array:
    var rows := []
    if not DirAccess.dir_exists_absolute(directory):
        return rows
    for name in DirAccess.get_files_at(directory):
        if not name.begins_with("journey_") or not name.ends_with(".json"):
            continue
        var path := directory.path_join(name)
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            continue
        var bytes := file.get_length()
        file.close()
        rows.append({"path":path, "name":name, "bytes":bytes, "modified":FileAccess.get_modified_time(path)})
        if rows.size() > MAX_BUNDLES:
            break
    rows.sort_custom(func(a: Dictionary, b: Dictionary):return int(a.modified) > int(b.modified))
    return rows

func open(path: String) -> Dictionary:
    if path.get_base_dir() != directory or not path.get_file().begins_with("journey_") or not path.ends_with(".json"):
        return {"ok":false, "reason":"只读取导出目录中的工作台导出包。"}
    var read := _read(path, MAX_BUNDLE)
    return decode(read.raw) if read.get("ok", false) else read

func remove(path: String, expected: String) -> Dictionary:
    if path.get_base_dir() != directory or not path.get_file().begins_with("journey_") or not path.ends_with(".json"):
        return {"ok":false, "reason":"导出包路径无效。"}
    if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected:
        return {"ok":false, "reason":"导出包已经变化，未删除文件。"}
    if DirAccess.remove_absolute(path) != OK:
        return {"ok":false, "reason":"无法删除导出包。"}
    return {"ok":true, "reason":"已删除核对过的导出包，主档与辅助记录不变。"}

static func utf8_valid(bytes: PackedByteArray) -> bool:
    var index := 0
    while index < bytes.size():
        var first := int(bytes[index])
        if first < 128:
            index += 1
            continue
        var length := 0
        var minimum_second := 128
        var maximum_second := 191
        if first >= 194 and first <= 223:
            length = 2
        elif first >= 224 and first <= 239:
            length = 3
            if first == 224:
                minimum_second = 160
            elif first == 237:
                maximum_second = 159
        elif first >= 240 and first <= 244:
            length = 4
            if first == 240:
                minimum_second = 144
            elif first == 244:
                maximum_second = 143
        else:
            return false
        if index + length > bytes.size():
            return false
        var second := int(bytes[index + 1])
        if second < minimum_second or second > maximum_second:
            return false
        for offset in range(2, length):
            var continuation := int(bytes[index + offset])
            if continuation < 128 or continuation > 191:
                return false
        index += length
    return true

static func primary_schema(raw: String) -> Dictionary:
    var parsed: Variant = V.parse_json(raw)
    if not parsed is Dictionary or not V.json_safe(parsed, 0, [V.MAX_ITEMS]):
        return {"ok":false, "reason":"主档副本的JSON结构无效或超出校验预算。"}
    var migrated: Variant = WORLD._migrate(parsed)
    if not WORLD._valid_data(migrated):
        return {"ok":false, "reason":"主档副本未通过当前正式存档字段校验。"}
    return {"ok":true, "summary":summarize_world(migrated)}

static func compare_summaries(before: Dictionary, after: Dictionary) -> Array:
    var result := []
    var fields := {"regions":"地区记录", "rooms":"已访问房间", "bosses":"守门者", "items":"物品种类", "currency":"碎钱", "hp":"生命", "energy":"绯线"}
    for key in fields:
        var a: Variant = before.get(key, 0)
        var b: Variant = after.get(key, 0)
        if V.number(a) and V.number(b):
            result.append({"name":fields[key], "before":float(a), "after":float(b), "difference":float(b) - float(a)})
    return result
