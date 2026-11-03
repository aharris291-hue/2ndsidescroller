class_name MapPanel
extends CanvasLayer
## The torn map: the book's regions as scraps of a page pinned around the Spine. A
## region is blank until Patch has been on one of its pages, inked once seen, and
## stitched in red once mended. Opened from a bookmark it also lists every bookmark
## Patch has touched, so he can travel to one. The game is paused while it's open.

signal closed

const MAP_SIZE := Vector2(820, 640)
const SPINE_SPOT := Vector2(0.5, 0.5)

## The open map, if any (only one at a time).
static var current: MapPanel

var travel := false
var _map: Control
var _close: Button


static func open_panel(parent: Node, travel_mode := false) -> MapPanel:
	var map := MapPanel.new()
	map.travel = travel_mode
	parent.add_child(map)
	return map


## "unknown", "seen" or "mended" for one region of BookMap.REGIONS.
static func region_state(entry: Dictionary) -> String:
	var flag: String = entry.get("mended_flag", "")
	if not flag.is_empty() and GameState.get_flag(flag):
		return "mended"
	for page_path: String in GameState.visited:
		for dir: String in entry.get("dirs", []):
			if page_path.begins_with(dir):
				return "seen"
	return "unknown"


## The known bookmarks, sorted by region then title, for the travel list.
static func travel_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in GameState.bookmarks:
		var mark: Dictionary = GameState.bookmarks[key]
		var entry := BookMap.region_of(mark["page"])
		var place: String = entry.get("name", "The Spine" if mark["page"] == BookMap.HUB else "The Margin")
		out.append({"key": key, "page": mark["page"], "position": Vector2(mark["x"], mark["y"]),
			"label": place if mark.get("title", "") in ["", place] else "%s: %s" % [place, mark["title"]]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"] < b["label"])
	return out


func _ready() -> void:
	current = self
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var box := DarkUI.dialog(self, Vector2(1480 if travel else 900, 860))
	box.add_child(DarkUI.label("The torn map" if not travel else "Travel by bookmark", 40, DarkUI.BONE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	box.add_child(row)
	_map = Control.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.draw.connect(_draw_map)
	row.add_child(_map)
	var buttons: Array[Button] = []
	if travel:
		var side := VBoxContainer.new()
		side.add_theme_constant_override(&"separation", 8)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(side)
		side.add_child(DarkUI.label("Bookmarks Patch has touched:", 22, DarkUI.ASH, true))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(500, 560)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		side.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for mark in travel_list():
			var here: bool = mark["page"] == GameState.current_page \
				and GameState.checkpoint_position.distance_to(mark["position"]) < 2.0
			var b := DarkUI.button(mark["label"] + ("   (here)" if here else ""), 22)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = here
			b.pressed.connect(go_to.bind(mark["page"], mark["position"]))
			list.add_child(b)
			buttons.append(b)
	_close = DarkUI.button("Fold the map away")
	_close.pressed.connect(close)
	box.add_child(_close)
	var first: Control = _close
	for b in buttons:
		if not b.disabled:
			first = b
			break
	first.grab_focus.call_deferred()


func _exit_tree() -> void:
	if current == self:
		current = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()


func go_to(page_path: String, position: Vector2) -> void:
	close()
	AudioManager.play_sfx(&"page_flip")
	SceneManager.change_page_at(page_path, position)


func _draw_map() -> void:
	var size := MAP_SIZE
	# The torn sheet itself: old paper gone grey, ragged at the edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var edge := PackedVector2Array()
	var steps := 48
	for i in steps:
		var t := float(i) / steps
		var p: Vector2
		if t < 0.25:
			p = Vector2(t * 4.0 * size.x, 0)
		elif t < 0.5:
			p = Vector2(size.x, (t - 0.25) * 4.0 * size.y)
		elif t < 0.75:
			p = Vector2(size.x - (t - 0.5) * 4.0 * size.x, size.y)
		else:
			p = Vector2(0, size.y - (t - 0.75) * 4.0 * size.y)
		edge.append(p + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)))
	_map.draw_colored_polygon(edge, Color("39332c"))
	_map.draw_polyline(edge + PackedVector2Array([edge[0]]), Color("1c1916"), 3.0)
	var font := DarkUI.SERIF
	var here := BookMap.region_of(GameState.current_page)
	var spine := SPINE_SPOT * size
	# Threads from the Spine out to each region.
	for entry: Dictionary in BookMap.REGIONS:
		if entry["id"] == &"prologue":
			continue
		var at: Vector2 = entry["spot"] * size
		var mended := region_state(entry) == "mended"
		_map.draw_dashed_line(spine, at, Color("7a231c") if mended else Color("5e574e"), 2.0, 10.0)
	_scrap(spine, Vector2(130, 70), Color("4a4038"), "The Spine", font, GameState.current_page == BookMap.HUB)
	for entry: Dictionary in BookMap.REGIONS:
		var at: Vector2 = entry["spot"] * size
		var s := region_state(entry)
		var colour := Color("26221e")
		var label := "?"
		if s == "seen":
			colour = Color("5a5046")
			label = entry["name"]
		elif s == "mended":
			colour = Color("a89f8f")
			label = entry["name"]
		_scrap(at, Vector2(170, 64), colour, label, font, here.get("id") == entry["id"], s == "mended")


func _scrap(at: Vector2, half: Vector2, colour: Color, label: String, font: Font,
		you_are_here := false, mended := false) -> void:
	var rect := Rect2(at - half / 2.0, half)
	_map.draw_rect(rect, colour)
	_map.draw_rect(rect, Color("15120f"), false, 2.0)
	if mended:
		# Red cross-stitches along the top and bottom: this page is sewn back in.
		var x := rect.position.x + 10.0
		while x < rect.end.x - 10.0:
			for y in [rect.position.y + 4.0, rect.end.y - 12.0]:
				_map.draw_line(Vector2(x, y), Vector2(x + 8, y + 8), Color("7a231c"), 2.0)
				_map.draw_line(Vector2(x + 8, y), Vector2(x, y + 8), Color("7a231c"), 2.0)
			x += 18.0
	var text_colour := Color("15120f") if mended else Color("c8c0b0")
	_map.draw_string(font, Vector2(rect.position.x, at.y + 8), label, HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x, 20, text_colour)
	if you_are_here:
		_map.draw_circle(Vector2(rect.end.x - 4, rect.position.y + 4), 9.0, Color("b0302a"))
		_map.draw_string(font, Vector2(rect.position.x, rect.end.y + 22), "you are here",
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color("e6dccb"))
