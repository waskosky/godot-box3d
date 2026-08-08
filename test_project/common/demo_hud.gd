class_name DemoHud
extends CanvasLayer

## Shared demo chrome: title, description, live status, and a control bar whose buttons are
## built from whatever actions the demo declares.

signal action_pressed(action: String)
signal back_pressed
signal restart_pressed

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var status_label: Label = %StatusLabel
@onready var controls: HBoxContainer = %Controls


func _ready() -> void:
	%BackButton.pressed.connect(back_pressed.emit)
	%RestartButton.pressed.connect(restart_pressed.emit)
	%BackButton.text = "Back (%s)" % _key_hint("demo_back")
	%RestartButton.text = "Restart (%s)" % _key_hint("demo_restart")
	%BackendLabel.text = "Backend: %s" % ProjectSettings.get_setting(
		"physics/3d/physics_engine", "DEFAULT"
	)


## Adds one button per extra action; the demo owns what each action means.
func add_action(action: String, label: String) -> void:
	var button: Button = Button.new()
	button.text = "%s (%s)" % [label, _key_hint(action)]
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action_pressed.emit.bind(action))
	controls.add_child(button)


func _key_hint(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return "?"
