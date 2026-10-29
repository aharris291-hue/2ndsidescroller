extends CanvasLayer
## Pause menu. Works with keyboard, mouse and controller (focus starts on Resume).

@onready var panel: Control = $Root
@onready var resume_button: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var fullscreen_button: Button = $Root/Panel/Margin/VBox/FullscreenButton
@onready var music_slider: HSlider = $Root/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Root/Panel/Margin/VBox/SfxRow/SfxSlider
@onready var quit_button: Button = $Root/Panel/Margin/VBox/QuitButton
@onready var quest_log: Label = $Root/Panel/Margin/VBox/QuestLog


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_button.pressed.connect(close)
	fullscreen_button.pressed.connect(Settings.toggle_fullscreen)
	quit_button.pressed.connect(_on_quit)
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	music_slider.value_changed.connect(_on_volume_changed.bind(true))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
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
	panel.visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	panel.visible = false
	get_tree().paused = false
	Settings.save()


func _on_volume_changed(value: float, is_music: bool) -> void:
	if is_music:
		Settings.music_volume = value
	else:
		Settings.sfx_volume = value
	Settings.apply()


func _on_quit() -> void:
	close()
	GameState.save_game()
	HUD.show_hud(false)
	SceneManager.go_to_title()
