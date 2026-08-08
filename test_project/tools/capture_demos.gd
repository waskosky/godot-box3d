class_name CaptureDemos
extends SceneTree

## Screenshots every demo for the docs. Run with a real GPU; --headless uses the dummy
## rasterizer and writes blank images.
##
##   godot --path test_project --script res://tools/capture_demos.gd
##
## Add --write-out DIR to save somewhere other than the repo's docs/images/demos.

const SETTLE_FRAMES: int = 180
const OUTPUT_DIR: String = "res://../docs/images/demos"

## Optional distance/pitch pull the camera in; the scene defaults frame for playing, not for a
## still, and leave the subject in a thin band.
const SHOTS: Array[Dictionary] = [
	{"name": "shapes", "path": "res://demos/shapes.tscn", "distance": 9.0, "pitch": -14.0},
	{"name": "joints", "path": "res://demos/joints.tscn", "distance": 10.0, "pitch": -12.0},
	{"name": "areas", "path": "res://demos/areas.tscn", "distance": 10.0, "pitch": -18.0},
	{"name": "contacts", "path": "res://demos/contacts.tscn", "distance": 9.0, "pitch": -16.0},
	{"name": "exceptions", "path": "res://demos/exceptions.tscn", "distance": 10.0, "pitch": -16.0},
	{"name": "trimesh", "path": "res://demos/trimesh.tscn", "distance": 11.0, "pitch": -18.0},
	{
		"name": "trimesh_transform",
		"path": "res://demos/trimesh_transform.tscn",
		"distance": 11.0,
		"pitch": -18.0,
	},
]

var _output_dir: String = OUTPUT_DIR


func _init() -> void:
	_parse_arguments()
	_run.call_deferred()


func _parse_arguments() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for i in arguments.size():
		if arguments[i] == "--write-out" and i + 1 < arguments.size():
			_output_dir = arguments[i + 1]
			return


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("capture_demos needs a real display; --headless renders blank frames.")
		quit(1)
		return

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_output_dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))

	for shot in SHOTS:
		await _capture(shot)

	print("Captured %d demo screenshots to %s" % [
		SHOTS.size(),
		ProjectSettings.globalize_path(_output_dir),
	])
	quit()


func _capture(shot: Dictionary) -> void:
	var shot_name: String = str(shot["name"])
	var path: String = str(shot["path"])
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Could not load %s" % path)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	_frame_camera(scene, shot)

	for i in SETTLE_FRAMES:
		await physics_frame

	# One more process frame so the settled transforms reach the rendered image.
	await process_frame
	await process_frame

	var image: Image = root.get_texture().get_image()
	var target: String = "%s/%s.png" % [_output_dir, shot_name]
	image.save_png(ProjectSettings.globalize_path(target))
	print("  %s" % target)

	scene.queue_free()
	await process_frame


func _frame_camera(scene: Node, shot: Dictionary) -> void:
	var camera: OrbitCamera = _find_orbit_camera(scene)
	if camera == null:
		return
	if shot.has("distance"):
		camera.distance = float(shot["distance"])
	if shot.has("pitch"):
		camera.pitch_degrees = float(shot["pitch"])
	camera.apply()


func _find_orbit_camera(node: Node) -> OrbitCamera:
	if node is OrbitCamera:
		return node as OrbitCamera
	for child in node.get_children():
		var found: OrbitCamera = _find_orbit_camera(child)
		if found != null:
			return found
	return null
