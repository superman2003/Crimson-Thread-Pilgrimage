extends SceneTree
## Verifies bounded resumable deep-copy semantics and caller/cache isolation.
const JOB := preload("res://scripts/world_variant_copy_job.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var original := {"nested": [{"values": [1, 2, {"leaf": "safe"}]}], "empty": [], "dict": {}}
	var job = JOB.new()
	job.begin(original)
	var batches := 0
	var max_edges := 0
	var edges := 0
	while not job.done:
		edges = job.step(2)
		max_edges = maxi(max_edges, edges)
		batches += 1
	_check(edges <= 2, "copy step respects edge cap")
	_check(batches < 100, "copy task makes bounded forward progress")
	var copied: Dictionary = job.result
	_check(copied == original, "copy result equals source after completion")
	copied.nested[0].values[2].leaf = "changed"
	_check(original.nested[0].values[2].leaf == "safe", "deep copy has independent nested containers")
	_check(max_edges <= 2 and batches > 1, "copy yields across bounded edge batches")
	_check(copied.empty.is_empty() and copied.dict.is_empty(), "empty containers are preserved")
	var scalar = JOB.new()
	scalar.begin("scalar")
	_check(scalar.done and scalar.result == "scalar", "scalar root copies without a stack")
	if failures.is_empty():
		print("WORLD_VARIANT_COPY PASS: %d checks; batches=%d edges=%d" % [checks, batches, job.edge_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
