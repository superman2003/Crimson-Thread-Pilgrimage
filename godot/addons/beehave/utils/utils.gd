@tool


## Editor scripts are parsed before the first filesystem import. Decode the
## bundled SVG source when an editor control is instantiated, without requiring
## an existing .import/.ctex cache or preloading a texture while parsing scripts.
static func load_editor_icon(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("Beehave: failed to decode editor icon: " + path)
		return null
	return ImageTexture.create_from_image(image)


static func get_plugin() -> EditorPlugin:
	var tree: SceneTree = Engine.get_main_loop()
	return tree.get_root().get_child(0).get_node_or_null("BeehavePlugin")


static func get_editor_scale() -> float:
	var plugin := get_plugin()
	if plugin:
		return plugin.get_editor_interface().get_editor_scale()
	return 1.0


static func get_frames() -> RefCounted:
	var plugin := get_plugin()
	if plugin:
		return plugin.frames
	push_error("Can't find Beehave Plugin")
	return null
