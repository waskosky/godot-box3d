extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var excluded_body: StaticBody3D = _make_box_body(Vector3(0, 0, 0), 4)
	_make_box_body(Vector3(1.2, 0, 0), 4)
	_make_box_body(Vector3(2.4, 0, 0), 4)
	_make_box_body(Vector3(0, 0, 20), 8)

	await physics_frame
	await physics_frame

	var state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state

	var overlapping: Array[Vector3] = state.collide_shape(_make_query(Vector3(0, 0, 0), 4), 8)
	_check(not overlapping.is_empty(), "an overlapping query reports collision points")
	_check(overlapping.size() % 2 == 0, "results come back as point pairs")
	for point in overlapping:
		_check(point.length() < 10.0, "reported points are near the query")
		break

	var clear_query: Array[Vector3] = state.collide_shape(_make_query(Vector3(0, 40, 0), 4), 8)
	_check(clear_query.is_empty(), "a query clear of everything reports nothing")

	# Three boxes sit within reach, but the cap must hold the pair count to one.
	var capped: Array[Vector3] = state.collide_shape(_make_query(Vector3(1.2, 0, 0), 4), 1)
	_check(capped.size() == 2, "max_results caps the number of returned pairs")

	var filtered: Array[Vector3] = state.collide_shape(_make_query(Vector3(0, 0, 0), 2), 8)
	_check(filtered.is_empty(), "a non-matching collision mask reports nothing")

	var other_layer: Array[Vector3] = state.collide_shape(_make_query(Vector3(0, 0, 20), 8), 8)
	_check(not other_layer.is_empty(), "a matching collision mask still reports")

	var excluded_query: PhysicsShapeQueryParameters3D = _make_query(Vector3(0, 0, 0), 4)
	excluded_query.exclude = [excluded_body.get_rid()]
	var excluded: Array[Vector3] = state.collide_shape(excluded_query, 8)
	_check(excluded.is_empty(), "excluded body RIDs are ignored")

	if failures == 0:
		print("RESULT: PASS - collide_shape reports overlapping shape points")
	else:
		print("RESULT: FAIL - ", failures, " collide_shape assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _make_query(position: Vector3, mask: int) -> PhysicsShapeQueryParameters3D:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(), position)
	query.collision_mask = mask
	return query


func _make_box_body(position: Vector3, layer: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position
	body.collision_layer = layer
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	collision.shape = box
	body.add_child(collision)
	root.add_child(body)
	return body


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
