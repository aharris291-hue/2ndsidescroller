extends Node
## Tracks whether the player last used a controller or keyboard/mouse,
## so on-screen prompts show the right button names.

signal device_changed(using_controller: bool)

var using_controller := false


func _input(event: InputEvent) -> void:
	var controller := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	var keyboard := event is InputEventKey or event is InputEventMouseButton
	if controller and not using_controller:
		using_controller = true
		device_changed.emit(true)
	elif keyboard and using_controller:
		using_controller = false
		device_changed.emit(false)


func interact_hint() -> String:
	return "Y" if using_controller else "E"


func hint(action: StringName) -> String:
	var hints := {
		&"jump": ["Space", "A"],
		&"attack": ["J / Click", "X"],
		&"dash": ["K / Shift", "B"],
		&"interact": ["E", "Y"],
		&"pause": ["Esc", "Start"],
	}
	var pair: Array = hints.get(action, ["?", "?"])
	return pair[1] if using_controller else pair[0]
