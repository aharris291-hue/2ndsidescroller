class_name BestiaryPanel
extends CanvasLayer
## Nell's bestiary, opened from the pause menu: a page for every kind of thing Patch
## has beaten (see Bestiary). Unbeaten kinds are blank pages. The weakness is filled
## in once Patch has beaten enough of them. The game is paused while it's open.

signal closed

## The open bestiary, if any.
static var current: BestiaryPanel

var _list: VBoxContainer
var _art: TextureRect
var _title: Label
var _count: Label
var _note: Label
var _tell: Label
var _weak: Label
var _close: Button


static func open_panel(parent: Node) -> BestiaryPanel:
	var panel := BestiaryPanel.new()
	parent.add_child(panel)
	return panel


func _ready() -> void:
	current = self
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var box := DarkUI.dialog(self, Vector2(1320, 820))
	box.add_child(DarkUI.label("Nell's bestiary", 40, DarkUI.BONE))
	box.add_child(DarkUI.label("A school exercise book with a wet-wrinkled cover. Nell has written PRIVATE on it, and then, underneath, smaller: except Patch.", 22, DarkUI.ASH, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = 340
	_list.add_theme_constant_override(&"separation", 6)
	row.add_child(_list)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 12)
	row.add_child(page)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 20)
	page.add_child(top)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(220, 220)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_art)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	_title = DarkUI.label("", 34, DarkUI.BONE)
	heading.add_child(_title)
	_count = DarkUI.label("", 22, DarkUI.ASH)
	heading.add_child(_count)
	_weak = DarkUI.label("", 22, DarkUI.BONE)
	heading.add_child(_weak)
	_note = DarkUI.label("", 24, DarkUI.BONE, true)
	page.add_child(_note)
	_tell = DarkUI.label("", 22, DarkUI.ASH)
	page.add_child(_tell)
	_close = DarkUI.button("Close the book")
	_close.pressed.connect(close)
	box.add_child(_close)
	var first := ""
	for enemy_id: String in Bestiary.ORDER:
		var seen := Bestiary.count(enemy_id) > 0
		var b := DarkUI.button(Bestiary.entry(enemy_id)["name"] if seen else "(a blank page)", 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not seen
		b.focus_entered.connect(show_entry.bind(enemy_id))
		b.pressed.connect(show_entry.bind(enemy_id))
		_list.add_child(b)
		if seen and first.is_empty():
			first = enemy_id
	if first.is_empty():
		show_blank()
		_close.grab_focus.call_deferred()
	else:
		show_entry(first)
		_list.get_child(Bestiary.ORDER.find(first)).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if current == self:
		current = null
	get_tree().paused = false
	closed.emit()
	queue_free()


func show_blank() -> void:
	_art.texture = null
	_title.text = "Nothing yet"
	_count.text = ""
	_weak.text = ""
	_note.text = "The pages are ruled and empty. Nell is waiting to see what Patch meets."
	_tell.text = ""


func show_entry(enemy_id: String) -> void:
	var entry := Bestiary.entry(enemy_id)
	var times := Bestiary.count(enemy_id)
	if entry.is_empty() or times == 0:
		show_blank()
		return
	_art.texture = load(entry["art"]) as Texture2D
	_art.self_modulate = entry.get("tint", Color.WHITE)
	_title.text = entry["name"]
	_count.text = "Beaten %d time%s" % [times, "" if times == 1 else "s"]
	var weak: int = entry.get("weak", -1)
	if weak < 0:
		_weak.text = ""
	elif Bestiary.weakness_known(enemy_id):
		_weak.text = "Weak to the shears as the %s" % ShearForms.display_name(weak)
	else:
		_weak.text = "Weak to: (beat %d more to find out)" % (Bestiary.REVEAL_AFTER - times)
	_note.text = "\"%s\"" % entry["note"]
	_tell.text = entry["tell"]
