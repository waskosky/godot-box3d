extends SceneTree

class MassProbeBody:
	extends RigidBody3D

	var sample_count: int = 0
	var inverse_mass: float = 0.0
	var inverse_inertia: Vector3
	var center_of_mass_local: Vector3

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		sample_count += 1
		inverse_mass = state.get_inverse_mass()
		inverse_inertia = state.get_inverse_inertia()
		center_of_mass_local = state.get_center_of_mass_local()


var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ProjectSettings.get_setting("physics/3d/physics_engine", "") == "Box3D Physics (Extension)", "test project requests the Box3D backend")
	_check(ClassDB.class_exists(&"Box3DPhysicsServer3D"), "Box3D extension is loaded")
	if failures > 0:
		quit(1)
		return

	await _test_mass_refresh_after_shape_change()
	await _test_global_impulse_offset()
	await _test_rotated_custom_center_force()
	await _clear_scene()

	if failures == 0:
		print("RESULT: PASS - body mass and off-center force checks passed")
	else:
		print("RESULT: FAIL - ", failures, " body dynamics assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _clear_scene() -> void:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await physics_frame
	await physics_frame


func _make_box_collision(size: Vector3 = Vector3.ONE, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.position = offset
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision


func _test_mass_refresh_after_shape_change() -> void:
	await _clear_scene()

	var body := MassProbeBody.new()
	body.name = "MassProbe"
	body.mass = 4.0
	body.gravity_scale = 0.0
	body.custom_integrator = true
	body.can_sleep = false
	body.add_child(_make_box_collision())
	root.add_child(body)
	for frame in 4:
		await physics_frame

	var initial_inertia := body.inverse_inertia
	var initial_samples := body.sample_count
	body.add_child(_make_box_collision(Vector3.ONE, Vector3(2, 0, 0)))
	for frame in 4:
		await physics_frame

	_check(initial_samples > 0 and body.sample_count > initial_samples, "direct body state samples mass properties before and after a shape change")
	_check(absf(body.inverse_mass - 0.25) < 0.01, "explicit body mass survives shape-driven mass refresh")
	_check(body.center_of_mass_local.x > 0.5, "automatic center of mass refreshes after adding an offset shape")
	_check(body.inverse_inertia.distance_to(initial_inertia) > 0.01, "automatic inertia refreshes after changing the shape set")


func _make_free_body(name: String, position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = name
	body.position = position
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.can_sleep = false
	body.add_child(_make_box_collision())
	root.add_child(body)
	return body


func _test_global_impulse_offset() -> void:
	await _clear_scene()

	var body := _make_free_body("ImpulseOffsetBody", Vector3(50, 0, 0))
	body.rotation.z = PI * 0.5
	await physics_frame
	await physics_frame

	body.apply_impulse(Vector3(0, 2, 0), Vector3(1, 0, 0))
	for frame in 4:
		await physics_frame

	_check(body.angular_velocity.z > 0.1, "off-center impulse uses a global offset even when the body is rotated")


func _test_rotated_custom_center_force() -> void:
	await _clear_scene()

	var body := _make_free_body("CustomCenterForceBody", Vector3(60, 0, 0))
	body.rotation.z = PI * 0.5
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.25, 0, 0)
	await physics_frame
	await physics_frame

	body.apply_force(Vector3(60, 0, 0), Vector3.ZERO)
	for frame in 4:
		await physics_frame

	_check(body.angular_velocity.z > 0.05, "off-center force rotates a custom center of mass into world orientation")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
