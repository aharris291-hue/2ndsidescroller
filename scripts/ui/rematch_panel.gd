class_name RematchPanel
extends CanvasLayer
## Gran's proof press: pick a boss whose page is mended and fight it again (Rematch).
## Each row shows the best sticker and time from the ledger. The game is paused
## while it's open.

signal closed

var _list: VBoxContainer
var _close: Button


static func open_panel(parent: Node) -> RematchPanel:
	var panel := RematchPanel.new()
	parent.add_child(panel)
	return panel


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var box := DarkUI.dialog(self, Vector2(980, 700))
	box.add_child(DarkUI.label("Gran's proof press", 40, DarkUI.BONE))
	box.add_child(DarkUI.label("She pulled a proof of every page before it went to the binder, and kept them. A proof is the page as it was. Pull one, and whatever was on it is there again, and the ink has had time to think.", 22, DarkUI.ASH, true))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 8)
	box.add_child(_list)
	box.add_child(DarkUI.label("Stickers: Gilt (no hits, under par), Silver, Copper, Paper. After its health runs out each boss comes back inked.", 20, DarkUI.ASH, true))
	_close = DarkUI.button("Leave the press")
	_close.pressed.connect(close)
	box.add_child(_close)
	var first: Control = _close
	for b: Dictionary in Rematch.BOSSES:
		var row := DarkUI.button(row_text(b["id"]), 22)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.disabled = not Rematch.unlocked(b["id"])
		row.pressed.connect(_pull.bind(b["id"]))
		var rank := Rematch.best_rank(b["id"])
		if rank > 0:
			row.add_theme_color_override(&"font_color", Rematch.STICKER_COLORS[rank])
		_list.add_child(row)
		if first == _close and not row.disabled:
			first = row
	first.grab_focus.call_deferred()


## "Old Millwheel   Silver sticker, best 1:42" or the locked line.
static func row_text(id: String) -> String:
	var b := Rematch.entry(id)
	if not Rematch.unlocked(id):
		return "(a page not mended yet)"
	var rank := Rematch.best_rank(id)
	if rank == 0:
		return "%s   no sticker yet" % b["name"]
	return "%s   %s sticker, best %s" % [b["name"], Rematch.STICKERS[rank], Rematch.clock(Rematch.best_time(id))]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _pull(id: String) -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
	AudioManager.play_sfx(&"page_flip", 0.6)
	Rematch.start(id)


func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
