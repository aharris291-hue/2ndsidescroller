extends Control
## Title screen with three save slots. An empty slot starts a new game;
## a used slot continues from its last bookmark.

const TITLE_MUSIC := preload("res://assets/audio/music/foldwick_lullaby.wav")
const PATCH_TEXTURE := preload("res://assets/art/characters/patch.png")
const PATCH_MENDED_TEXTURE := preload("res://assets/art/characters/patch_mended.png")
const DOT_TEXTURE := preload("res://assets/art/characters/dot.png")
const SOGGY_TEXTURE := preload("res://assets/art/characters/soggy.png")

@onready var slot_buttons: Array[Button] = [
	$Center/VBox/Slots/Slot1, $Center/VBox/Slots/Slot2, $Center/VBox/Slots/Slot3,
]
@onready var erase_toggle: CheckButton = $Center/VBox/EraseToggle
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var title_label: Label = $Center/VBox/Title


func _ready() -> void:
	GameState.in_gameplay = false
	HUD.show_hud(false)
	# The menu floats above the open book (BookFrame), so buttons stay flat and
	# line up with the mouse; only the illustration is drawn onto the page.
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 6
	add_child(menu_layer)
	$Center.reparent(menu_layer)
	title_label.add_theme_color_override(&"font_color", Color("281e2e"))
	title_label.add_theme_color_override(&"font_outline_color", Color("fff8e2"))
	title_label.add_theme_constant_override(&"outline_size", 22)
	AudioManager.play_music(TITLE_MUSIC)
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i))
	erase_toggle.toggled.connect(func(_on: bool) -> void: _refresh_slots())
	quit_button.pressed.connect(get_tree().quit)
	_refresh_slots()
	_add_cast()
	slot_buttons[0].grab_focus()
	# A gentle paper sway on the title.
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "rotation", 0.02, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "rotation", -0.02, 1.6).set_trans(Tween.TRANS_SINE)


## Patch and Dot on the meadow, with a Soggy lurking on the far page. They're drawn
## onto the page itself, under the menu. Once any book has been finished, Patch wears
## his new tail here too.
func _add_cast() -> void:
	var finished := false
	for i in slot_buttons.size():
		if GameState.read_save(i).get("flags", {}).get("game_complete", false):
			finished = true
	var patch := _cast_sprite(PATCH_MENDED_TEXTURE if finished else PATCH_TEXTURE, Vector2(300, 790), 0.8)
	patch.hframes = 5
	_cast_sprite(DOT_TEXTURE, Vector2(430, 850), 0.6)
	var soggy := _cast_sprite(SOGGY_TEXTURE, Vector2(1640, 820), 0.6)
	soggy.flip_h = true
	soggy.modulate = Color(1, 1, 1, 0.92)
	# Patch bobs proudly; the Soggy sways, waiting.
	var bob := create_tween().set_loops()
	bob.tween_property(patch, "position:y", patch.position.y - 10.0, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(patch, "position:y", patch.position.y, 0.7).set_trans(Tween.TRANS_SINE)
	var sway := create_tween().set_loops()
	sway.tween_property(soggy, "rotation", 0.08, 1.3).set_trans(Tween.TRANS_SINE)
	sway.tween_property(soggy, "rotation", -0.08, 1.3).set_trans(Tween.TRANS_SINE)


func _cast_sprite(texture: Texture2D, at: Vector2, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2(size, size)
	add_child(sprite)
	return sprite


func _refresh_slots() -> void:
	for i in slot_buttons.size():
		var data := GameState.read_save(i)
		if data.is_empty():
			slot_buttons[i].text = "Book %d  -  New story" % (i + 1)
		else:
			var prefix := "Erase " if erase_toggle.button_pressed else ""
			var letters: int = data.get("letters", []).size()
			var done := " - The End" if data.get("flags", {}).get("game_complete", false) else ""
			slot_buttons[i].text = "%sBook %d  -  %s played, %d/%d letters%s" % [
				prefix, i + 1, GameState.format_time(data.get("play_time", 0.0)), letters, GameState.LETTER_TOTAL, done]


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
