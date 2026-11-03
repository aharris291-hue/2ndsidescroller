extends CanvasLayer
## Pause menu. Works with keyboard, mouse and controller (focus starts on Resume).

## On/off options shown in the grid: setting name -> label.
const OPTIONS := {
	&"screen_shake": "Screen shake",
	&"flashing": "Lightning flashes",
	&"high_effects": "Weather detail",
}

@onready var panel: Control = $Root
@onready var resume_button: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var fullscreen_button: Button = $Root/Panel/Margin/VBox/FullscreenButton
@onready var book_view_button: Button = $Root/Panel/Margin/VBox/BookViewButton
@onready var music_slider: HSlider = $Root/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Root/Panel/Margin/VBox/SfxRow/SfxSlider
@onready var quit_button: Button = $Root/Panel/Margin/VBox/QuitButton
@onready var quest_log: Label = $Root/Panel/Margin/VBox/QuestLog

var restart_button: Button
var options_button: Button
var map_button: Button
var save_button: Button
var _options: OptionsPanel
var _option_buttons: Dictionary = {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	_build_extra_controls()
	resume_button.pressed.connect(close)
	fullscreen_button.pressed.connect(Settings.toggle_fullscreen)
	book_view_button.pressed.connect(_on_book_view)
	quit_button.pressed.connect(_on_quit)
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	music_slider.value_changed.connect(_on_volume_changed.bind(true))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(false))


## Adds "Back to the last bookmark" and a two-column grid of display and comfort
## options. The grid keeps the panel short enough for a 1080p screen.
func _build_extra_controls() -> void:
	var box := resume_button.get_parent()
	var panel_container := $Root/Panel as Control
	# Grow from the centre if the options make the panel taller than its default size.
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH

	restart_button = Button.new()
	restart_button.name = &"RestartButton"
	restart_button.text = "Back to the last bookmark"
	restart_button.pressed.connect(_on_restart)
	box.add_child(restart_button)
	box.move_child(restart_button, resume_button.get_index() + 1)

	map_button = Button.new()
	map_button.name = &"MapButton"
	map_button.text = "The torn map"
	map_button.pressed.connect(_open_map)
	box.add_child(map_button)
	box.move_child(map_button, restart_button.get_index() + 1)

	# Out in the Margin (the real world) Patch can save anywhere.
	save_button = Button.new()
	save_button.name = &"SaveButton"
	save_button.text = "Save here"
	save_button.pressed.connect(_on_save_here)
	box.add_child(save_button)
	box.move_child(save_button, map_button.get_index() + 1)

	options_button = Button.new()
	options_button.name = &"OptionsButton"
	options_button.text = "Controls, accessibility and assists"
	options_button.pressed.connect(_open_options)
	box.add_child(options_button)
	box.move_child(options_button, save_button.get_index() + 1)

	var grid := GridContainer.new()
	grid.name = &"Options"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 10)
	box.add_child(grid)
	box.move_child(grid, options_button.get_index() + 1)
	for button: Button in [fullscreen_button, book_view_button]:
		button.reparent(grid, false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option: StringName in OPTIONS:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_option.bind(option))
		grid.add_child(button)
		_option_buttons[option] = button
	_update_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map") and not panel.visible and MapPanel.current == null \
			and GameState.in_gameplay and not SceneManager.is_transitioning \
			and not DialogueUI.is_active() and not get_tree().paused:
		MapPanel.open_panel(get_tree().root)
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"pause") or is_instance_valid(_options):
		return
	if panel.visible:
		close()
	elif GameState.in_gameplay and not SceneManager.is_transitioning and not DialogueUI.is_active():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	var lines := GameState.quest_log()
	quest_log.text = "Side quests:\n" + "\n".join(lines) if not lines.is_empty() else "No side quests yet."
	# Rainy pages fill the screen instead of sitting in the book, so the switch would
	# do nothing there: only offer it where it shows.
	var scene := get_tree().current_scene
	book_view_button.visible = scene != null and scene.get(&"in_book") != false
	restart_button.visible = not GameState.checkpoint_page.is_empty()
	save_button.visible = in_margin()
	save_button.text = "Save here"
	_update_labels()
	panel.visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	panel.visible = false
	get_tree().paused = false
	Settings.save()


## True on a page out in the real world (the Margin), where Patch can save anywhere.
static func in_margin() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene
	# Margin pages are the ones staged on Gran's desk (a DeskDiorama).
	return scene is Page and scene.has_node(^"Diorama") and not GameState.sandbox


## Saves with Patch's current spot as the place to come back to.
func _on_save_here() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	GameState.set_checkpoint(get_tree().current_scene.scene_file_path, player.global_position)
	save_button.text = "Saved" if GameState.save_game() else "Couldn't save"


func _open_map() -> void:
	close()
	MapPanel.open_panel(get_tree().root)


func _open_options() -> void:
	_options = OptionsPanel.open_panel(self)
	_options.closed.connect(func() -> void:
		_update_labels()
		options_button.grab_focus.call_deferred())


func _on_book_view() -> void:
	Settings.toggle_book_view()
	_update_labels()


func _on_option(option: StringName) -> void:
	Settings.toggle(option)
	_update_labels()


func _update_labels() -> void:
	book_view_button.text = "Book view: on" if Settings.book_view else "Book view: off"
	for option: StringName in _option_buttons:
		var on: bool = Settings.get(option)
		var state := "on" if on else "off"
		if option == &"high_effects":
			state = "high" if on else "low"
		(_option_buttons[option] as Button).text = "%s: %s" % [OPTIONS[option], state]


func _on_volume_changed(value: float, is_music: bool) -> void:
	if is_music:
		Settings.music_volume = value
	else:
		Settings.sfx_volume = value
	Settings.apply()


## Starts again from the last bookmark, as if Patch had been torn: full health, same
## place. Handy when stuck or when a fight went badly.
func _on_restart() -> void:
	close()
	TimeFX.reset()
	SceneManager.respawn_at_checkpoint()


func _on_quit() -> void:
	close()
	GameState.save_game()
	HUD.show_hud(false)
	SceneManager.go_to_title()
