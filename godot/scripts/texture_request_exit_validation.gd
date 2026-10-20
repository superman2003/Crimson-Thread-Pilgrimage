extends SceneTree
## Quit with actual pending shared image requests and no World host or poller.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const PATHS := [
    "res://assets/sprites/flat_maps/moss_cavern/background.png",
    "res://assets/sprites/flat_maps/rain_foundry/background.png"]
var owners: Array = []
var checks := 0
var failures := 0

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func run() -> void:
    for path in PATHS:ART.request_texture(path)
    owners = ART.texture_requests.values()
    check(owners.size() == 2, "standalone tool exits with two actual unclaimed texture workers")
    # Connect after production admission so this observes the completed cleanup.
    root.tree_exiting.connect(check_exit, CONNECT_ONE_SHOT)
    quit()

func check_exit() -> void:
    check(ART.texture_requests.is_empty(), "SceneTree exit reaps the shared requests without a World shutdown")
    check(owners.all(func(owner):return owner._thread == null), "standalone exit joins every unclaimed Thread")
    check(PATHS.all(func(path):return ART.textures.has(path)), "exit preserves the successfully decoded immutable textures")
    owners.clear()
    print("TEXTURE_REQUEST_EXIT checks=%d failures=%d" % [checks, failures])
