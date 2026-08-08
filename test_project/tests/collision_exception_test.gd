extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_baseline_separation()
	await _test_exception_allows_overlap()
	await _test_removal_restores_collision()
	await _test_free_with_live_exception()

	if failures == 0:
		print("RESULT: PASS - per-pair collision exceptions are honored")
	else:
		print("RESULT: FAIL - ", failures, " collision exception assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _test_baseline_separation() -> void:
	var a: RigidBody3D = _make_body(Vector3(0, 0, 0))
	var b: RigidBody3D = _make_body(Vector3(0, 0.2, 0))

	for frame in 90:
		await physics_frame

	_check(
		a.global_position.distance_to(b.global_position) > 0.5,
		"overlapping bodies push apart without an exception",
	)

	a.queue_free()
	b.queue_free()
	await physics_frame


func _test_exception_allows_overlap() -> void:
	var a: RigidBody3D = _make_body(Vector3(0, 0, 0))
	var b: RigidBody3D = _make_body(Vector3(0, 0.2, 0))
	a.add_collision_exception_with(b)

	for frame in 90:
		await physics_frame

	_check(
		a.global_position.distance_to(b.global_position) < 0.5,
		"excepted bodies interpenetrate instead of separating",
	)

	# Godot records the exception only on the body it was requested from, even though the
	# collision itself is disabled in both directions.
	var from_a: Array[PhysicsBody3D] = a.get_collision_exceptions()
	_check(from_a.size() == 1 and from_a[0] == b, "the exception is listed on the requesting body")
	_check(b.get_collision_exceptions().is_empty(), "the other body does not list it")

	a.queue_free()
	b.queue_free()
	await physics_frame


func _test_removal_restores_collision() -> void:
	var a: RigidBody3D = _make_body(Vector3(0, 0, 0))
	var b: RigidBody3D = _make_body(Vector3(0, 0.2, 0))
	a.add_collision_exception_with(b)

	for frame in 30:
		await physics_frame

	a.remove_collision_exception_with(b)
	_check(a.get_collision_exceptions().is_empty(), "removing clears the exception list")

	for frame in 90:
		await physics_frame

	_check(
		a.global_position.distance_to(b.global_position) > 0.5,
		"bodies collide again once the exception is removed",
	)

	a.queue_free()
	b.queue_free()
	await physics_frame


func _test_free_with_live_exception() -> void:
	# Free each side in turn: the body holding the list, then the body it points at.
	var a: RigidBody3D = _make_body(Vector3(0, 0, 0))
	var b: RigidBody3D = _make_body(Vector3(0, 0.2, 0))
	a.add_collision_exception_with(b)

	await physics_frame
	a.queue_free()

	for frame in 10:
		await physics_frame

	_check(is_instance_valid(b), "freeing the listing body does not crash")

	var c: RigidBody3D = _make_body(Vector3(5, 0, 0))
	var d: RigidBody3D = _make_body(Vector3(5, 0.2, 0))
	c.add_collision_exception_with(d)

	await physics_frame
	d.queue_free()

	for frame in 10:
		await physics_frame

	_check(is_instance_valid(c), "freeing the referenced body does not crash")

	b.queue_free()
	c.queue_free()
	await physics_frame


func _make_body(position: Vector3) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.position = position
	body.gravity_scale = 0.0
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
