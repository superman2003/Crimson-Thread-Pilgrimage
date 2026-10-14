extends SceneTree
## Preserve the exact editor build's engine and bundled-library notices.
func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected one license output path")
        quit(1)
        return
    var file := FileAccess.open(args[0], FileAccess.WRITE)
    if file == null:
        push_error("Cannot write engine license notices")
        quit(1)
        return
    file.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n")
    file.store_string(Engine.get_license_text() + "\n\nBundled components and copyright holders\n\n")
    file.store_string(JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\nBundled license texts\n\n")
    var licenses := Engine.get_license_info()
    var names := licenses.keys()
    names.sort()
    for name in names:
        file.store_string(String(name) + "\n" + String(licenses[name]) + "\n\n")
    file.flush()
    var status := file.get_error()
    file.close()
    if status != OK:
        push_error("Failed to flush engine license notices")
        quit(1)
        return
    print("ENGINE_LICENSES_PASS")
    quit(0)
