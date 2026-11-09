extends Node
## Player preferences (volume, display, comfort, accessibility, assist options and
## control bindings), stored apart from save slots in user://settings.cfg.

## Emitted after any setting is applied, so live systems (weather, camera) can follow.
signal changed

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := false
## Show pages as an open book on a desk (BookFrame). Off = flat full-screen page.
var book_view := true
## Camera shake on heavy hits, slams and boss blows.
var screen_shake := true
## Lightning flashes in the rain (off for players sensitive to flashing light).
var flashing := true
## Weather detail: true = full fog, film grain and rain; false = lighter for older GPUs.
var high_effects := true
## Assist: enemy hits take at most half a paper token, for a gentler adventure.
var assist := false
## Assist: falling off the page puts Patch back on the ledge without costing health.
var assist_safe_falls := false
## Assist: the parry window is twice as long.
var assist_wide_parry := false
## Assist: the whole game runs at this speed (1.0, or 0.8 for more time to react).
var game_speed := 1.0
## Accessibility: Patch guards by himself when a blockable hit comes at his front while
## he's standing still or walking (a block, never a parry).
var auto_guard := false
## Accessibility: every tell also shows a shape (a white star to parry, a black and
## yellow warning to dodge), so the colours aren't the only cue.
var tell_shapes := false
## Accessibility: short captions for important sounds (growls, splashes, alarms).
var sound_captions := false
## Accessibility: dialogue and caption text size: 1.0, 1.25 or 1.5.
var text_scale := 1.0

## Actions the player can rebind, in the order the controls screen lists them.
const REBINDABLE := {
	&"move_left": "Move left",
	&"move_right": "Move right",
	&"move_up": "Up / climb",
	&"move_down": "Down / drop",
	&"jump": "Jump",
	&"attack": "Light cut",
	&"heavy": "Heavy cut",
	&"guard": "Guard / parry",
	&"dash": "Dodge",
	&"mend": "Mend",
	&"grapple": "Thread grapple",
	&"slam": "Pop-Up Slam",
	&"switch_form": "Switch shears form",
	&"warp": "Bookmark warp",
	&"interact": "Interact",
	&"map": "Torn map",
	&"pause": "Pause",
}
## Ready-made keyboard layouts. "left_hand" puts everything under the left hand, so
## the right hand is free (or the mouse isn't needed).
const PRESETS := {
	&"left_hand": {
		&"move_left": [KEY_A], &"move_right": [KEY_D], &"move_up": [KEY_W], &"move_down": [KEY_S],
		&"jump": [KEY_SPACE], &"attack": [KEY_Q], &"heavy": [KEY_E], &"guard": [KEY_C],
		&"dash": [KEY_SHIFT], &"mend": [KEY_R], &"grapple": [KEY_TAB], &"slam": [KEY_V],
		&"interact": [KEY_F], &"map": [KEY_G], &"pause": [KEY_ESCAPE], &"switch_form": [KEY_X],
		&"warp": [KEY_Z],
	},
}
const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5]
const GAME_SPEEDS: Array[float] = [1.0, 0.8]

## The project's own bindings, kept so "Reset to defaults" can put them back.
var _default_bindings := {}


func _ready() -> void:
	for action: StringName in REBINDABLE:
		_default_bindings[action] = InputMap.action_get_events(action).duplicate()
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
		book_view = config.get_value("video", "book_view", book_view)
		high_effects = config.get_value("video", "high_effects", high_effects)
		screen_shake = config.get_value("comfort", "screen_shake", screen_shake)
		flashing = config.get_value("comfort", "flashing", flashing)
		assist = config.get_value("comfort", "assist", assist)
		assist_safe_falls = config.get_value("assist", "safe_falls", assist_safe_falls)
		assist_wide_parry = config.get_value("assist", "wide_parry", assist_wide_parry)
		game_speed = config.get_value("assist", "game_speed", game_speed)
		auto_guard = config.get_value("access", "auto_guard", auto_guard)
		tell_shapes = config.get_value("access", "tell_shapes", tell_shapes)
		sound_captions = config.get_value("access", "sound_captions", sound_captions)
		text_scale = config.get_value("access", "text_scale", text_scale)
		for action: StringName in REBINDABLE:
			# An action added since this file was written keeps its default binding.
			var events = config.get_value("bindings", String(action)) if config.has_section_key("bindings", String(action)) else null
			if events is Array and not events.is_empty():
				_set_events(action, events)
	apply()


func apply() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	# TimeFX loads after Settings; on the first apply it reads game_speed itself.
	var time_fx := get_node_or_null(^"/root/TimeFX")
	if time_fx:
		time_fx.set_base_speed(game_speed)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	# Headless runs (CI, exports) have no window to change.
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	changed.emit()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "book_view", book_view)
	config.set_value("video", "high_effects", high_effects)
	config.set_value("comfort", "screen_shake", screen_shake)
	config.set_value("comfort", "flashing", flashing)
	config.set_value("comfort", "assist", assist)
	config.set_value("assist", "safe_falls", assist_safe_falls)
	config.set_value("assist", "wide_parry", assist_wide_parry)
	config.set_value("assist", "game_speed", game_speed)
	config.set_value("access", "auto_guard", auto_guard)
	config.set_value("access", "tell_shapes", tell_shapes)
	config.set_value("access", "sound_captions", sound_captions)
	config.set_value("access", "text_scale", text_scale)
	for action: StringName in REBINDABLE:
		config.set_value("bindings", String(action), InputMap.action_get_events(action))
	config.save(PATH)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save()


func toggle_book_view() -> void:
	book_view = not book_view
	BookFrame.refresh()
	save()


## Flips one of the on/off options by name ("screen_shake", "flashing", "high_effects",
## "assist"), applies it and saves.
func toggle(option: StringName) -> void:
	set(option, not get(option))
	apply()
	save()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## Steps a many-valued option (text_scale, game_speed) to its next value.
func cycle(option: StringName) -> void:
	var values: Array[float] = TEXT_SCALES if option == &"text_scale" else GAME_SPEEDS
	var at := values.find(get(option))
	set(option, values[(at + 1) % values.size()])
	apply()
	save()


# --- Bindings ------------------------------------------------------------------

## True for a keyboard or mouse event ("kb"), false for a controller one ("pad").
static func is_keyboard(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


## Binds `event` to `action` in its column (keyboard and mouse, or controller),
## replacing what that column had. Anything else using the same input lets go of it,
## so one press never does two things.
func rebind(action: StringName, event: InputEvent) -> void:
	var keyboard := is_keyboard(event)
	for other: StringName in REBINDABLE:
		for old in InputMap.action_get_events(other):
			if other == action and is_keyboard(old) == keyboard:
				InputMap.action_erase_event(other, old)
			elif _same_input(old, event):
				InputMap.action_erase_event(other, old)
	InputMap.action_add_event(action, event)
	save()


func reset_bindings() -> void:
	for action: StringName in REBINDABLE:
		_set_events(action, _default_bindings[action])
	save()


## Applies a keyboard preset; controller bindings are left as they are.
func apply_preset(preset: StringName) -> void:
	var layout: Dictionary = PRESETS[preset]
	for action: StringName in layout:
		for old in InputMap.action_get_events(action):
			if is_keyboard(old):
				InputMap.action_erase_event(action, old)
		for keycode: int in layout[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
	save()


## What's bound to `action` in one column, for menus and button prompts.
func binding_text(action: StringName, controller: bool) -> String:
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		if is_keyboard(event) != controller:
			var text := event_name(event)
			if not text.is_empty() and not names.has(text):
				names.append(text)
	return " / ".join(names) if not names.is_empty() else "-"


static func event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		# Name the key as printed on this keyboard (AZERTY and so on); a headless run
		# has no keyboard layout to ask.
		if key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Click"
			MOUSE_BUTTON_RIGHT: return "Right-click"
			MOUSE_BUTTON_MIDDLE: return "Middle-click"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel"
			_: return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		var buttons := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-pad up", "D-pad down", "D-pad left", "D-pad right"]
		var index := (event as InputEventJoypadButton).button_index
		return buttons[index] if index < buttons.size() else "Button %d" % index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
			JOY_AXIS_LEFT_X: return "Left stick " + ("left" if motion.axis_value < 0 else "right")
			JOY_AXIS_LEFT_Y: return "Left stick " + ("up" if motion.axis_value < 0 else "down")
			JOY_AXIS_RIGHT_X: return "Right stick " + ("left" if motion.axis_value < 0 else "right")
			JOY_AXIS_RIGHT_Y: return "Right stick " + ("up" if motion.axis_value < 0 else "down")
	return ""


func _set_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		if event is InputEvent:
			InputMap.action_add_event(action, event)


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		return (ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode) == (kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis and signf((a as InputEventJoypadMotion).axis_value) == signf((b as InputEventJoypadMotion).axis_value)
	return false
