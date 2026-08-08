extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_gravity_replace()
	await _test_gravity_combine()
	await _test_linear_damp_replace()
	await _test_angular_damp_replace()

	if failures == 0:
		print("RESULT: PASS - area gravity and damping overrides are honored")
	else:
		print("RESULT: FAIL - ", failures, " area override assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _test_gravity_replace() -> void:
	var area: Area3D = _make_area(Vector3(0, 0, 0), Vector3(20, 20, 20))
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity = 0.0

	var inside: RigidBody3D = _make_body(Vector3(0, 0, 0))
	var outside: RigidBody3D = _make_body(Vector3(100, 0, 0))

	for frame in 120:
		await physics_frame

	_check(
		absf(inside.linear_velocity.y) < 0.5,
		"REPLACE gravity of zero leaves the body floating",
	)
	_check(outside.global_position.y < -3.0, "a body outside the area still falls")

	area.queue_free()
	inside.queue_free()
	outside.queue_free()
	await physics_frame


func _test_gravity_combine() -> void:
	var area: Area3D = _make_area(Vector3(0, 0, 0), Vector3(20, 20, 20))
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
	area.gravity_direction = Vector3.UP
	area.gravity = 9.8

	var body: RigidBody3D = _make_body(Vector3(0, 0, 0))

	for frame in 120:
		await physics_frame

	_check(
		absf(body.global_position.y) < 0.5,
		"COMBINE gravity cancelling world gravity holds the body in place",
	)

	area.queue_free()
	body.queue_free()
	await physics_frame


func _test_linear_damp_replace() -> void:
	var area: Area3D = _make_area(Vector3(0, 0, 0), Vector3(200, 20, 20))
	area.linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.linear_damp = 5.0

	var damped: RigidBody3D = _make_body(Vector3(0, 0, 0))
	damped.gravity_scale = 0.0
	var free_body: RigidBody3D = _make_body(Vector3(0, 0, 500))
	free_body.gravity_scale = 0.0

	await physics_frame
	damped.apply_central_impulse(Vector3(5, 0, 0))
	free_body.apply_central_impulse(Vector3(5, 0, 0))

	for frame in 60:
		await physics_frame

	var damped_speed: float = damped.linear_velocity.length()
	var free_speed: float = free_body.linear_velocity.length()
	_check(
		free_speed > 0.0 and damped_speed < free_speed * 0.4,
		"REPLACE linear damp slows the body inside the area",
	)

	area.queue_free()
	damped.queue_free()
	free_body.queue_free()
	await physics_frame


func _test_angular_damp_replace() -> void:
	var area: Area3D = _make_area(Vector3(0, 0, 0), Vector3(200, 20, 20))
	area.angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.angular_damp = 5.0

	var damped: RigidBody3D = _make_body(Vector3(0, 0, 0))
	damped.gravity_scale = 0.0
	var free_body: RigidBody3D = _make_body(Vector3(0, 0, 500))
	free_body.gravity_scale = 0.0

	await physics_frame
	damped.apply_torque_impulse(Vector3(0, 3, 0))
	free_body.apply_torque_impulse(Vector3(0, 3, 0))

	for frame in 60:
		await physics_frame

	var damped_speed: float = damped.angular_velocity.length()
	var free_speed: float = free_body.angular_velocity.length()
	_check(
		free_speed > 0.0 and damped_speed < free_speed * 0.4,
		"REPLACE angular damp slows the body inside the area",
	)

	area.queue_free()
	damped.queue_free()
	free_body.queue_free()
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
