extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_hinge_joint()
	await _test_pin_joint()
	await _test_slider_joint()
	await _clear_scene()

	if failures == 0:
		print("RESULT: PASS - supported joint checks passed")
	else:
		print("RESULT: FAIL - ", failures, " supported joint assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _clear_scene() -> void:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await physics_frame
	await physics_frame


func _make_box_collision(size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision


func _make_anchor(name: String) -> StaticBody3D:
	var anchor := StaticBody3D.new()
	anchor.name = name
	anchor.add_child(_make_box_collision(Vector3(0.2, 0.2, 0.2)))
	root.add_child(anchor)
	return anchor


func _make_body(name: String, position: Vector3, size: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = name
	body.position = position
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.can_sleep = false
	body.add_child(_make_box_collision(size))
	root.add_child(body)
	return body


func _connect_joint(joint: Joint3D, body_a: PhysicsBody3D, body_b: PhysicsBody3D) -> void:
	joint.node_a = NodePath("../" + String(body_a.name))
	joint.node_b = NodePath("../" + String(body_b.name))
	root.add_child(joint)


func _test_hinge_joint() -> void:
	await _clear_scene()

	var anchor := _make_anchor("HingeAnchor")
	var door := _make_body("HingeDoor", Vector3(1, 0, 0), Vector3(2, 2, 0.1))
	var hinge := HingeJoint3D.new()
	hinge.name = "Hinge"
	_connect_joint(hinge, anchor, door)
	await physics_frame
	await physics_frame

	door.apply_torque_impulse(Vector3(0, 0, 3.0))
	var max_rotation: float = 0.0
	for frame in 90:
		await physics_frame
		max_rotation = maxf(max_rotation, absf(door.rotation.z))

	var distance_from_anchor := door.global_position.distance_to(anchor.global_position)
	_check(max_rotation > 0.05 and distance_from_anchor < 1.5, "HingeJoint3D constrains a rotating body around its anchor")


func _test_pin_joint() -> void:
	await _clear_scene()

	var anchor := _make_anchor("PinAnchor")
	var body := _make_body("PinnedBody", Vector3(1, 0, 0), Vector3(0.5, 0.5, 0.5))
	var pin := PinJoint3D.new()
	pin.name = "Pin"
	_connect_joint(pin, anchor, body)
	await physics_frame
	await physics_frame

	body.apply_central_impulse(Vector3(0, 3, 0))
	var max_y: float = 0.0
	var max_distance: float = 0.0
	for frame in 90:
		await physics_frame
		max_y = maxf(max_y, absf(body.global_position.y))
		max_distance = maxf(max_distance, body.global_position.distance_to(anchor.global_position))

	_check(max_y > 0.05 and max_distance < 1.5, "PinJoint3D allows rotation while keeping its anchor points together")


func _test_slider_joint() -> void:
	await _clear_scene()

	var anchor := _make_anchor("SliderAnchor")
	var body := _make_body("SliderBody", Vector3.ZERO, Vector3(0.5, 0.5, 0.5))
	var slider := SliderJoint3D.new()
	slider.name = "Slider"
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, -0.75)
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.75)
	_connect_joint(slider, anchor, body)
	await physics_frame
	await physics_frame

	body.apply_central_impulse(Vector3(4, 2, 0))
	var max_x: float = 0.0
	var max_y: float = 0.0
	for frame in 90:
		await physics_frame
		max_x = maxf(max_x, absf(body.global_position.x))
		max_y = maxf(max_y, absf(body.global_position.y))

	_check(max_x > 0.1 and max_x < 1.0, "SliderJoint3D permits motion along its local X axis within configured limits")
	_check(max_y < 0.2 and body.rotation.length() < 0.2, "SliderJoint3D blocks orthogonal translation and rotation")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
