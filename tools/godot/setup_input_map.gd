extends SceneTree
## Writes the game's input actions into project.godot.
## Keyboard + mouse and controller bindings for every action.
## Run: godot --headless --path . --script tools/godot/setup_input_map.gd

const DEADZONE := 0.25


func _init() -> void:
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_button(JOY_BUTTON_DPAD_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_button(JOY_BUTTON_DPAD_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _joy_button(JOY_BUTTON_DPAD_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _joy_button(JOY_BUTTON_DPAD_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("jump", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)])
	_action("attack", [_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_X)])
	_action("dash", [_key(KEY_K), _key(KEY_SHIFT), _mouse(MOUSE_BUTTON_RIGHT), _joy_button(JOY_BUTTON_B), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("grapple", [_key(KEY_L), _key(KEY_Q), _mouse(MOUSE_BUTTON_MIDDLE), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("slam", [_key(KEY_I), _key(KEY_F), _mouse(MOUSE_BUTTON_XBUTTON1), _joy_button(JOY_BUTTON_LEFT_SHOULDER), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("interact", [_key(KEY_E), _joy_button(JOY_BUTTON_Y)])
	_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy_button(JOY_BUTTON_START)])
	var err := ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _action(action_name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": DEADZONE, "events": events})


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.device = -1
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.device = -1
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = -1
	return event


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = -1
	return event
