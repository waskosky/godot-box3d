extends SceneTree

var failures: int = 0
var body_enter_count: int = 0
var area_enter_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_detach_body_clears_override()
	await _test_shape_disable_clears_override()
	await _test_free_body_during_area_callback()
	await _test_free_area_during_area_callback()

	if failures == 0:
		print("RESULT: PASS - area overlap lifecycle survives detach and callback frees")
	else:
		print("RESULT: FAIL - ", failures, " area lifecycle assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _test_detach_body_clears_override() -> void:
	var area: Area3D = _make_area(Vector3.ZERO)
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity = 0.0
	var body: RigidBody3D = _make_body(Vector3.ZERO)

	for frame in 12:
		await physics_frame
	_check(absf(body.linear_velocity.y) < 0.5, "an overlapping body receives the area override")

	PhysicsServer3D.body_set_space(body.get_rid(), RID())
	PhysicsServer3D.body_set_space(body.get_rid(), root.world_3d.space)
	body.linear_velocity = Vector3.ZERO
	body.global_position = Vector3(100, 0, 0)

	for frame in 15:
		await physics_frame
	_check(body.linear_velocity.y < -1.0, "detach and reattach cannot retain a stale area override")

	body.queue_free()
	area.queue_free()
	await physics_frame


func _test_shape_disable_clears_override() -> void:
	var area: Area3D = _make_area(Vector3.ZERO)
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity = 0.0
	var body: RigidBody3D = _make_body(Vector3.ZERO)
	for frame in 12:
		await physics_frame
	_check(absf(body.linear_velocity.y) < 0.5, "a body starts with the area override before shape removal")

	var collision: CollisionShape3D = area.get_child(0)
	body.linear_velocity = Vector3.ZERO
	collision.disabled = true

	for frame in 15:
		await physics_frame
	_check(body.linear_velocity.y < -1.0, "disabling an area shape cannot retain a stale override")

	body.queue_free()
	area.queue_free()
	await physics_frame


func _test_free_body_during_area_callback() -> void:
	var area: Area3D = _make_area(Vector3.ZERO)
	await physics_frame
	body_enter_count = 0
	area.body_entered.connect(_on_body_entered_and_free)
	var first: RigidBody3D = _make_body(Vector3.ZERO)
	var second: RigidBody3D = _make_body(Vector3(0.5, 0, 0))

	for frame in 8:
		await physics_frame
	_check(body_enter_count >= 1, "body callbacks can immediately free an overlapping body safely")
	_check(not is_instance_valid(first) and not is_instance_valid(second), "callback-freed bodies leave no live instances")

	area.queue_free()
	await physics_frame


func _test_free_area_during_area_callback() -> void:
	var monitor: Area3D = _make_area(Vector3.ZERO)
	monitor.monitorable = true
	await physics_frame
	area_enter_count = 0
	monitor.area_entered.connect(_on_area_entered_and_free)
	var visitor: Area3D = _make_area(Vector3.ZERO)
	visitor.monitorable = true

	for frame in 8:
		await physics_frame
	_check(area_enter_count >= 1, "area callbacks can immediately free an overlapping area safely")
	_check(not is_instance_valid(visitor), "callback-freed area leaves no live instance")

	monitor.queue_free()
	await physics_frame


func _on_body_entered_and_free(body: Node3D) -> void:
	body_enter_count += 1
	body.free()


func _on_area_entered_and_free(area: Area3D) -> void:
	area_enter_count += 1
	area.free()


func _make_area(position: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.position = position
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	collision.shape = box
	area.add_child(collision)
	root.add_child(area)
	return area


func _make_body(position: Vector3) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.position = position
	body.gravity_scale = 1.0
	body.can_sleep = false
	var collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.3
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
