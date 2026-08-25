extends SceneTree

const VIEWPORT_SIZE := Vector2i(800, 600)

var failures := 0
var pick_counts: Dictionary = {}
var pick_shape_indices: Dictionary = {}


func _initialize() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	call_deferred("_run")


func _run() -> void:
	root.size = VIEWPORT_SIZE
	root.physics_object_picking = true
	root.physics_object_picking_sort = true
	root.physics_object_picking_first_only = true
	# Headless windows never receive an OS-level mouse-enter notification, but Viewport
	# intentionally suppresses picking while the pointer is outside its bounds.
	root.notify_mouse_entered()

	var camera := Camera3D.new()
	camera.name = "PickCamera"
	camera.look_at_from_position(Vector3(0, 0, 6), Vector3.ZERO, Vector3.UP)
	camera.current = true
	root.add_child(camera)

	await _test_body(camera)
	await _test_area(camera)

	if failures == 0:
		print("RESULT: PASS - viewport ray picking honors body and area pickability")
	else:
		print("RESULT: FAIL - ", failures, " ray pickability check(s) failed")
	quit(1 if failures > 0 else 0)


func _assert_result(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)


func _make_box_shape() -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision.shape = shape
	return collision


func _track_pick_events(target: CollisionObject3D) -> void:
	pick_counts[target.name] = 0
	pick_shape_indices[target.name] = -1
	target.input_event.connect(_on_input_event.bind(target.name))


func _on_input_event(
		_camera: Camera3D,
		event: InputEvent,
		_event_position: Vector3,
		_normal: Vector3,
		shape_idx: int,
		target_name: StringName) -> void:
	if event is InputEventMouseButton and event.pressed:
		pick_counts[target_name] = int(pick_counts.get(target_name, 0)) + 1
		pick_shape_indices[target_name] = shape_idx


func _click(camera: Camera3D, world_position: Vector3) -> void:
	var screen_position := camera.unproject_position(world_position)
	var event := InputEventMouseButton.new()
	event.position = screen_position
	event.global_position = screen_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)

	event = InputEventMouseButton.new()
	event.position = screen_position
	event.global_position = screen_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event, true)


func _settle() -> void:
	await process_frame
	await physics_frame
	await physics_frame


func _direct_ray_hits(target: CollisionObject3D, collide_with_areas: bool) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 0, 6), Vector3(0, 0, -6))
	query.collide_with_bodies = not collide_with_areas
	query.collide_with_areas = collide_with_areas
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	return hit.get("rid", RID()) == target.get_rid() and hit.get("collider") == target


func _test_body(camera: Camera3D) -> void:
	var body := StaticBody3D.new()
	body.name = "PickableBody"
	body.add_child(_make_box_shape())
	root.add_child(body)
	_track_pick_events(body)
	await _settle()

	_click(camera, body.global_position)
	await _settle()
	_assert_result(int(pick_counts[body.name]) == 1, "viewport picking reaches a ray-pickable StaticBody3D")
	_assert_result(int(pick_shape_indices[body.name]) == 0, "body picking reports the local shape index")

	body.input_ray_pickable = false
	await _settle()
	_click(camera, body.global_position)
	await _settle()
	_assert_result(int(pick_counts[body.name]) == 1, "viewport picking ignores a StaticBody3D after ray picking is disabled")
	_assert_result(_direct_ray_hits(body, false), "ordinary scripted ray queries still hit an unpickable body")

	body.queue_free()
	await _settle()


func _test_area(camera: Camera3D) -> void:
	var area := Area3D.new()
	area.name = "PickableArea"
	area.add_child(_make_box_shape())
	root.add_child(area)
	_track_pick_events(area)
	await _settle()

	_click(camera, area.global_position)
	await _settle()
	_assert_result(int(pick_counts[area.name]) == 1, "viewport picking reaches a ray-pickable Area3D")
	_assert_result(int(pick_shape_indices[area.name]) == 0, "area picking reports the local shape index")

	area.input_ray_pickable = false
	await _settle()
	_click(camera, area.global_position)
	await _settle()
	_assert_result(int(pick_counts[area.name]) == 1, "viewport picking ignores an Area3D after ray picking is disabled")
	_assert_result(_direct_ray_hits(area, true), "ordinary scripted ray queries still hit an unpickable area")

	area.queue_free()
	await _settle()
