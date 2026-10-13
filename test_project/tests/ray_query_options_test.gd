extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var box := StaticBody3D.new()
	var box_collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE
	box_collision.shape = box_shape
	box.add_child(box_collision)
	root.add_child(box)
	var terrain := StaticBody3D.new()
	terrain.position = Vector3(10, 0, 0)
	var collision := CollisionShape3D.new()
	var mesh := ConcavePolygonShape3D.new()
	# Two clockwise triangles; input face 1 is the one under the ray.
	mesh.set_faces(PackedVector3Array([
		Vector3(5, 0, -1), Vector3(7, 0, -1), Vector3(6, 0, 1),
		Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(0, 0, 1),
	]))
	mesh.backface_collision = true
	collision.shape = mesh
	terrain.add_child(collision)
	root.add_child(terrain)
	await physics_frame
	await physics_frame
	var state := root.world_3d.direct_space_state
	var inside := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(2, 0, 0))
	inside.hit_from_inside = false
	_check(state.intersect_ray(inside).is_empty(), "inside hits are omitted when disabled")
	inside.hit_from_inside = true
	var inside_hit := state.intersect_ray(inside)
	_check(not inside_hit.is_empty() and inside_hit.get("position") == Vector3.ZERO and inside_hit.get("normal") == Vector3.ZERO, "enabled inside hits report the origin with a zero normal")
	var front := PhysicsRayQueryParameters3D.create(Vector3(10, 1, 0), Vector3(10, -1, 0))
	var front_hit := state.intersect_ray(front)
	_check(front_hit.get("face_index", -1) == 1, "ray face index uses input triangle order")
	_check(front_hit.get("normal", Vector3.ZERO).distance_to(Vector3.UP) < 0.01, "front-facing triangle has the expected normal")
	var back := PhysicsRayQueryParameters3D.create(Vector3(10, -1, 0), Vector3(10, 1, 0))
	back.hit_back_faces = false
	_check(state.intersect_ray(back).is_empty(), "backface hits are omitted when disabled")
	back.hit_back_faces = true
	var back_hit := state.intersect_ray(back)
	_check(back_hit.get("face_index", -1) == 1 and back_hit.get("normal", Vector3.ZERO).distance_to(Vector3.DOWN) < 0.01, "enabled backface hits have an input face index and oppose the ray")
	back.exclude = [terrain.get_rid()]
	_check(state.intersect_ray(back).is_empty(), "backface fallback honors exclusions")
	back.exclude = []
	back.collision_mask = 2
	_check(state.intersect_ray(back).is_empty(), "backface fallback honors collision masks")
	back.collision_mask = 1
	mesh.backface_collision = false
	await physics_frame
	_check(state.intersect_ray(back).is_empty(), "the mesh must also enable backface collision")
	if failures == 0:
		print("RESULT: PASS - ray queries honor inside/backface options and original mesh triangle indices")
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESULT: FAIL - ", message)
