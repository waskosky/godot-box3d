class_name JointsDemo
extends DemoBase

const SWEEP_SPEED: float = 0.01
const SWEEP_REACH: float = 0.6
const SLIDE_SPEED: float = 0.02
const SLIDE_FORCE: float = 40.0

@export var pendulum_joint: PinJoint3D
@export var door: RigidBody3D
@export var slider_box: RigidBody3D

var _elapsed_frames: int = 0


func _physics_process(_delta: float) -> void:
	_elapsed_frames += 1

	if pendulum_joint != null:
		var sweep: float = sin(_elapsed_frames * SWEEP_SPEED) * SWEEP_REACH
		PhysicsServer3D.pin_joint_set_local_a(pendulum_joint.get_rid(), Vector3(sweep, 0.0, 0.0))

	# The slider is horizontal, so gravity cannot drive it; push it back and forth instead.
	if slider_box != null:
		var push: float = signf(sin(_elapsed_frames * SLIDE_SPEED)) * SLIDE_FORCE
		slider_box.apply_central_force(Vector3(push, 0.0, 0.0))

	if door != null:
		set_status("Door: %+.0f deg    Slider X: %+.2f" % [
			rad_to_deg(door.rotation.y),
			0.0 if slider_box == null else slider_box.global_position.x - 4.0,
		])
