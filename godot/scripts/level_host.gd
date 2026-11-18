extends RefCounted
## W00 stage 1 (docs/W00_SEAMLESS_RESIDENCY_PLAN.md): region-owned nodes are
## moving from direct children of the level host into its `region_root`
## container. Code that treated `get_parent()` as the level, compared a node's
## parent with the level, or looked region nodes up by name on the level goes
## through these helpers, which accept both layouts.
## A container marks itself with META pointing at its level host. Fixtures that
## parent actors to a plain stub node keep getting that stub, as before.
const META := &"level_host"


static func of(node: Node) -> Node:
	var parent := node.get_parent()
	if parent != null and parent.has_meta(META):
		return parent.get_meta(META)
	return parent


static func owns(level: Node, node: Node) -> bool:
	var parent := node.get_parent()
	if parent == null or level == null:
		return false
	# The current container only: a destination being built hidden (W00 stage 3)
	# sits in a second container that is not the level's region until handover.
	return parent == level or parent == container(level)


static func container(level: Node) -> Node:
	var root: Variant = level.get("region_root") if level != null else null
	return root if root is Node and is_instance_valid(root) else null


## Where region-owned nodes are added: the container once it exists.
static func region_parent(level: Node) -> Node:
	var root := container(level)
	return root if root != null else level


## Region container first, then the host itself (session nodes, absolute paths).
static func find(level: Node, path: NodePath) -> Node:
	var root := container(level)
	if root != null and not path.is_absolute():
		var found := root.get_node_or_null(path)
		if found != null:
			return found
	return level.get_node_or_null(path)


## The host's children with the region container expanded in its place.
static func children(level: Node) -> Array[Node]:
	var out: Array[Node] = []
	var root := container(level)
	for child in level.get_children():
		if child != root:
			out.append(child)
	if root != null:
		out.append_array(root.get_children())
	return out
