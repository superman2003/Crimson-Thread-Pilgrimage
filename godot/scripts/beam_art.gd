extends RefCounted
## Segmented authored pixels only; collision, wall clipping and clocks stay outside.
const ATLAS := preload("res://assets/vfx/beams/beams.png")
const FAMILIES := ["erase","gate","steam","thread"]
const BODY := 32.0
const AXIS := 64.0
const FPS := 12.0
const MAX_MIDDLES := 64
const LEGACY := {"pipe_thrower":"steam","valve_crawler":"steam","erasure_bailiff":"erase","sunken_hammer_smith":"thread","silent_crown_core":"gate"}
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/beams/manifest.json"))

static func family_for(skin: String,owner_node: Node = null) -> String:
    var family := skin
    if skin == "thorn":
        var kind := String(owner_node.get("kind")) if is_instance_valid(owner_node) and "kind" in owner_node else ""
        family=String(LEGACY.get(kind,""))
    return family if FAMILIES.has(family) else ""

static func middle_frame(seconds: float) -> int:
    return 1+int(maxf(0,seconds)*FPS)%2

static func atlas_rect(family: String,part: int) -> Rect2:
    if not data.get("sources",{}).has(family) or part < 0 or part > 3:return Rect2()
    var rect: Array=data.sources[family].frames[part].atlas_rect
    return Rect2(rect[0],rect[1],rect[2],rect[3])

static func segments(family: String,length: float,radius: float,seconds: float) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    if not FAMILIES.has(family) or not is_finite(length) or not is_finite(radius) or length<=0 or radius<=0:return result
    var scale:=radius*2/BODY
    var start:=atlas_rect(family,0)
    var middle:=atlas_rect(family,middle_frame(seconds))
    var finish:=atlas_rect(family,3)
    if start.size==Vector2.ZERO or middle.size==Vector2.ZERO or finish.size==Vector2.ZERO:return result
    var start_width:=start.size.x*scale
    var end_width:=finish.size.x*scale
    if start_width+end_width>length:
        var squeeze:=length/(start_width+end_width)
        start_width*=squeeze
        end_width=length-start_width
    var height:=start.size.y*scale
    result.append({"source":start,"destination":Rect2(0,-AXIS*scale,start_width,height)})
    var span:=maxf(0,length-start_width-end_width)
    var count:=clampi(ceili(span/(middle.size.x*scale)),0,MAX_MIDDLES)
    # Full tiles keep the shared collar at every join, including the last one.
    # Distribute the middle span evenly instead of cutting a tile mid-pattern.
    for index in range(count):
        var x:=start_width+span*index/count
        var end:=start_width+span*(index+1)/count
        result.append({"source":middle,"destination":Rect2(x,-AXIS*scale,end-x,height)})
    result.append({"source":finish,"destination":Rect2(length-end_width,-AXIS*scale,end_width,height)})
    return result

static func draw_frame(host: Node2D,family: String,length: float,radius: float,heading: Vector2,seconds: float) -> bool:
    if not FAMILIES.has(family) or not is_finite(length) or not is_finite(radius) or radius<=0:return false
    if length<=0:return true
    var pieces:=segments(family,length,radius,seconds)
    if pieces.is_empty():return false
    var axis:=heading.normalized() if heading.length_squared()>.0001 else Vector2.RIGHT
    host.draw_set_transform(Vector2.ZERO,axis.angle(),Vector2.ONE)
    for piece in pieces:
        host.draw_texture_rect_region(ATLAS,piece.destination,piece.source,Color.WHITE)
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
    return true
