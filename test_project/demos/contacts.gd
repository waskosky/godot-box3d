class_name ContactsDemo
extends DemoBase

const DROP_HEIGHT: float = 6.0

@export var reporter: RigidBody3D
@export var markers: Node3D

var _peak_impulse: float = 0.0


func _physics_process(_delta: float) -> void:
	if reporter == null or markers == null:
		return

	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(reporter.get_rid())
	var count: int = 0 if state == null else state.get_contact_count()

	for i in markers.get_child_count():
		var marker: MeshInstance3D = markers.get_child(i)
		marker.visible = i < count
		if i < count:
			marker.global_position = state.get_contact_local_position(i)

	var impulse: float = 0.0
	if count > 0:
		impulse = state.get_contact_impulse(0).length()
		_peak_impulse = maxf(_peak_impulse, impulse)

	set_status("Contacts: %d    Impulse: %.2f    Peak: %.2f" % [count, impulse, _peak_impulse])


func _action_buttons() -> Array[Array]:
	return [["demo_action", "Drop"]]


func _on_action(action: String) -> void:
	if action != "demo_action":
		return
	_peak_impulse = 0.0
	PhysicsServer3D.body_set_state(
		reporter.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(Vector3.FORWARD, 0.26), Vector3(0.0, DROP_HEIGHT, 0.0)),
	)
	reporter.linear_velocity = Vector3.ZERO
	reporter.angular_velocity = Vector3.ZERO
