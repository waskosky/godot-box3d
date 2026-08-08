class_name AreasDemo
extends DemoBase

@export var well: Area3D
@export var orb: Area3D


func _physics_process(_delta: float) -> void:
	if well == null or orb == null:
		return
	set_status("In well: %d    In orb: %d" % [
		well.get_overlapping_bodies().size(),
		orb.get_overlapping_bodies().size(),
	])
