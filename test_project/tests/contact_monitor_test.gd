extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "ContactGround"
	ground.position = Vector3(0, -0.5, 0)
	var ground_shape: CollisionShape3D = CollisionShape3D.new()
	var ground_box: BoxShape3D = BoxShape3D.new()
	ground_box.size = Vector3(10, 1, 10)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	root.add_child(ground)

	var body: RigidBody3D = RigidBody3D.new()
	body.position = Vector3(0, 3, 0)
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.can_sleep = false
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.5
	body_shape.shape = sphere
	body.add_child(body_shape)
	root.add_child(body)

	await physics_frame
	await physics_frame

	# Regression guard: the count was Box3D's contact capacity, not the real count.
	var airborne: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	_check(airborne.get_contact_count() == 0, "no contacts are reported while airborne")

	for frame in 180:
		await physics_frame

	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	var count: int = state.get_contact_count()
	_check(count > 0, "resting body reports at least one contact")
	_check(count <= 8, "reported contacts respect max_contacts_reported")
	if count == 0:
		_finish()
		return

	# Godot points the normal from the collider back toward the body, so resting reports +Y.
	var normal: Vector3 = state.get_contact_local_normal(0)
	_check(normal.dot(Vector3.UP) > 0.95, "contact normal points up, away from the ground")

	var position: Vector3 = state.get_contact_local_position(0)
	_check(absf(position.y) < 0.15, "contact position sits on the ground surface")

	_check(
		state.get_contact_collider(0) == ground.get_rid(),
		"contact collider RID is the ground body",
	)
	_check(
		state.get_contact_collider_object(0) == ground,
		"contact collider object resolves to the ground node",
	)
	_check(
		state.get_contact_collider_id(0) == ground.get_instance_id(),
		"contact collider instance ID matches the ground",
	)
	_check(
		state.get_contact_impulse(0).length() > 0.0,
		"resting contact carries a nonzero impulse",
	)

	var collider_position: Vector3 = state.get_contact_collider_position(0)
	_check(
		collider_position.distance_to(position) < 0.2,
		"collider contact point is near the local contact point",
	)

	_finish()


func _finish() -> void:
	if failures == 0:
		print("RESULT: PASS - contact monitoring reports real contact data")
	else:
		print("RESULT: FAIL - ", failures, " contact monitor assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
