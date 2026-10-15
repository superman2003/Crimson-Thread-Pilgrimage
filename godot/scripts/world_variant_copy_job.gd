extends RefCounted
## Explicit-stack deep copy for cached JSON Variants. Each edge is visited once,
## so callers can yield between bounded steps without a recursive duplicate(true).
var source: Variant
var result: Variant
var stack: Array[Dictionary] = []
var edge_count := 0
var done := false

func begin(value: Variant) -> void:
	source = value
	result = _empty_container(value)
	stack.clear()
	edge_count = 0
	done = false
	if _is_container(value):
		_push(value, result)
	else:
		done = true

func step(max_edges: int = 512) -> int:
	var visited := 0
	while not stack.is_empty() and visited < max_edges:
		var frame: Dictionary = stack[stack.size() - 1]
		var src: Variant = frame.source
		var dst: Variant = frame.destination
		if frame.index >= frame.length:
			stack.pop_back()
			continue
		var key: Variant = frame.keys[frame.index] if src is Dictionary else frame.index
		frame.index += 1
		stack[stack.size() - 1] = frame
		var child: Variant = src[key] if src is Dictionary else src[int(key)]
		if _is_container(child):
			var copy: Variant = _empty_container(child)
			if dst is Dictionary:
				dst[key] = copy
			else:
				dst.append(copy)
			_push(child, copy)
		else:
			if dst is Dictionary:
				dst[key] = child
			else:
				dst.append(child)
		visited += 1
		edge_count += 1
	done = stack.is_empty()
	return visited

func _push(src: Variant, dst: Variant) -> void:
	stack.append({"source": src, "destination": dst,
		"keys": src.keys() if src is Dictionary else [], "length": src.size(), "index": 0})

func _is_container(value: Variant) -> bool:
	return value is Dictionary or value is Array

func _empty_container(value: Variant) -> Variant:
	if value is Dictionary:
		return {}
	if value is Array:
		return []
	return value
