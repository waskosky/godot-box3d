extends SceneTree

# Tests that a dynamic body must rest ON a trimesh floor, not tunnel
# through it.

var frames: int = 0
var body: RigidBody3D

func _initialize() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	# Trimesh floor: a thin box turned into a ConcavePolygonShape3D so we get Godot's
	# real triangle winding rather than a hand-rolled one.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(10, 1, 10)
	floor_shape.shape = floor_mesh.create_trimesh_shape()
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)  # top face at y = 0
	root.add_child(floor_body)

	body = RigidBody3D.new()
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	body_shape.shape = box
	body.add_child(body_shape)
	body.position = Vector3(0, 5, 0)
	root.add_child(body)

	print("Initial body Y: ", body.position.y)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 180:
		var y: float = body.global_position.y
		print("Body Y after 180 physics frames: ", y)
		print("Body linear velocity: ", body.linear_velocity)
		# Box (half-height 0.5) resting on floor top (y = 0) settles near y = 0.5.
		if y > 0.2 and y < 1.0:
			print("RESULT: PASS - body came to rest on the trimesh floor")
		else:
			print("RESULT: FAIL - body did not rest on the trimesh floor (tunneled or floated)")
		quit()
	return false
