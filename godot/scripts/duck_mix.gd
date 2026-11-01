extends RefCounted
## Independent envelopes combine by strongest attenuation, never by addition.
const LIMIT := 8
var layers: Dictionary = {}

func level() -> float:
    var result := 0.0
    for layer in layers.values():result = minf(result,float(layer.db))
    return result

func admit(id: int, target: float) -> Dictionary:
    if id <= 0 or layers.has(id) or not is_finite(target) or target >= 0.0:return {"ok":false}
    target = clampf(target,-24.0,0.0)
    var evicted := 0
    var start := 0.0
    if layers.size() >= LIMIT:
        for key in layers:
            if evicted == 0 or float(layers[key].target) > float(layers[evicted].target):evicted = int(key)
        if target >= float(layers[evicted].target):return {"ok":false}
        start = float(layers[evicted].db)
        layers.erase(evicted)
    layers[id] = {"target":target,"db":start}
    return {"ok":true,"evicted":evicted,"start":start,"target":target}

func set_level(id: int, value: float) -> float:
    if layers.has(id) and is_finite(value):layers[id].db = clampf(value,float(layers[id].target),0.0)
    return level()

func remove(id: int) -> float:
    layers.erase(id)
    return level()
