class_name DemoBase
extends Node3D

## Base for every demo scene. Owns the shared HUD wiring, the hub shortcut, and restart, so
## each demo only describes its own physics setup plus the actions it wants buttons for.

const HUB_SCENE: String = "res://main.tscn"

@export_multiline var description: String = ""
## Assigned in each demo scene; unique names do not cross an instanced scene boundary.
@export var hud: Node

var _hud: DemoHud


func _ready() -> void:
	_hud = hud as DemoHud
	if _hud == null:
		return
	_hud.title_label.text = name.capitalize()
	_hud.description_label.text = description
	_hud.status_label.text = ""
	_hud.back_pressed.connect(return_to_hub)
	_hud.restart_pressed.connect(restart)
	_hud.action_pressed.connect(_on_action)
	for entry in _action_buttons():
		_hud.add_action(entry[0], entry[1])

	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("demo_back"):
		get_viewport().set_input_as_handled()
		return_to_hub()
		return
	if event.is_action_pressed("demo_restart"):
		get_viewport().set_input_as_handled()
		restart()
		return
	for entry in _action_buttons():
		if event.is_action_pressed(entry[0]):
			get_viewport().set_input_as_handled()
			_on_action(entry[0])
			return


func set_status(text: String) -> void:
	if _hud != null:
		_hud.status_label.text = text


func restart() -> void:
	get_tree().reload_current_scene()


func return_to_hub() -> void:
	# Running a demo standalone with F6 has no hub to go back to.
	if ResourceLoader.exists(HUB_SCENE):
		get_tree().change_scene_to_file(HUB_SCENE)


## Override to declare [action, button label] pairs; each gets a button and a key binding.
func _action_buttons() -> Array[Array]:
	return []


## Override to respond to a declared action, from either the button or the key.
func _on_action(_action: String) -> void:
	pass
