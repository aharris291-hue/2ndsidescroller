class_name DarkUI
extends RefCounted
## Shared look for the dark rebuild's menus: slate panels edged in dried red, bone
## serif text, buttons that warm when focused.

const BONE := Color("e6dccb")
const ASH := Color("a89f8f")
const BLOOD := Color("7a231c")
const SERIF := preload("res://assets/fonts/LiberationSerif-Regular.ttf")
const SERIF_ITALIC := preload("res://assets/fonts/LiberationSerif-Italic.ttf")


static func button(text: String, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.09, 0.9)
	normal.border_color = Color("2e2420")
	normal.set_border_width_all(2)
	normal.set_content_margin_all(8)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.16, 0.08, 0.07, 0.95)
	focus.border_color = BLOOD
	focus.border_width_left = 6
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.05, 0.06, 0.8)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"disabled", disabled)
	for state in [&"hover", &"focus", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(state, focus)
	for state in [&"font_color", &"font_focus_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color("c8c0b0"))
	b.add_theme_color_override(&"font_disabled_color", Color("5e574e"))
	b.add_theme_color_override(&"font_hover_color", BONE)
	b.add_theme_color_override(&"font_pressed_color", BONE)
	b.add_theme_font_override(&"font", SERIF)
	b.add_theme_font_size_override(&"font_size", size)
	return b


static func label(text: String, size := 26, color := ASH, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_font_override(&"font", SERIF_ITALIC if italic else SERIF)
	l.add_theme_font_size_override(&"font_size", size)
	return l


## A full-screen dimmer with a centred panel of the given size; returns the panel's
## VBoxContainer to fill.
static func dialog(layer: CanvasLayer, size: Vector2) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_bottom = size.y / 2.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.06, 0.96)
	box.border_color = BLOOD
	box.set_border_width_all(2)
	box.border_width_top = 4
	box.set_content_margin_all(28)
	panel.add_theme_stylebox_override(&"panel", box)
	dim.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 14)
	panel.add_child(vbox)
	return vbox
