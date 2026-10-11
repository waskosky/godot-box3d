extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _box(size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision


func _run() -> void:
	var wall := StaticBody3D.new()
	wall.position = Vector3(60, 2, 0)
	wall.add_child(_box(Vector3(0.025, 8, 8)))
	root.add_child(wall)
	var bullet := RigidBody3D.new()
	bullet.position = Vector3(58, 2, 0)
	bullet.gravity_scale = 0.0
	bullet.continuous_cd = true
	var round_collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	round_collision.shape = sphere
	bullet.add_child(round_collision)
	root.add_child(bullet)
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(80, -0.5, 0)
	floor_body.add_child(_box(Vector3(8, 1, 8)))
	root.add_child(floor_body)
	var sleeper := RigidBody3D.new()
	sleeper.position = Vector3(80, 2, 0)
	sleeper.add_child(_box(Vector3.ONE))
	root.add_child(sleeper)
	var impulse_body := RigidBody3D.new()
	impulse_body.position = Vector3(100, 10, 0)
	impulse_body.rotation.z = PI / 2.0
	impulse_body.gravity_scale = 0.0
	impulse_body.mass = 2.0
	impulse_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	impulse_body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	impulse_body.linear_damp = 0.0
	impulse_body.angular_damp = 0.0
	impulse_body.add_child(_box(Vector3(2, 1, 0.5)))
	root.add_child(impulse_body)
	await physics_frame
	await physics_frame
	bullet.linear_velocity = Vector3(600, 0, 0)
	impulse_body.apply_impulse(Vector3(0, 0, 1), Vector3(1, 0, 0))
	var velocity: Vector3 = PhysicsServer3D.body_get_state(impulse_body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
	var angular: Vector3 = PhysicsServer3D.body_get_state(impulse_body.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
	# Rotation about Z maps local X inertia onto world Y. The global offset
	# crossed with the impulse is -Y, not the body's rotated local direction.
	var expected_spin := -1.0 / (2.0 * (1.0 + 0.25) / 12.0)
	if velocity.distance_to(Vector3(0, 0, 0.5)) > 0.01 or absf(angular.y - expected_spin) > 0.05 or absf(angular.x) + absf(angular.z) > 0.01:
		_fail("off-center impulse or rotated inertia was incorrect: v=%s omega=%s" % [velocity, angular])
	for frame in 420:
		await physics_frame
		if not bullet.position.is_finite() or bullet.position.x > 60.15:
			_fail("CCD body crossed 25 mm geometry at 600 m/s")
			quit(1)
			return
		if not sleeper.position.is_finite() or not impulse_body.position.is_finite() or not impulse_body.angular_velocity.is_finite():
			_fail("sustained simulation produced non-finite state")
			quit(1)
			return
	if absf(sleeper.position.y - 0.5) > 0.03 or not sleeper.sleeping:
		_fail("resting body did not settle and sleep")
	sleeper.apply_central_impulse(Vector3(0.4, 1, 0))
	await physics_frame
	await physics_frame
	if sleeper.sleeping or sleeper.linear_velocity.x < 0.1:
		_fail("an impulse did not wake a sleeping body")
	# Churn actual collision fixtures, not only script-side resource handles.
	for batch in 5:
		var bodies: Array[RigidBody3D] = []
		for index in 16:
			var body := RigidBody3D.new()
			body.position = Vector3(120 + index, 3 + batch, 0)
			body.add_child(_box(Vector3.ONE))
			root.add_child(body)
			bodies.append(body)
		await physics_frame
		for body in bodies:
			body.queue_free()
		await process_frame
		await physics_frame
	if failures == 0:
		print("RESULT: PASS - thin-wall CCD, rotated off-center impulse, sleep/wake and sustained finite simulation/fixture churn")
	quit(1 if failures else 0)


func _fail(message: String) -> void:
	failures += 1
	print("RESULT: FAIL - ", message)
