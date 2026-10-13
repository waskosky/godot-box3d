extends SceneTree

class MovingPlatform extends AnimatableBody3D:
	var speed := Vector3.ZERO
	var turn_speed := 0.0
	func _physics_process(delta: float) -> void:
		var target := transform
		target.origin += speed * delta
		target.basis = Basis(Vector3.UP, turn_speed * delta) * target.basis
		transform = target

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _solid(shape: Shape3D) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	return collision


func _box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	body.add_child(_solid(shape))
	body.position = position
	root.add_child(body)
	return body


func _character(position: Vector3) -> CharacterBody3D:
	var character := CharacterBody3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 1.0
	character.add_child(_solid(capsule))
	character.floor_snap_length = 0.15
	character.position = position
	root.add_child(character)
	return character


func _run() -> void:
	await _slope_limit(43.0, 40.0, true)
	await _slope_limit(47.0, 60.0, false)
	await _descending_step()
	await _rough_terrain()
	await _hole_boundary()
	await _platform_jump(false)
	await _platform_jump(true)
	if failures == 0:
		print("RESULT: PASS - floor-angle limits, descending steps, rough rotated terrain, holes and platform jump/detach")
	quit(1 if failures else 0)


func _slope_limit(degrees: float, x: float, floor_expected: bool) -> void:
	var angle := deg_to_rad(degrees)
	var floor_body := _box(Vector3(12, 0.5, 6), Vector3(x, -0.25 / cos(angle), 0))
	floor_body.rotation.z = angle
	var character := _character(Vector3(x, 0.5, 0))
	character.floor_max_angle = deg_to_rad(45)
	await physics_frame
	await physics_frame
	for frame in 20:
		character.velocity = Vector3(0, -1, 0)
		character.move_and_slide()
		await physics_frame
	_check(character.is_on_floor() == floor_expected, "slope %.0f degrees respects a 45-degree floor limit" % degrees)
	_check(character.position.is_finite() and character.get_slide_collision_count() > 0, "slope has finite, observable contact")
	character.queue_free()
	floor_body.queue_free()
	await process_frame


func _descending_step() -> void:
	_box(Vector3(2, 1, 4), Vector3(79, -0.5, 0))
	_box(Vector3(2, 1, 4), Vector3(81, -0.58, 0))
	var character := _character(Vector3(79, 0.5, 0))
	await physics_frame
	var grounded := 0
	for frame in 120:
		character.velocity = Vector3(1, -1, 0)
		character.move_and_slide()
		grounded += int(character.is_on_floor())
		await physics_frame
	_check(character.position.x > 80.5 and absf(character.position.y - 0.42) < 0.03 and grounded >= 115, "floor snap follows an 8 cm descending step")
	character.queue_free()
	await process_frame


func _rough_terrain() -> void:
	var heights := HeightMapShape3D.new()
	heights.map_width = 9
	heights.map_depth = 9
	var data := PackedFloat32Array()
	var row := [-0.08, 0.0, 0.08, 0.0, -0.08, 0.0, 0.08, 0.0, -0.08]
	for z in 9:
		for x in 9:
			data.append(row[x])
	heights.map_data = data
	var floor_body := StaticBody3D.new()
	floor_body.position.x = 100
	floor_body.rotation.y = PI / 6.0
	floor_body.add_child(_solid(heights))
	root.add_child(floor_body)
	var character := _character(floor_body.transform * Vector3(-2.5, 0.54, 0.5))
	var direction := floor_body.basis * Vector3.RIGHT
	await physics_frame
	var grounded := 0
	for frame in 180:
		character.velocity = direction + Vector3.DOWN
		character.move_and_slide()
		grounded += int(character.is_on_floor())
		_check(character.position.is_finite() and character.position.y > 0.4 and character.position.y < 0.62, "rough terrain retains bounded support height")
		await physics_frame
	var local := floor_body.transform.affine_inverse() * character.position
	_check(local.x > 0.25 and grounded >= 175, "character traverses peaks/seams on a rotated heightmap")
	character.queue_free()
	await process_frame


func _hole_boundary() -> void:
	var heights := HeightMapShape3D.new()
	heights.map_width = 7
	heights.map_depth = 7
	var data := PackedFloat32Array()
	for z in 7:
		for x in 7:
			data.append(NAN if x == 3 else 0.0)
	heights.map_data = data
	var floor_body := StaticBody3D.new()
	floor_body.position.x = 120
	floor_body.add_child(_solid(heights))
	root.add_child(floor_body)
	var character := _character(Vector3(118, 0.5, 0))
	await physics_frame
	var initial_grounded := 0
	var air_frames := 0
	for frame in 150:
		character.velocity.x = 1.0
		character.velocity.y -= 9.8 / 60.0
		character.move_and_slide()
		if frame < 30:
			initial_grounded += int(character.is_on_floor())
		elif not character.is_on_floor():
			air_frames += 1
		await physics_frame
	_check(initial_grounded >= 25 and air_frames > 40 and character.position.y < -0.5, "crossing a NaN hole boundary loses support and falls")
	character.queue_free()
	await process_frame


func _platform_jump(rotating: bool) -> void:
	var platform := MovingPlatform.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 1, 8)
	platform.position = Vector3(160 if rotating else 140, -0.5, 0)
	platform.add_child(_solid(box))
	root.add_child(platform)
	var offset := Vector3(2, 1, 0) if rotating else Vector3(0, 1, 0)
	var character := _character(platform.position + offset)
	await physics_frame
	await physics_frame
	if rotating:
		platform.turn_speed = 0.3
	else:
		platform.speed.x = 0.6
	for frame in 90:
		character.velocity = Vector3.DOWN
		character.move_and_slide()
		await physics_frame
	var expected := platform.transform * offset
	_check(character.is_on_floor() and character.position.distance_to(expected) < 0.08, "platform carries an offset rider (rotating=%s): actual=%s expected=%s" % [rotating, character.position, expected])
	var inherited := character.get_platform_velocity()
	character.velocity = Vector3(0, 3, 0)
	character.move_and_slide()
	_check(not character.is_on_floor(), "jump detaches immediately (rotating=%s): position=%s velocity=%s collisions=%s" % [rotating, character.position, character.velocity, _contacts(character)])
	var horizontal := Vector3(character.velocity.x, 0, character.velocity.z)
	var expected_horizontal := Vector3(inherited.x, 0, inherited.z)
	_check(expected_horizontal.length() > 0.5 and horizontal.distance_to(expected_horizontal) < 0.05, "jump inherits platform velocity (rotating=%s): actual=%s expected=%s" % [rotating, horizontal, expected_horizontal])
	for frame in 15:
		await physics_frame
		character.velocity.y -= 9.8 / 60.0
		character.move_and_slide()
	_check(character.position.y > 0.8 and not character.is_on_floor(), "detached character continues its airborne jump")
	character.queue_free()
	platform.queue_free()
	await process_frame


func _contacts(character: CharacterBody3D) -> Array:
	var contacts := []
	for index in character.get_slide_collision_count():
		var hit := character.get_slide_collision(index)
		contacts.append({"normal": hit.get_normal(), "position": hit.get_position(), "travel": hit.get_travel(), "depth": hit.get_depth()})
	return contacts


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESULT: FAIL - ", message)
