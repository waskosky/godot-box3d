extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ProjectSettings.get_setting("physics/3d/physics_engine", "") == "Box3D Physics (Extension)", "test project requests the Box3D backend")
	_check(ClassDB.class_exists(&"Box3DPhysicsServer3D"), "Box3D extension is loaded")
	if failures > 0:
		quit(1)
		return

	await _test_point_queries()
	await _test_shape_motion_queries()
	await _test_supported_shape_queries()
	await _clear_scene()

	if failures == 0:
		print("RESULT: PASS - direct query and supported shape checks passed")
	else:
		print("RESULT: FAIL - ", failures, " direct query/shape assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _clear_scene() -> void:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await physics_frame
	await physics_frame


func _make_collision(shape: Shape3D) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	return collision


func _make_static_target(name: String, position: Vector3, shape: Shape3D, layer: int = 1) -> StaticBody3D:
	var target := StaticBody3D.new()
	target.name = name
	target.position = position
	target.collision_layer = layer
	target.collision_mask = 0
	target.add_child(_make_collision(shape))
	root.add_child(target)
	return target


func _make_area_target(name: String, position: Vector3, shape: Shape3D, layer: int = 1) -> Area3D:
	var target := Area3D.new()
	target.name = name
	target.position = position
	target.collision_layer = layer
	target.collision_mask = 0
	target.add_child(_make_collision(shape))
	root.add_child(target)
	return target


func _test_point_queries() -> void:
	await _clear_scene()

	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(2, 2, 2)
	var body := _make_static_target("PointBody", Vector3.ZERO, body_shape)

	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(2, 2, 2)
	var area := _make_area_target("PointArea", Vector3(4, 0, 0), area_shape)
	await physics_frame

	var state := root.get_world_3d().direct_space_state
	var point_query := PhysicsPointQueryParameters3D.new()
	point_query.position = Vector3.ZERO
	point_query.collision_mask = 1
	point_query.collide_with_bodies = true
	point_query.collide_with_areas = false

	var body_hits: Array[Dictionary] = state.intersect_point(point_query, 4)
	_check(body_hits.size() == 1 and body_hits[0].get("collider") == body, "intersect_point reports a body containing the point")

	point_query.exclude = [body.get_rid()]
	_check(state.intersect_point(point_query, 4).is_empty(), "intersect_point honors excluded RIDs")

	point_query.exclude = []
	point_query.position = area.position
	point_query.collide_with_bodies = false
	point_query.collide_with_areas = true
	var area_hits: Array[Dictionary] = state.intersect_point(point_query, 4)
	_check(area_hits.size() == 1 and area_hits[0].get("collider") == area, "intersect_point distinguishes areas from bodies")


func _test_shape_motion_queries() -> void:
	await _clear_scene()

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(6, 1, 6)
	var floor := _make_static_target("MotionFloor", Vector3(0, -0.5, 0), floor_shape)
	await physics_frame

	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	var motion_query := PhysicsShapeQueryParameters3D.new()
	motion_query.shape = sphere
	motion_query.transform = Transform3D(Basis(), Vector3(0, 3, 0))
	motion_query.motion = Vector3(0, -5, 0)
	motion_query.collision_mask = 1
	motion_query.collide_with_bodies = true
	motion_query.collide_with_areas = false

	var state := root.get_world_3d().direct_space_state
	var fractions: PackedFloat32Array = state.cast_motion(motion_query)
	_check(fractions.size() == 2 and fractions[0] > 0.0 and fractions[0] < 1.0 and fractions[1] >= fractions[0], "cast_motion reports safe and unsafe collision fractions")

	var rest: Dictionary = state.get_rest_info(motion_query)
	var normal: Vector3 = rest.get("normal", Vector3.ZERO)
	var point: Vector3 = rest.get("point", Vector3(0, 100, 0))
	_check(rest.get("rid", RID()) == floor.get_rid(), "get_rest_info reports the nearest collider")
	_check(absf(normal.y) > 0.8 and absf(point.y) < 0.15, "get_rest_info reports a usable contact point and normal")

	motion_query.exclude = [floor.get_rid()]
	fractions = state.cast_motion(motion_query)
	rest = state.get_rest_info(motion_query)
	_check(fractions.size() == 2 and is_equal_approx(fractions[0], 1.0) and is_equal_approx(fractions[1], 1.0) and rest.is_empty(), "shape motion queries honor excluded RIDs")


func _test_supported_shape_queries() -> void:
	await _clear_scene()

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	var capsule_target := _make_static_target("CapsuleTarget", Vector3(-6, 0, 0), capsule, 8)

	var convex := ConvexPolygonShape3D.new()
	convex.points = PackedVector3Array([
		Vector3(-0.75, -0.75, -0.75),
		Vector3(0.75, -0.75, -0.75),
		Vector3(-0.75, 0.75, -0.75),
		Vector3(0.75, 0.75, -0.75),
		Vector3(-0.75, -0.75, 0.75),
		Vector3(0.75, -0.75, 0.75),
		Vector3(-0.75, 0.75, 0.75),
		Vector3(0.75, 0.75, 0.75),
	])
	var convex_target := _make_static_target("ConvexTarget", Vector3(-2, 0, 0), convex, 8)

	var concave := ConcavePolygonShape3D.new()
	# Godot's front-face winding is opposite Box3D's one-sided mesh winding.
	concave.set_faces(PackedVector3Array([
		Vector3(-1, 0, -1),
		Vector3(1, 0, -1),
		Vector3(1, 0, 1),
		Vector3(-1, 0, -1),
		Vector3(1, 0, 1),
		Vector3(-1, 0, 1),
	]))
	var concave_target := _make_static_target("ConcaveTarget", Vector3(2, 0, 0), concave, 8)

	var heightmap := HeightMapShape3D.new()
	heightmap.map_width = 3
	heightmap.map_depth = 3
	heightmap.map_data = PackedFloat32Array([
		-0.1, 0.0, 0.1,
		-0.1, 0.0, 0.1,
		-0.1, 0.0, 0.1,
	])
	var heightmap_target := _make_static_target("HeightMapTarget", Vector3(6, 0, 0), heightmap, 8)

	var boundary := WorldBoundaryShape3D.new()
	boundary.plane = Plane(Vector3.UP, 0.0)
	var boundary_target := _make_static_target("BoundaryTarget", Vector3.ZERO, boundary, 16)
	await physics_frame
	await physics_frame

	_check(_ray_hits(capsule_target, Vector3(-6, 3, 0), 8), "ray query hits a CapsuleShape3D")
	_check(_ray_hits(convex_target, Vector3(-2, 3, 0), 8), "ray query hits a ConvexPolygonShape3D")
	_check(_ray_hits(concave_target, Vector3(2, 3, 0), 8), "ray query hits a ConcavePolygonShape3D")
	_check(_ray_hits(heightmap_target, Vector3(6, 3, 0), 8), "ray query hits a HeightMapShape3D")
	_check(_ray_hits(boundary_target, Vector3(20, 3, 0), 16), "ray query hits a WorldBoundaryShape3D")


func _ray_hits(target: CollisionObject3D, from: Vector3, mask: int) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -6, 0))
	query.collision_mask = mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_back_faces = true
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == target


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
