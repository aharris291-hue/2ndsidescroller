extends Control
## Title screen with three save slots. An empty slot starts a new game;
## a used slot continues from its last bookmark.

const TITLE_MUSIC := preload("res://assets/audio/dark/mus_drowned.ogg")
const PATCH_TEXTURE := preload("res://assets/art/dark/patch.png")
const SOGG_TEXTURE := preload("res://assets/art/dark/sogg.png")
const SERIF := preload("res://assets/fonts/LiberationSerif-Regular.ttf")
const SERIF_ITALIC := preload("res://assets/fonts/LiberationSerif-Italic.ttf")
const BONE := Color("d8d0c0")
const BLOOD := Color("7a1f1a")
const COMBAT_LAB := "res://scenes/levels/combat_lab/combat_lab.tscn"

@onready var slot_buttons: Array[Button] = [
	$Center/VBox/Slots/Slot1, $Center/VBox/Slots/Slot2, $Center/VBox/Slots/Slot3,
]
@onready var erase_toggle: CheckButton = $Center/VBox/EraseToggle
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var title_label: Label = $Center/VBox/Title
@onready var subtitle_label: Label = $Center/VBox/Subtitle

## The title is set in the drowned world, not on the open book.
var in_book := false


func _ready() -> void:
	GameState.in_gameplay = false
	HUD.show_hud(false)
	# The menu sits above the weather (rain, fog and grain are on layers 2 and 3).
	var center: Control = $Center
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 6
	add_child(menu_layer)
	center.reparent(menu_layer)
	var atmosphere := DarkAtmosphere.new()
	atmosphere.rain_amount = 300
	add_child(atmosphere)
	_style_menu()
	AudioManager.play_music(TITLE_MUSIC)
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i))
	erase_toggle.toggled.connect(func(_on: bool) -> void: _refresh_slots())
	quit_button.pressed.connect(get_tree().quit)
	_add_lab_button()
	_add_options_button()
	for button in center.find_children("*", "BaseButton", true, false):
		_style_button(button)
	_refresh_slots()
	_add_cast()
	slot_buttons[0].grab_focus()
	# The menu surfaces slowly out of the dark.
	center.modulate.a = 0.0
	create_tween().tween_property(center, "modulate:a", 1.0, 1.8).set_delay(0.4)


## Bone-white serif title over the rain; menu buttons are dark slates edged in
## dried red that warm when focused.
func _style_menu() -> void:
	var title_font := FontVariation.new()
	title_font.base_font = SERIF
	title_font.spacing_glyph = 22
	title_label.text = "PATCH"
	title_label.theme_type_variation = &""
	title_label.add_theme_font_override(&"font", title_font)
	title_label.add_theme_font_size_override(&"font_size", 168)
	title_label.add_theme_color_override(&"font_color", BONE)
	title_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override(&"shadow_offset_x", 0)
	title_label.add_theme_constant_override(&"shadow_offset_y", 6)
	title_label.add_theme_constant_override(&"shadow_outline_size", 18)
	subtitle_label.text = "and the Pop-Up Kingdom"
	subtitle_label.add_theme_font_override(&"font", SERIF_ITALIC)
	subtitle_label.add_theme_font_size_override(&"font_size", 46)
	subtitle_label.add_theme_color_override(&"font_color", Color("a89f8f"))
	subtitle_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	subtitle_label.add_theme_constant_override(&"shadow_outline_size", 10)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	subtitle_label.add_sibling(spacer)


func _style_button(button: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.06, 0.07, 0.78)
	normal.border_color = Color("2e2420")
	normal.set_border_width_all(2)
	normal.set_content_margin_all(10)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.14, 0.07, 0.06, 0.88)
	focus.border_color = BLOOD
	focus.border_width_left = 6
	for state in [&"normal", &"disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in [&"hover", &"focus", &"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, focus)
	for state in [&"font_color", &"font_focus_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("b8b0a0"))
	button.add_theme_color_override(&"font_hover_color", BONE)
	button.add_theme_color_override(&"font_pressed_color", BONE)
	button.add_theme_font_override(&"font", SERIF)
	button.add_theme_font_size_override(&"font_size", 30)


## The painted Patch on the left, lantern in the rain; the Sogg looms in the fog on
## the right, waiting. They're under the weather, the menu is above it.
func _add_cast() -> void:
	var patch := _cast_sprite(PATCH_TEXTURE, Vector2(330, 860), 0.95)
	var lantern := PointLight2D.new()
	lantern.texture = _glow_texture()
	lantern.texture_scale = 4.0
	lantern.color = Color(1.0, 0.76, 0.48)
	lantern.energy = 1.1
	lantern.position = Vector2(40, -40)
	patch.add_child(lantern)
	var sogg := _cast_sprite(SOGG_TEXTURE, Vector2(1620, 760), 1.25)
	sogg.modulate = Color(0.55, 0.58, 0.66, 0.85)
	# Patch breathes; the Sogg sways, slow and heavy.
	var breathe := create_tween().set_loops()
	breathe.tween_property(patch, "scale:y", 0.95 * 1.015, 1.4).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(patch, "scale:y", 0.95, 1.4).set_trans(Tween.TRANS_SINE)
	var sway := create_tween().set_loops()
	sway.tween_property(sogg, "rotation", 0.03, 2.6).set_trans(Tween.TRANS_SINE)
	sway.tween_property(sogg, "rotation", -0.03, 2.6).set_trans(Tween.TRANS_SINE)


func _glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	return texture


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
			var printing := int(data.get("printing", 0))
			if printing > 0:
				done += " - %s Printing" % SecondPrinting.ordinal(printing)
			slot_buttons[i].text = "%sBook %d  -  %s played, %d/%d letters%s" % [
				prefix, i + 1, GameState.format_time(data.get("play_time", 0.0)), letters, GameState.LETTER_TOTAL, done]


## The Combat Lab: a practice page for the new combat. It never touches a save slot.
func _add_lab_button() -> void:
	var lab := Button.new()
	lab.name = "LabButton"
	lab.text = "Combat Lab (practice)"
	lab.custom_minimum_size = Vector2(720, 56)
	lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vbox := erase_toggle.get_parent()
	vbox.add_child(lab)
	vbox.move_child(lab, erase_toggle.get_index())
	lab.pressed.connect(func() -> void:
		if SceneManager.is_transitioning:
			return
		GameState.new_game(0)
		GameState.sandbox = true
		SceneManager.change_page(COMBAT_LAB))


## Controls, accessibility and assists, before starting (OptionsPanel).
func _add_options_button() -> void:
	var options := Button.new()
	options.name = "OptionsButton"
	options.text = "Controls and accessibility"
	options.custom_minimum_size = Vector2(720, 56)
	options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vbox := erase_toggle.get_parent()
	vbox.add_child(options)
	vbox.move_child(options, erase_toggle.get_index())
	options.pressed.connect(func() -> void:
		var panel := OptionsPanel.open_panel(self)
		panel.closed.connect(options.grab_focus.call_deferred))


func _on_slot_pressed(slot: int) -> void:
	if SceneManager.is_transitioning:
		return
	if erase_toggle.button_pressed:
		GameState.delete_save(slot)
		erase_toggle.button_pressed = false
		_refresh_slots()
		return
	if SecondPrinting.available(GameState.read_save(slot)):
		var panel := SecondPrinting.PrintingPanel.open(self, slot)
		panel.closed.connect(slot_buttons[slot].grab_focus.call_deferred)
		return
	if GameState.load_game(slot):
		SceneManager.change_page_at(GameState.checkpoint_page, GameState.checkpoint_position)
	else:
		GameState.new_game(slot)
		SceneManager.change_page(GameState.FIRST_PAGE)
