class_name TrimeshTransformDemo
extends DemoBase

## Expected resting height per ball, so a wrong local transform reads as FAIL on screen.
const EXPECTED_Y: Array[float] = [2.35, 2.35, 2.35]
const TOLERANCE: float = 0.3

@export var balls: Node3D

var _start_transforms: Array[Transform3D] = []


func _ready() -> void:
	super._ready()
	for ball in balls.get_children():
		_start_transforms.append((ball as Node3D).global_transform)


func _physics_process(_delta: float) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for i in balls.get_child_count():
		var ball: RigidBody3D = balls.get_child(i)
		var resting: bool = absf(ball.global_position.y - EXPECTED_Y[i]) < TOLERANCE
		parts.append("%s %.2f %s" % [
			ball.name.replace("Ball", ""),
			ball.global_position.y,
			"OK" if resting else "..",
		])
	set_status("  ".join(parts))


func _action_buttons() -> Array[Array]:
	return [["demo_action", "Drop again"]]


func _on_action(action: String) -> void:
	if action != "demo_action":
		return
	for i in balls.get_child_count():
		var ball: RigidBody3D = balls.get_child(i)
		PhysicsServer3D.body_set_state(
			ball.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			_start_transforms[i],
		)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
