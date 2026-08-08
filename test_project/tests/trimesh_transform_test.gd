extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The collision shape sits 4 units above its body. Box3D's mesh shape takes no
	# transform, so the local offset has to be baked into the mesh vertices.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = plane_mesh.create_trimesh_shape()
	collision.position = Vector3(0, 4, 0)
	floor_body.add_child(collision)
	root.add_child(floor_body)

	var ball: RigidBody3D = RigidBody3D.new()
	ball.position = Vector3(0, 12, 0)
	var ball_collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.5
	ball_collision.shape = sphere
	ball.add_child(ball_collision)
	root.add_child(ball)

	for frame in 240:
		await physics_frame

	var resting_y: float = ball.global_position.y
	_check(resting_y > 3.5, "body rests on an offset trimesh, not at the body origin")
	_check(absf(resting_y - 4.5) < 0.2, "resting height matches the offset shape surface")

	if failures == 0:
		print("RESULT: PASS - trimesh honors its local shape transform")
	else:
		print("RESULT: FAIL - ", failures, " trimesh transform assertion(s) failed")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
