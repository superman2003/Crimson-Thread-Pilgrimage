extends RefCounted
## A suspended consumer has no catch-up debt. Reappearance gets one fresh read.
const INTERVAL:=0.5
var elapsed:=0.0
var active:=false
func reset() -> void:
    elapsed=0.0;active=false
func observed() -> void:
    # An explicit open/refresh just supplied fresh data to the same consumers.
    elapsed=0.0;active=true
func advance(delta: float,window_visible: bool,hud_needed: bool) -> bool:
    if not window_visible and not hud_needed:reset();return false
    if not is_finite(delta) or delta<0:return false
    if not active:observed();return true
    elapsed+=minf(delta,INTERVAL)
    if elapsed<INTERVAL:return false
    elapsed=fmod(elapsed,INTERVAL)
    return true
