extends Control
## Title screen with three save slots. An empty slot starts a new game;
## a used slot continues from its last bookmark.

const TITLE_MUSIC := preload("res://assets/audio/music/foldwick_lullaby.wav")

@onready var slot_buttons: Array[Button] = [
	$Center/VBox/Slots/Slot1, $Center/VBox/Slots/Slot2, $Center/VBox/Slots/Slot3,
]
@onready var erase_toggle: CheckButton = $Center/VBox/EraseToggle
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var title_label: Label = $Center/VBox/Title


func _ready() -> void:
	GameState.in_gameplay = false
	HUD.show_hud(false)
	AudioManager.play_music(TITLE_MUSIC)
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i))
	erase_toggle.toggled.connect(func(_on: bool) -> void: _refresh_slots())
	quit_button.pressed.connect(get_tree().quit)
	_refresh_slots()
	slot_buttons[0].grab_focus()
	# A gentle paper sway on the title.
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "rotation", 0.02, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "rotation", -0.02, 1.6).set_trans(Tween.TRANS_SINE)


func _refresh_slots() -> void:
	for i in slot_buttons.size():
		var data := GameState.read_save(i)
		if data.is_empty():
			slot_buttons[i].text = "Book %d  -  New story" % (i + 1)
		else:
			var prefix := "Erase " if erase_toggle.button_pressed else ""
			slot_buttons[i].text = "%sBook %d  -  %s played, %d scraps" % [
				prefix, i + 1, GameState.format_time(data.get("play_time", 0.0)), int(data.get("scraps", 0))]


func _on_slot_pressed(slot: int) -> void:
	if SceneManager.is_transitioning:
		return
	if erase_toggle.button_pressed:
		GameState.delete_save(slot)
		erase_toggle.button_pressed = false
		_refresh_slots()
		return
	if GameState.load_game(slot):
		SceneManager.change_page_at(GameState.checkpoint_page, GameState.checkpoint_position)
	else:
		GameState.new_game(slot)
		SceneManager.change_page(GameState.FIRST_PAGE)
