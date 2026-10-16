extends RefCounted
## Independent lifetime owner for a detached world-travel coroutine.
# Passage observers consume this synchronously at the publishing boundary.
signal completed
var serial := 0
var cancelled := false
var finished := false
var succeeded := false

func cancel() -> void:
	cancelled = true
