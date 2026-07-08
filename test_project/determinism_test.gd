extends SceneTree

var failures: int = 0
var first_body: StaticBody3D
var second_body: StaticBody3D


func _initialize() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	call_deferred("_run")


func _run() -> void:
	_setup_overlap_targets()
	await physics_frame
	await physics_frame

	_test_intersect_shape_order()
	_test_intersect_ray_tie_order()

	if failures == 0:
		print("RESULT: PASS - deterministic ordering checks passed")
	else:
		print("RESULT: FAIL - ", failures, " deterministic ordering check(s) failed")
	quit(1 if failures > 0 else 0)


func _assert_result(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)


func _make_box_shape(size: Vector3) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision


func _setup_overlap_targets() -> void:
	first_body = StaticBody3D.new()
	first_body.name = "FirstDeterminismTarget"
	first_body.add_child(_make_box_shape(Vector3(2, 2, 2)))
	root.add_child(first_body)

	second_body = StaticBody3D.new()
	second_body.name = "SecondDeterminismTarget"
	second_body.add_child(_make_box_shape(Vector3(2, 2, 2)))
	root.add_child(second_body)


func _test_intersect_shape_order() -> void:
	var query_shape: SphereShape3D = SphereShape3D.new()
	query_shape.radius = 1.5

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = Transform3D(Basis(), Vector3.ZERO)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits: Array[Dictionary] = root.get_world_3d().direct_space_state.intersect_shape(query, 1)
	_assert_result(hits.size() == 1, "intersect_shape returns one limited hit")
	if hits.size() == 1:
		_assert_result(hits[0]["rid"] == first_body.get_rid(), "intersect_shape limited hit uses stable RID order")


func _test_intersect_ray_tie_order() -> void:
	var result: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(-4, 0, 0), Vector3(4, 0, 0)))

	_assert_result(!result.is_empty(), "intersect_ray reports an overlapping target")
	if !result.is_empty():
		_assert_result(result["rid"] == first_body.get_rid(), "intersect_ray tie uses stable RID order")
