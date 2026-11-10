class_name Arcade
extends RefCounted
## The minigame arcade (post-game): Gran's penny theatre in the Spine. Three shadow
## shows on the old puppet screen (ShadowTheater, each its own chart and tempo) and
## Flood Run, a paper boat down the drowned millrace (BoatRace). Each game keeps its
## best score in the flag "arcade:<id>" and its best rank in "arcade_rank:<id>", and
## pays scraps only for beating that best, so it can't be farmed.
##
## `play(id)` stores the game's settings in `pending` and turns to its page; the
## minigame calls `take()` in _ready to read them, and `finish(id, score, rank)` when
## it's over, which records the score and turns back to the theatre.

const HUB := "res://scenes/levels/hub/spine_hub.tscn"
## In front of the penny theatre on the Spine's ground floor.
const HUB_SPOT := Vector2(1088, 940)
const RANKS: Array[String] = ["", "Paper", "Copper", "Silver", "Gilt"]

## settings are set on the minigame's root before it starts.
const GAMES := [
	{"id": "waltz", "name": "The Drowned Waltz", "kind": "Shadow show",
		"scene": "res://scenes/minigames/shadow_theater.tscn",
		"settings": {"bpm": 104.0, "beats": 40, "chart_seed": 11}},
	{"id": "reel", "name": "The Lamplighters' Reel", "kind": "Shadow show",
		"scene": "res://scenes/minigames/shadow_theater.tscn",
		"settings": {"bpm": 128.0, "beats": 56, "chart_seed": 23, "travel_time": 1.6}},
	{"id": "long_night", "name": "The Long Night", "kind": "Shadow show",
		"scene": "res://scenes/minigames/shadow_theater.tscn",
		"settings": {"bpm": 148.0, "beats": 72, "chart_seed": 37, "travel_time": 1.4, "hit_window": 0.13}},
	{"id": "flood_run", "name": "Flood Run", "kind": "Paper boat",
		"scene": "res://scenes/minigames/flood_run.tscn", "settings": {}},
]

## The game being started: {"id", "settings"}; empty when a minigame is opened
## any other way.
static var pending: Dictionary = {}


static func game(id: String) -> Dictionary:
	for g: Dictionary in GAMES:
		if g["id"] == id:
			return g
	return {}


static func best(id: String) -> int:
	return int(GameState.get_flag("arcade:" + id, 0))


static func best_rank(id: String) -> int:
	return int(GameState.get_flag("arcade_rank:" + id, 0))


static func play(id: String) -> bool:
	var g := game(id)
	if g.is_empty() or SceneManager.is_transitioning:
		return false
	pending = {"id": id, "settings": g["settings"]}
	SceneManager.change_page(g["scene"])
	return true


## Called by a minigame in _ready: applies the arcade's settings to it and returns
## the game id ("" when it wasn't started from the arcade).
static func take(minigame: Node) -> String:
	if pending.is_empty():
		return ""
	var id: String = pending["id"]
	var settings: Dictionary = pending["settings"]
	for key: String in settings:
		minigame.set(key, settings[key])
	pending = {}
	return id


## Records a finished game. Returns the scraps paid (the amount the best went up by,
## over `per_scrap` points each).
static func record(id: String, score: int, rank: int, per_scrap := 1) -> int:
	var old := best(id)
	var paid := 0
	if score > old:
		paid = (score - old) / maxi(per_scrap, 1)
		GameState.set_flag("arcade:" + id, score)
		if paid > 0:
			GameState.add_scraps(paid)
	if rank > best_rank(id):
		GameState.set_flag("arcade_rank:" + id, rank)
	GameState.save_game()
	return paid


static func back_to_theatre() -> void:
	SceneManager.change_page_at(HUB, HUB_SPOT)


## The list of games, with each one's best.
class ArcadePanel extends CanvasLayer:
	static func open(parent: Node) -> ArcadePanel:
		var panel := ArcadePanel.new()
		parent.add_child(panel)
		return panel

	func _ready() -> void:
		layer = 32
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var box := DarkUI.dialog(self, Vector2(900, 520))
		box.add_child(DarkUI.label("Gran's penny theatre", 40, DarkUI.BONE))
		box.add_child(DarkUI.label("A penny a show. Scraps only for beating your best.", 22, DarkUI.ASH, true))
		var first: Control = null
		for g: Dictionary in Arcade.GAMES:
			var b := DarkUI.button(row_text(g["id"]), 24)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var rank := Arcade.best_rank(g["id"])
			if rank > 0:
				b.add_theme_color_override(&"font_color", Rematch.STICKER_COLORS[rank])
			b.pressed.connect(_pick.bind(g["id"]))
			box.add_child(b)
			if first == null:
				first = b
		var leave := DarkUI.button("Leave the theatre")
		leave.pressed.connect(close)
		box.add_child(leave)
		first.grab_focus.call_deferred()

	static func row_text(id: String) -> String:
		var g := Arcade.game(id)
		var rank := Arcade.best_rank(id)
		var best := "not played" if rank == 0 else "best %d, %s" % [Arcade.best(id), Arcade.RANKS[rank]]
		return "%s: %s   (%s)" % [g["kind"], g["name"], best]

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()

	func _pick(id: String) -> void:
		close()
		AudioManager.play_sfx(&"pickup", 0.6)
		Arcade.play(id)

	func close() -> void:
		get_tree().paused = false
		queue_free()
