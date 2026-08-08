extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_priority()
	await _test_point_gravity_center()
	await _test_gravity_direction_length()

	if failures == 0:
		print("RESULT: PASS - area priority and point gravity match Godot")
	else:
		print("RESULT: FAIL - ", failures, " area priority assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _test_priority() -> void:
	var outer: Area3D = _make_area(Vector3.ZERO, Vector3(30, 30, 30))
	outer.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	outer.gravity = 0.0
	outer.priority = 0

	var inner: Area3D = _make_area(Vector3.ZERO, Vector3(20, 20, 20))
	inner.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	inner.gravity_direction = Vector3.UP
	inner.gravity = 20.0
	inner.priority = 10

	var body: RigidBody3D = _make_body(Vector3.ZERO)

	for frame in 60:
		await physics_frame

	_check(body.linear_velocity.y > 1.0, "the higher priority area wins")

	# Swapping priorities must hand control to the zero-gravity area instead.
	inner.priority = 0
	outer.priority = 10
	body.linear_velocity = Vector3.ZERO

	for frame in 60:
		await physics_frame

	_check(
		absf(body.linear_velocity.y) < 0.5,
		"swapping priority at runtime changes which area wins",
	)

	outer.queue_free()
	inner.queue_free()
	body.queue_free()
	await physics_frame


func _test_point_gravity_center() -> void:
	# The area sits at x=10 but its point center is offset +5 on Y in area space, so the
	# body must be pulled up toward (10, 5, 0) rather than toward the area origin.
	var area: Area3D = _make_area(Vector3(10, 0, 0), Vector3(30, 30, 30))
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity_point = true
	area.gravity_point_center = Vector3(0, 5, 0)
	area.gravity = 20.0

	var body: RigidBody3D = _make_body(Vector3(10, 0, 0))

	for frame in 60:
		await physics_frame

	_check(body.linear_velocity.y > 1.0, "point gravity pulls toward the offset center")

	area.queue_free()
	body.queue_free()
	await physics_frame


func _test_gravity_direction_length() -> void:
	# Godot does not normalize gravity_direction, so a length of 2 doubles the strength.
	var area: Area3D = _make_area(Vector3.ZERO, Vector3(30, 30, 30))
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity_direction = Vector3(0, 2, 0)
	area.gravity = 5.0

	var body: RigidBody3D = _make_body(Vector3.ZERO)

	for frame in 30:
		await physics_frame

	# 2 * 5 = 10 m/s^2 upward over 0.5s is about 5 m/s, versus 2.5 if normalized.
	_check(body.linear_velocity.y > 3.5, "gravity direction length scales the strength")

	area.queue_free()
	body.queue_free()
	await physics_frame


func _make_area(position: Vector3, size: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.position = position
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	area.add_child(collision)
	root.add_child(area)
	return area


func _make_body(position: Vector3) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.position = position
	body.can_sleep = false
	var collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.5
	collision.shape = sphere
	body.add_child(collision)
	root.add_child(body)
	return body


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
