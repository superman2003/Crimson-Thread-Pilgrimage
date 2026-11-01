extends RefCounted
const ROUTES:=preload("res://scripts/world_routes.gd")
const MODEL:=preload("res://scripts/known_wish_manifest.gd")
const MAX_FILE:=4194304
## Read only regions already present in this journey's visited-region storage.
static func read(level: Node) -> Dictionary:
    if not is_instance_valid(level) or level.world_loading or level.world_state==null:return {"ok":false,"reason":"旅途仍在准备，请稍后重新读取。"}
    if not ROUTES.cache_is_current():return {"ok":false,"reason":"地区目录正在更新，请稍后重新读取。"}
    var saved: Variant=level.world_state.data.get("regions",{})
    if not saved is Dictionary:return {"ok":false,"reason":"已到地区记录无效。"}
    var known: Array=saved.keys()
    if not known.has(String(level.config.id)):known.append(String(level.config.id))
    if known.size()>8:return {"ok":false,"reason":"地区记录超过读取上限，未生成部分清单。"}
    var configs: Array=[]
    for id in known:
        if not id is String:continue
        var path:=ROUTES.cached_config_path(id)
        if path.is_empty():continue # Unknown legacy keys reveal no region data.
        if id==String(level.config.id):configs.append(level.config);continue
        var file:=FileAccess.open(path,FileAccess.READ)
        if file==null or file.get_length()>MAX_FILE:return {"ok":false,"reason":"已到地区资料暂不可读取，清单未更新。"}
        var parser:=JSON.new();var result:=parser.parse(file.get_as_text());file.close()
        if result!=OK or not parser.data is Dictionary or parser.data.get("id")!=id:return {"ok":false,"reason":"已到地区资料无效，清单未更新。"}
        configs.append(parser.data)
    return MODEL.collect(configs,level.inventory_counts,level.story_flags,func(item: String):return level._item_display_name(item))
