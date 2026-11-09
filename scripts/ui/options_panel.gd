class_name OptionsPanel
extends CanvasLayer
## Controls and accessibility, opened from the pause menu or the title screen.
##
## Two pages, switched by the tabs at the top:
## - Controls: rebind every action for keyboard and mouse or for a controller, apply
##   the left-hand keyboard layout, or reset to the defaults.
## - Accessibility and assists: auto-guard, shapes on tells, sound captions, text
##   size, and the assists (gentle hits, safe falls, wider parry, slower game).
## Works with keyboard, mouse and controller; Back (or Esc) closes it.

signal closed

const BONE := Color("e6dccb")
const BLOOD := Color("7a231c")
const SERIF := preload("res://assets/fonts/LiberationSerif-Regular.ttf")

## Accessibility page: setting -> [label, description shown under the list].
const ACCESS := [
	[&"auto_guard", "Auto-guard", "Patch blocks hits from the front by himself while standing or walking. Timing your own guard still parries."],
	[&"tell_shapes", "Shapes on tells", "A yellow warning sign joins every red glow (dodge it), so tells never rely on colour alone."],
	[&"sound_captions", "Sound captions", "Short captions for important sounds: growls, splashes, bookmarks, the hair dryer."],
	[&"text_scale", "Text size", "Size of dialogue, names and captions."],
	[&"screen_shake", "Screen shake", "Camera shake on heavy hits and slams."],
	[&"flashing", "Lightning flashes", "Turn off if flashing light bothers you."],
	[&"assist", "Assist: gentle hits", "No single hit takes more than half a paper token."],
	[&"assist_safe_falls", "Assist: safe falls", "Falling off the page puts Patch back on the ledge without hurting him."],
	[&"assist_wide_parry", "Assist: wider parry", "The parry window is twice as long."],
	[&"game_speed", "Assist: game speed", "Run the whole game at 80% for more time to react."],
]

var _root: Control
var _pages := {}
var _tabs := {}
var _access_buttons := {}
var _binding_buttons := {}
var _hint: Label
## While rebinding: [action, controller column?]; empty when not waiting for input.
var _waiting: Array = []


static func open_panel(parent: Node, page := &"controls") -> OptionsPanel:
	var panel := OptionsPanel.new()
	parent.add_child(panel)
	panel.show_page(page)
	return panel


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func show_page(page: StringName) -> void:
	for key: StringName in _pages:
		(_pages[key] as Control).visible = key == page
	_refresh()
	(_tabs[page] as Button).grab_focus()


func close() -> void:
	Settings.save()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting.is_empty() and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _waiting.is_empty() or not event.is_pressed() or event.is_echo():
		return
	var action: StringName = _waiting[0]
	var controller: bool = _waiting[1]
	var accepted: InputEvent = null
	if not controller:
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			accepted = null
		elif event is InputEventKey:
			var key := InputEventKey.new()
			key.physical_keycode = (event as InputEventKey).physical_keycode
			accepted = key
		elif event is InputEventMouseButton:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = (event as InputEventMouseButton).button_index
			accepted = mouse
		else:
			return
	else:
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			accepted = null
		elif event is InputEventJoypadButton:
			if (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
				accepted = null
			else:
				var button := InputEventJoypadButton.new()
				button.button_index = (event as InputEventJoypadButton).button_index
				accepted = button
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
			var motion := InputEventJoypadMotion.new()
			motion.axis = (event as InputEventJoypadMotion).axis
			motion.axis_value = signf((event as InputEventJoypadMotion).axis_value)
			accepted = motion
		else:
			return
	get_viewport().set_input_as_handled()
	_waiting = []
	if accepted:
		Settings.rebind(action, accepted)
	_refresh()
	(_binding_buttons[_key(action, controller)] as Button).grab_focus.call_deferred()


# --- Building --------------------------------------------------------------------

func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.02, 0.02, 0.03, 0.82)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -620
	panel.offset_right = 620
	panel.offset_top = -470
	panel.offset_bottom = 470
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.06, 0.96)
	box.border_color = BLOOD
	box.set_border_width_all(2)
	box.border_width_top = 4
	box.set_content_margin_all(28)
	panel.add_theme_stylebox_override(&"panel", box)
	_root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	panel.add_child(vbox)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 12)
	vbox.add_child(tabs)
	for tab: Array in [[&"controls", "Controls"], [&"access", "Accessibility and assists"]]:
		var button := _button(tab[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_page.bind(tab[0]))
		tabs.add_child(button)
		_tabs[tab[0]] = button

	_pages[&"controls"] = _build_controls()
	_pages[&"access"] = _build_access()
	for page: Control in _pages.values():
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(page)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(0, 64)
	_hint.add_theme_color_override(&"font_color", Color("a89f8f"))
	_hint.add_theme_font_size_override(&"font_size", 24)
	vbox.add_child(_hint)
	var back := _button("Back")
	back.pressed.connect(close)
	vbox.add_child(back)


func _build_controls() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 10)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 6)
	scroll.add_child(grid)
	for title in ["Action", "Keyboard and mouse", "Controller"]:
		grid.add_child(_label(title, BONE))
	for action: StringName in Settings.REBINDABLE:
		grid.add_child(_label(Settings.REBINDABLE[action], Color("b8b0a0")))
		for controller in [false, true]:
			var button := _button("")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(380, 0)
			button.pressed.connect(_start_rebind.bind(action, controller))
			button.focus_entered.connect(_set_hint.bind("Choose a binding, then press the new key or button. Esc (or Back on a controller) cancels."))
			grid.add_child(button)
			_binding_buttons[_key(action, controller)] = button
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	page.add_child(row)
	var left := _button("Left-hand keyboard layout")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.pressed.connect(func() -> void:
		Settings.apply_preset(&"left_hand")
		_refresh())
	left.focus_entered.connect(_set_hint.bind("Everything under the left hand: move WASD, jump Space, cut Q, heavy E, guard C, dodge Shift, mend R, grapple Tab, slam V, warp Z, interact F."))
	row.add_child(left)
	var reset := _button("Reset to defaults")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh())
	reset.focus_entered.connect(_set_hint.bind("Put every key and button back the way the game started."))
	row.add_child(reset)
	return page


func _build_access() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 10)
	for entry: Array in ACCESS:
		var button := _button("")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_access.bind(entry[0]))
		button.focus_entered.connect(_set_hint.bind(entry[2]))
		button.mouse_entered.connect(_set_hint.bind(entry[2]))
		grid.add_child(button)
		_access_buttons[entry[0]] = button
	return grid


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.09, 0.9)
	normal.border_color = Color("2e2420")
	normal.set_border_width_all(2)
	normal.set_content_margin_all(8)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.16, 0.08, 0.07, 0.95)
	focus.border_color = BLOOD
	focus.border_width_left = 6
	for state in [&"normal", &"disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in [&"hover", &"focus", &"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, focus)
	for state in [&"font_color", &"font_focus_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("c8c0b0"))
	button.add_theme_color_override(&"font_hover_color", BONE)
	button.add_theme_color_override(&"font_pressed_color", BONE)
	button.add_theme_font_override(&"font", SERIF)
	button.add_theme_font_size_override(&"font_size", 26)
	return button


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_override(&"font", SERIF)
	label.add_theme_font_size_override(&"font_size", 26)
	return label


# --- Behaviour -------------------------------------------------------------------

func _start_rebind(action: StringName, controller: bool) -> void:
	_waiting = [action, controller]
	var button := _binding_buttons[_key(action, controller)] as Button
	button.text = "Press a button..." if controller else "Press a key or click..."


func _on_access(option: StringName) -> void:
	if option in [&"text_scale", &"game_speed"]:
		Settings.cycle(option)
	else:
		Settings.toggle(option)
	_refresh()


static func _key(action: StringName, controller: bool) -> String:
	return "%s|%s" % [action, "pad" if controller else "kb"]


func _set_hint(text: String) -> void:
	if _hint:
		_hint.text = text


func _refresh() -> void:
	for action: StringName in Settings.REBINDABLE:
		for controller in [false, true]:
			(_binding_buttons[_key(action, controller)] as Button).text = Settings.binding_text(action, controller)
	for entry: Array in ACCESS:
		var option: StringName = entry[0]
		var state := ""
		match option:
			&"text_scale":
				state = {1.0: "normal", 1.25: "large", 1.5: "largest"}.get(Settings.text_scale, "normal")
			&"game_speed":
				state = "%d%%" % roundi(Settings.game_speed * 100.0)
			_:
				state = "on" if Settings.get(option) else "off"
		(_access_buttons[option] as Button).text = "%s: %s" % [entry[1], state]
