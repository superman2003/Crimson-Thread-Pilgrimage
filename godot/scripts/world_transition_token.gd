extends RefCounted
## Independent lifetime owner for a detached world-travel coroutine.
var serial := 0
var cancelled := false
var finished := false
var succeeded := false

func cancel() -> void:
	cancelled = true
