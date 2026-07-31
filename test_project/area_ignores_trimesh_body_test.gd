extends SceneTree

# Initialise a scene with an Area3D and two StaticBody3D children: one convex
# (BoxShape3D) and one concave (ConcavePolygonShape3D / trimesh).
#
# An Area3D reports convex bodies overlapping it, but a trimesh body is never a
# sensor visitor in Box3D, so the area silently ignores it. This is a divergence
# from current Godot/Jolt behaviour, where a ConcavePolygonShape3D StaticBody
# triggers a body_entered signal on an Area3D on the first physics frame. This
# test documents that small discrepancy.

var frames: int = 0
var convex_entered: bool = false
var trimesh_entered: bool = false

func _on_body_entered(b: Node3D) -> void:
	print("Area entered by: ", b.name, " at frame ", frames)
	if b.name == "ConvexBody":
		convex_entered = true
	elif b.name == "TrimeshBody":
		trimesh_entered = true

func _initialize() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	var area: Area3D = Area3D.new()
	var area_shape: CollisionShape3D = CollisionShape3D.new()
	var area_box: BoxShape3D = BoxShape3D.new()
	area_box.size = Vector3(6, 6, 6)
	area_shape.shape = area_box
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	root.add_child(area)

	# Positive control: a convex static body inside the area (must be detected).
	var convex: StaticBody3D = StaticBody3D.new()
	convex.name = "ConvexBody"
	var convex_shape: CollisionShape3D = CollisionShape3D.new()
	var convex_box: BoxShape3D = BoxShape3D.new()
	convex_box.size = Vector3(1, 1, 1)
	convex_shape.shape = convex_box
	convex.add_child(convex_shape)
	convex.position = Vector3(-1.5, 0, 0)
	root.add_child(convex)

	# Behavior under test: a trimesh static body inside the area (must be ignored).
	var trimesh: StaticBody3D = StaticBody3D.new()
	trimesh.name = "TrimeshBody"
	var trimesh_shape: CollisionShape3D = CollisionShape3D.new()
	var trimesh_mesh: BoxMesh = BoxMesh.new()
	trimesh_mesh.size = Vector3(1, 1, 1)
	trimesh_shape.shape = trimesh_mesh.create_trimesh_shape()
	trimesh.add_child(trimesh_shape)
	trimesh.position = Vector3(1.5, 0, 0)
	root.add_child(trimesh)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 60:
		print("ConvexBody entered=", convex_entered, "  TrimeshBody entered=", trimesh_entered)
		var passed: bool = convex_entered and not trimesh_entered
		if passed:
			print("RESULT: PASS - area detected the convex body and ignored the trimesh body") # This is a divergence from Godot/Jolt
		elif not convex_entered:
			print("RESULT: FAIL - control body not detected; test is broken, not the feature")
		else:
			print("RESULT: FAIL - area reported the trimesh body (should be ignored)")
		quit(0 if passed else 1)
	return false
