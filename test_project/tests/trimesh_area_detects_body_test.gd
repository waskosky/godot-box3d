extends SceneTree

# A trimesh (ConcavePolygonShape3D) is allowed to act as an Area3D *sensor*: it may
# detect convex bodies that pass through it. This exercises Box3D's mesh-as-sensor
# path (b3OverlapSensor with a mesh sensor + a convex visitor proxy), which is
# distinct from mesh-as-visitor (unsupported by box3D)

var frames: int = 0
var body: RigidBody3D
var area: Area3D
var entered: bool = false
var exited: bool = false

func _on_body_entered(b: Node3D) -> void:
	entered = true
	print("Trimesh area entered by: ", b.name)

func _on_body_exited(b: Node3D) -> void:
	exited = true
	print("Trimesh area exited by: ", b.name)

func _initialize() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	# Area3D whose own shape is a trimesh volume.
	area = Area3D.new()
	area.name = "TrimeshArea"
	var area_shape: CollisionShape3D = CollisionShape3D.new()
	var area_mesh: BoxMesh = BoxMesh.new()
	area_mesh.size = Vector3(4, 4, 4)
	area_shape.shape = area_mesh.create_trimesh_shape()
	area.add_child(area_shape)
	area.position = Vector3(0, 0, 0)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	root.add_child(area)

	# Convex dynamic body travelling straight down through the area.
	body = RigidBody3D.new()
	body.name = "FallingBody"
	body.gravity_scale = 0.0
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	body_shape.shape = box
	body.add_child(body_shape)
	body.position = Vector3(0, 10, 0)
	body.linear_velocity = Vector3(0, -5, 0)
	root.add_child(body)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 600:
		print("Entered: ", entered, " Exited: ", exited)
		if entered and exited:
			print("RESULT: PASS - trimesh area detected the convex body entering and exiting")
		else:
			print("RESULT: FAIL - trimesh area did not report enter/exit for the convex body")
		quit()
	return false
