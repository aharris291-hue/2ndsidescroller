class_name PaperRack
extends Interactable
## Gran's drying rack in the Spine: the papers Patch can be reprinted on (Papers).
## Usable once the book is finished; each paper on it is earned by a post-game feat.

const ART := preload("res://assets/art/dark/props/paper_rack.png")

var _panel: CanvasLayer


func _init() -> void:
	prompt_text = "Look through Gran's papers"
	prompt_offset = Vector2(0, -250)
	collision_layer = 32
	collision_mask = 2


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 200)
	shape.shape = rect
	shape.position = Vector2(0, -100)
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.position = Vector2(0, -ART.get_height() / 2.0 + 4.0)
	add_child(sprite)
	super._ready()


func _process(delta: float) -> void:
	visible = GameState.get_flag("game_complete")
	super._process(delta)


func can_interact() -> bool:
	return visible and not is_instance_valid(_panel) and not SceneManager.is_transitioning


func interact(player: Patch) -> void:
	var fresh := Papers.refresh()
	if not GameState.get_flag("paper_rack_seen"):
		GameState.set_flag("paper_rack_seen")
		DialogueUI.narrate("Gran's drying rack. She used to peg her good papers on it to flatten, and never took them down. Hold one up to the lamp and the fox in it was him, printed on something else.")
	elif not fresh.is_empty():
		DialogueUI.narrate("A new sheet on the rack: %s." % ", ".join(fresh.map(func(id: String) -> String: return Papers.entry(id)["name"])))
	GameState.save_game()
	AudioManager.play_sfx(&"rustle")
	_panel = RackPanel.open(get_tree().root, player)


## The list of papers: earned ones can be worn, the rest say how they're earned.
class RackPanel extends CanvasLayer:
	var player: Patch

	static func open(parent: Node, who: Patch) -> RackPanel:
		var panel := RackPanel.new()
		panel.player = who
		parent.add_child(panel)
		return panel

	func _ready() -> void:
		layer = 32
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var box := DarkUI.dialog(self, Vector2(1060, 760))
		box.add_child(DarkUI.label("Gran's papers", 40, DarkUI.BONE))
		var first: Control = null
		var worn := Papers.worn()
		for p: Dictionary in Papers.CATALOG:
			var id: String = p["id"]
			var text: String
			if Papers.owned(id):
				text = "%s%s: %s" % [p["name"], "  (wearing)" if id == worn else "", p["note"]]
			else:
				text = "A sheet still in its wrapper: %s" % p["how"]
			var b := DarkUI.button(text, 21)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.disabled = not Papers.owned(id)
			b.pressed.connect(_wear.bind(id))
			box.add_child(b)
			if first == null and id == worn:
				first = b
		var leave := DarkUI.button("Leave the rack")
		leave.pressed.connect(close)
		box.add_child(leave)
		(first if first else leave).grab_focus.call_deferred()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()

	func _wear(id: String) -> void:
		if Papers.wear(id) and is_instance_valid(player):
			player.rig.set_paper(id)
			AudioManager.play_sfx(&"page_flip", 0.6)
		GameState.save_game()
		close()

	func close() -> void:
		get_tree().paused = false
		queue_free()
