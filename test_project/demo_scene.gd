class_name Box3DDemoScene
extends Node3D

# Spawns a ground plane, falling rigid bodies, a monitored area, and a hinge
# joint door entirely from code so the scene can be opened and played without
# hand-authored .tscn node trees.

var _door: RigidBody3D
var _door_swung: bool = false


func _ready() -> void:
	print("Active physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	_add_camera()
	_add_light()
	_add_ground()
	_add_trimesh_plane()
	_add_falling_bodies()
	_add_monitored_area()
	_add_hinge_door()


func _add_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 8, 16)
	camera.rotation_degrees = Vector3(-20, 0, 0)
	add_child(camera)


func _add_light() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	add_child(light)


func _add_ground() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0, -0.5, 0)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	mesh.mesh = box_mesh
	ground.add_child(mesh)

	add_child(ground)


func _add_trimesh_plane() -> void:
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(6, 6)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TrimeshFloor"
	body.position = Vector3(0, 2.5, 4)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = plane_mesh.create_trimesh_shape()
	body.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane_mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.45, 0.2)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	body.add_child(mesh)

	add_child(body)

	var dropper: RigidBody3D = RigidBody3D.new()
	dropper.name = "TrimeshDropper"
	dropper.position = Vector3(0, 8, 4)
	var dropper_shape: CollisionShape3D = CollisionShape3D.new()
	var dropper_box: BoxShape3D = BoxShape3D.new()
	dropper_box.size = Vector3(0.8, 0.8, 0.8)
	dropper_shape.shape = dropper_box
	dropper.add_child(dropper_shape)
	var dropper_mesh: MeshInstance3D = MeshInstance3D.new()
	var dropper_box_mesh: BoxMesh = BoxMesh.new()
	dropper_box_mesh.size = dropper_box.size
	dropper_mesh.mesh = dropper_box_mesh
	dropper.add_child(dropper_mesh)
	add_child(dropper)


func _add_falling_bodies() -> void:
	var positions: Array[Vector3] = [
		Vector3(-4, 6, -2),
		Vector3(-2, 8, -2),
		Vector3(0, 10, -2),
		Vector3(2, 8, -2),
		Vector3(4, 6, -2),
	]
	for i in positions.size():
		var use_sphere: bool = i % 2 == 0
		var body: RigidBody3D = RigidBody3D.new()
		body.name = "FallingBody%d" % i
		body.position = positions[i]

		var collision: CollisionShape3D = CollisionShape3D.new()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		if use_sphere:
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 0.5
			collision.shape = sphere
			var sphere_mesh: SphereMesh = SphereMesh.new()
			sphere_mesh.radius = 0.5
			sphere_mesh.height = 1.0
			mesh.mesh = sphere_mesh
		else:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(0.8, 0.8, 0.8)
			collision.shape = box
			var box_mesh: BoxMesh = BoxMesh.new()
			box_mesh.size = box.size
			mesh.mesh = box_mesh

		body.add_child(collision)
		body.add_child(mesh)
		add_child(body)


func _add_monitored_area() -> void:
	var area: Area3D = Area3D.new()
	area.name = "TriggerArea"
	area.position = Vector3(-4, 3, 4)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3, 6, 3)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = shape.size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.6, 1.0, 0.25)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.mesh = box_mesh
	mesh.material_override = material
	area.add_child(mesh)

	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	add_child(area)

	var dropper: RigidBody3D = RigidBody3D.new()
	dropper.name = "AreaDropper"
	dropper.position = Vector3(-4, 12, 4)
	var dropper_shape: CollisionShape3D = CollisionShape3D.new()
	var dropper_sphere: SphereShape3D = SphereShape3D.new()
	dropper_sphere.radius = 0.4
	dropper_shape.shape = dropper_sphere
	dropper.add_child(dropper_shape)
	var dropper_mesh: MeshInstance3D = MeshInstance3D.new()
	var dropper_sphere_mesh: SphereMesh = SphereMesh.new()
	dropper_sphere_mesh.radius = 0.4
	dropper_sphere_mesh.height = 0.8
	dropper_mesh.mesh = dropper_sphere_mesh
	dropper.add_child(dropper_mesh)
	add_child(dropper)


func _on_area_body_entered(body: Node3D) -> void:
	print("[Area] entered by: ", body.name)


func _on_area_body_exited(body: Node3D) -> void:
	print("[Area] exited by: ", body.name)


func _add_hinge_door() -> void:
	var anchor: StaticBody3D = StaticBody3D.new()
	anchor.name = "DoorAnchor"
	anchor.position = Vector3(4, 1.5, 4)
	var anchor_shape: CollisionShape3D = CollisionShape3D.new()
	var anchor_box: BoxShape3D = BoxShape3D.new()
	anchor_box.size = Vector3(0.2, 3, 0.2)
	anchor_shape.shape = anchor_box
	anchor.add_child(anchor_shape)
	var anchor_mesh: MeshInstance3D = MeshInstance3D.new()
	var anchor_box_mesh: BoxMesh = BoxMesh.new()
	anchor_box_mesh.size = anchor_box.size
	anchor_mesh.mesh = anchor_box_mesh
	anchor.add_child(anchor_mesh)
	add_child(anchor)

	_door = RigidBody3D.new()
	_door.name = "Door"
	_door.position = Vector3(5, 1.5, 4)
	_door.gravity_scale = 0.0
	var door_shape: CollisionShape3D = CollisionShape3D.new()
	var door_box: BoxShape3D = BoxShape3D.new()
	door_box.size = Vector3(2, 3, 0.1)
	door_shape.shape = door_box
	_door.add_child(door_shape)
	var door_mesh: MeshInstance3D = MeshInstance3D.new()
	var door_box_mesh: BoxMesh = BoxMesh.new()
	door_box_mesh.size = door_box.size
	door_mesh.mesh = door_box_mesh
	_door.add_child(door_mesh)
	add_child(_door)

	var hinge: HingeJoint3D = HingeJoint3D.new()
	hinge.position = Vector3(4, 1.5, 4)
	add_child(hinge)
	hinge.node_a = hinge.get_path_to(anchor)
	hinge.node_b = hinge.get_path_to(_door)


func _process(_delta: float) -> void:
	if not _door_swung and Engine.get_physics_frames() > 30:
		_door_swung = true
		_door.apply_torque_impulse(Vector3(0, 3.0, 0))
