class_name TitleCard
extends CanvasLayer
## The place's name, written across the screen when Patch walks into a different part
## of the book (a region, the Spine, or out into the Margin). Fades in and out on its
## own and never blocks input.

const HOLD := 2.6

## Where Patch was last, so the card only shows when the place changes.
static var last_place := ""


## The place a page belongs to: {name, subtitle}, or {} for pages with no title card
## (cutscenes, the title, the ending).
static func place_of(page_path: String) -> Dictionary:
	if page_path == BookMap.HUB:
		return {"id": "spine", "name": "The Spine", "subtitle": "where every page is sewn"}
	if page_path.begins_with("res://scenes/levels/margin/"):
		return {"id": "margin", "name": "The Margin", "subtitle": "outside the book, at Gran's table"}
	var entry := BookMap.region_of(page_path)
	if entry.is_empty():
		return {}
	return {"id": String(entry["id"]), "name": entry["name"], "subtitle": entry.get("subtitle", "")}


## Shows the card if this page is in a different place from the last one.
static func on_page(page: Node) -> TitleCard:
	var place := place_of(page.scene_file_path)
	if place.is_empty():
		last_place = ""
		return null
	if place["id"] == last_place:
		return null
	last_place = place["id"]
	var card := TitleCard.new()
	card.name = &"TitleCard"
	card.place_name = place["name"]
	card.subtitle = place["subtitle"]
	page.add_child(card)
	return card


var place_name := ""
var subtitle := ""


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0
	add_child(root)
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.3
	box.anchor_bottom = 0.3
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var title := DarkUI.label(place_name, 96, DarkUI.BONE)
	title.name = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"outline_size", 14)
	title.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	box.add_child(title)
	# A stitched red rule under the name.
	var rule := Label.new()
	rule.text = "x  x  x  x  x  x  x  x  x"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_color_override(&"font_color", Color("9a2a22"))
	rule.add_theme_font_override(&"font", DarkUI.SERIF)
	rule.add_theme_font_size_override(&"font_size", 28)
	box.add_child(rule)
	if not subtitle.is_empty():
		var sub := DarkUI.label(subtitle, 34, DarkUI.ASH, true)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_constant_override(&"outline_size", 8)
		sub.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
		box.add_child(sub)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(root, "modulate:a", 1.0, 0.9)
	tween.tween_interval(HOLD)
	tween.tween_property(root, "modulate:a", 0.0, 1.2)
	tween.tween_callback(queue_free)
