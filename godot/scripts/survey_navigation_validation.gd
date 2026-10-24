extends RefCounted
## Real World map viewport + normal input dispatch. Fixed tick calls verify pan speed.
func key(code: Key, pressed: bool = true) -> void:
    var event := InputEventKey.new()
    event.physical_keycode=code
    event.pressed=pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func button(code: JoyButton) -> void:
    var event := InputEventJoypadButton.new()
    event.button_index=code
    event.device=5
    event.pressed=true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func axis(code: JoyAxis, value: float, device: int = 5) -> void:
    var event := InputEventJoypadMotion.new()
    event.axis=code
    event.axis_value=value
    event.device=device
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func run(tree: SceneTree, world: Node, check: Callable) -> void:
    var camera: Control=world.survey_map_view
    camera.set_process(false)
    world._process(0.0)
    camera.reset()
    var flags: Dictionary=world.story_flags.duplicate(true)
    var body: Vector2=world.player.global_position
    key(KEY_PAGEUP)
    key(KEY_PAGEUP,false)
    check.call(is_equal_approx(camera.zoom,1.25),"Keyboard page-up zooms the actual atlas")
    key(KEY_D)
    camera._process(0.1)
    var start: Vector2=camera.content.position
    check.call(camera.keyboard_pan.x==1.0 and start.x < -camera.size.x*0.125,"Held D pans actual atlas presentation")
    key(KEY_D,false)
    camera._process(0.1)
    check.call(camera.content.position==start,"Keyboard release stops map pan")
    key(KEY_HOME)
    key(KEY_HOME,false)
    check.call(camera.zoom==1.0 and camera.content.position==Vector2.ZERO,"Home restores full map without mouse")
    button(JOY_BUTTON_RIGHT_SHOULDER)
    check.call(is_equal_approx(camera.zoom,1.25),"Controller RB zooms actual map")
    axis(JOY_AXIS_LEFT_X,0.18)
    check.call(camera.stick_pan==Vector2.ZERO,"Resting stick drift does not move map")
    axis(JOY_AXIS_LEFT_X,1.0)
    var before: Vector2=camera.content.position
    camera._process(0.1)
    check.call(camera.content.position.x < before.x,"Controller left stick pans atlas")
    Input.emit_signal("joy_connection_changed",6,false)
    check.call(camera.stick_pan.x>0,"Another controller disconnect does not cancel active pan")
    Input.emit_signal("joy_connection_changed",5,false)
    check.call(camera.stick_pan==Vector2.ZERO,"Active controller disconnect stops pan immediately")
    axis(JOY_AXIS_LEFT_X,1.0)
    axis(JOY_AXIS_LEFT_Y,1.0)
    before=camera.content.position
    camera._process(0.01)
    check.call(camera.content.position.distance_to(before)<=camera.PAN_SPEED*0.01+0.01,"Diagonal pan speed is bounded")
    button(JOY_BUTTON_Y)
    world._process(0.0)
    check.call(camera.zoom==1.0 and camera.stick_pan==Vector2.ZERO and world.active_overlay=="map","Y resets zoom without colliding with the global map toggle")
    button(JOY_BUTTON_RIGHT_SHOULDER)
    button(JOY_BUTTON_LEFT_SHOULDER)
    check.call(camera.zoom==1.0,"LB reverses RB zoom")
    camera.magnify(2.0)
    key(KEY_D)
    camera.dragging=true
    camera.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check.call(camera.keyboard_pan==Vector2.ZERO and not camera.dragging,"Focus loss cancels held map movement and drag")
    key(KEY_D,false)
    key(KEY_S)
    world._close_overlays()
    check.call(camera.keyboard_pan==Vector2.ZERO,"Closing actual map clears held keys")
    key(KEY_PAGEUP)
    key(KEY_PAGEUP,false)
    check.call(camera.zoom==2.0,"Hidden map ignores navigation shortcuts")
    world._toggle_map()
    camera._process(0.1)
    check.call(camera.keyboard_pan==Vector2.ZERO,"Reopened map cannot replay a held movement")
    key(KEY_S,false)
    axis(JOY_AXIS_LEFT_X,1.0)
    camera.set_view(99)
    check.call(camera.zoom==1.0 and camera.stick_pan==Vector2.ZERO,"Changing map view clears pan and resets frame")
    for factor in [NAN,INF,0.0,-1.0]: camera.magnify(factor)
    check.call(camera.zoom==1.0 and camera.content.position.is_finite(),"Invalid magnification cannot corrupt map transform")
    check.call(not camera.center_on(Vector2(NAN,0)) and not camera.center_on(Vector2(-1,0)) and not camera.center_on(camera.size*0.5,NAN) and camera.zoom==1.0,"invalid or off-paper locate target leaves the map frame intact")
    camera.keyboard_pan=Vector2.RIGHT
    camera.dragging=true
    check.call(camera.center_on(camera.size*0.5) and camera.zoom==2.0 and camera.keyboard_pan==Vector2.ZERO and not camera.dragging,"centering a target stops held pan and drag before framing it")
    for rate in [30,60,120]:
        camera.reset()
        camera.magnify(4.0)
        key(KEY_D)
        before=camera.content.position
        for tick in rate: camera._process(1.0/rate)
        check.call(is_equal_approx(before.x-camera.content.position.x,camera.PAN_SPEED),"Map pan uses elapsed seconds at %d Hz" % rate)
        key(KEY_D,false)
    check.call(world.story_flags==flags and world.player.global_position==body,"Map navigation never charts rooms or moves the player")
    axis(JOY_AXIS_LEFT_X,0.0)
    axis(JOY_AXIS_LEFT_Y,0.0)
    camera.reset()
    world.world_map_view=true
    world._refresh_map_overlay()
    camera.set_process(true)
    await tree.process_frame
