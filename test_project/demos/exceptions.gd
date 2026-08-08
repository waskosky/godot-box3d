class_name ExceptionsDemo
extends DemoBase

@export var excepted_a: RigidBody3D
@export var excepted_b: RigidBody3D
@export var control_a: RigidBody3D
@export var control_b: RigidBody3D

var _exception_active: bool = false


func _ready() -> void:
	super._ready()
	_set_exception(true)


func _physics_process(_delta: float) -> void:
	if excepted_a == null or control_a == null:
		return
	set_status("Exception: %s    Blue gap: %.2f    Orange gap: %.2f" % [
		"ON" if _exception_active else "OFF",
		excepted_a.global_position.distance_to(excepted_b.global_position),
		control_a.global_position.distance_to(control_b.global_position),
	])


func _action_buttons() -> Array[Array]:
	return [["demo_action", "Toggle exception"]]


func _on_action(action: String) -> void:
	if action == "demo_action":
		_set_exception(not _exception_active)


func _set_exception(enabled: bool) -> void:
	_exception_active = enabled
	if enabled:
		excepted_a.add_collision_exception_with(excepted_b)
	else:
		excepted_a.remove_collision_exception_with(excepted_b)
