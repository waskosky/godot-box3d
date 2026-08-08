class_name OrbitCamera
extends Node3D

@export var distance: float = 14.0
@export var min_distance: float = 3.0
@export var max_distance: float = 60.0
@export var pitch_degrees: float = -22.0
@export var yaw_degrees: float = 0.0
@export var orbit_speed: float = 0.4
@export var zoom_step: float = 1.2

@onready var _camera: Camera3D = %Camera

var _dragging: bool = false


func _ready() -> void:
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("demo_orbit"):
		_dragging = true
	elif event.is_action_released("demo_orbit"):
		_dragging = false
	elif event.is_action_pressed("demo_zoom_in"):
		distance = maxf(min_distance, distance - zoom_step)
		apply()
	elif event.is_action_pressed("demo_zoom_out"):
		distance = minf(max_distance, distance + zoom_step)
		apply()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		yaw_degrees -= motion.relative.x * orbit_speed
		pitch_degrees = clampf(pitch_degrees - motion.relative.y * orbit_speed, -85.0, 85.0)
		apply()


## Pushes distance and angles to the camera; call after setting them from code.
func apply() -> void:
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
	_camera.position = Vector3(0.0, 0.0, distance)
