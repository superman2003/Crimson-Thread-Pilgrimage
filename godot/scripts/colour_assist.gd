extends RefCounted
## Full-screen colour-vision assist. Nothing exists in the tree while it is
## off, so the default picture and its cost are exactly as before.
const MODES := {"protan": 1, "deutan": 2}
const NODE := "ColourAssist"

static func apply(root: Node, mode: String) -> void:
    var layer:=root.get_node_or_null(NODE) as CanvasLayer
    if not MODES.has(mode):
        if layer!=null:layer.queue_free();layer.name="ColourAssistRetired"
        return
    if layer==null:
        layer=CanvasLayer.new();layer.name=NODE;layer.layer=120;layer.process_mode=Node.PROCESS_MODE_ALWAYS
        var rect:=ColorRect.new();rect.name="Filter";rect.set_anchors_preset(Control.PRESET_FULL_RECT)
        rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
        var material:=ShaderMaterial.new();material.shader=preload("res://shaders/colour_assist.gdshader")
        rect.material=material;layer.add_child(rect)
        # Autoloads call this during their own _ready; the root is still busy.
        if root.is_node_ready():root.add_child(layer)
        else:root.add_child.call_deferred(layer)
    (layer.get_node("Filter").material as ShaderMaterial).set_shader_parameter("mode",int(MODES[mode]))
