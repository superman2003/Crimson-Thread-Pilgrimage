extends CharacterBody2D

const MOTION := preload("res://scripts/character_ground_motion.gd")

var feet_offset: Vector2
var ignored_player: PhysicsBody2D


func setup(body_size: Vector2, clearance: float) -> void:
    # The parent Area2D still handles attacks and contact damage. Keep this
    # terrain-only body at the authored foot plane, independent of the artwork.
    name = "GroundBody"
    top_level = true
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    collision_layer = 0
    collision_mask = 1
    feet_offset = Vector2(0.0, clearance)
    MOTION.configure_floor(self)
    var collider := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = body_size
    collider.shape = rectangle
    collider.position.y = -body_size.y * 0.5
    add_child(collider)


func walk(actor: Area2D, player: PhysicsBody2D, base_speed: float, goal_speed: float, stop_x: float, limits: Vector2, delta: float) -> void:
    var feet := actor.global_position + feet_offset
    var repositioned := global_position != feet
    if repositioned:
        global_position = feet
        velocity = Vector2.ZERO
    if not is_same(player, ignored_player):
        if is_instance_valid(ignored_player):
            remove_collision_exception_with(ignored_player)
        ignored_player = player
        if player != null:
            add_collision_exception_with(player)

    # Brake before a patrol turn, chosen stop or territorial boundary.
    var left := limits.x
    var right := limits.y
    if goal_speed > 0.0:
        right = minf(right, stop_x)
    elif goal_speed < 0.0:
        left = maxf(left, stop_x)
    if goal_speed != 0.0:
        var distance := maxf(0.0, right - feet.x if goal_speed > 0.0 else feet.x - left)
        var acceleration := base_speed * MOTION.ACCELERATION
        var speed_step := acceleration * delta
        # Reserve the upcoming full step before the remaining braking distance.
        var braking_speed := sqrt(speed_step * speed_step + 2.0 * acceleration * distance) - speed_step
        goal_speed = signf(goal_speed) * minf(absf(goal_speed), braking_speed)
    velocity.x = MOTION.approach_speed(velocity.x, goal_speed, base_speed, delta)
    velocity.x = clampf(velocity.x, minf(0.0, left - feet.x) / delta, maxf(0.0, right - feet.x) / delta)
    if repositioned or not is_on_floor():
        velocity.y += MOTION.GRAVITY * delta
    move_and_slide()
    actor.global_position = global_position - feet_offset
