class_name LabTrials
extends Node2D
## Combat Lab challenges (post-game): a walled trial floor at the far end of the
## Combat Lab, with a board of six trials. Each one sets a goal against set enemies
## (clear them, parry, dodge, reach a style rank), fails if Patch is torn down to his
## last point (or, for Clean Cut, hit at all) or the clock runs out, and gives a medal
## by time. The lab saves nothing to a save slot, so the best medals and times live in
## their own file (RECORDS_PATH) and are shared by every slot and the title screen.

signal finished(won: bool)

const RECORDS_PATH := "user://lab_records.json"
## The trial floor: the gate drops at FLOOR_LEFT behind Patch; the page ends at the right.
const FLOOR_LEFT := 7360.0
const FLOOR_RIGHT := 8900.0
const GROUND_Y := 960.0
const START := Vector2(7560, 900)
const TIME_LIMIT := 120.0
const MEDALS: Array[String] = ["", "Bronze", "Silver", "Gold"]
const MEDAL_COLORS: Array[Color] = [Color(0.4, 0.4, 0.42), Color(0.72, 0.46, 0.3),
	Color(0.78, 0.8, 0.84), Color(0.92, 0.76, 0.36)]
const SCENES := {
	"soggy": "res://scenes/enemies/soggy.tscn",
	"moth": "res://scenes/enemies/paper_moth.tscn",
	"crane": "res://scenes/enemies/folded_crane.tscn",
	"knight": "res://scenes/enemies/tack_knight.tscn",
}
## goal: "clear" (every wave), "parries", "dodges" (perfect dodges) or "style" (rank).
## waves: lists of [kind, count, inked]. refill: the wave comes back when it's gone.
## medals: [silver time, gold time] in seconds; any finish is bronze.
const TRIALS := [
	{"id": "clean_cut", "name": "Clean Cut", "goal": "clear", "no_hits": true,
		"text": "Four Soggies. Don't let one touch you.",
		"waves": [[["soggy", 4, false]]], "medals": [30.0, 18.0]},
	{"id": "glint", "name": "The Glint", "goal": "parries", "target": 5, "refill": true,
		"text": "Parry five blows. They glint before they lunge.",
		"waves": [[["soggy", 3, false]]], "medals": [40.0, 22.0]},
	{"id": "edge_on", "name": "Edge-On", "goal": "dodges", "target": 3, "refill": true,
		"text": "Three perfect dodges. The cranes glow red, then dive.",
		"waves": [[["crane", 2, false]]], "medals": [45.0, 26.0]},
	{"id": "moth_season", "name": "Moth Season", "goal": "clear",
		"text": "Two swarms of paper moths. Quick cuts.",
		"waves": [[["moth", 4, false]], [["moth", 5, false]]], "medals": [40.0, 24.0]},
	{"id": "inked", "name": "Inked", "goal": "clear",
		"text": "Two inked Soggies, then an inked Tack Knight.",
		"waves": [[["soggy", 2, true]], [["knight", 1, true]]], "medals": [60.0, 36.0]},
	{"id": "grans_hand", "name": "Gran's Hand", "goal": "style", "target": 5, "refill": true,
		"text": "Fight until the style meter reads Gran's Hand. Vary your cuts.",
		"waves": [[["soggy", 3, false], ["knight", 1, false]]], "medals": [70.0, 40.0]},
]

var active: Dictionary = {}
var elapsed := 0.0
var progress := 0
var won := false
var _wave := 0
var _alive: Array[Node] = []
var _gate: StaticBody2D
var _gate_art: ColorRect
var _label: Label
var _layer: CanvasLayer
var _patch: Node2D


# --- Records ---------------------------------------------------------------------

static func records() -> Dictionary:
	if not FileAccess.file_exists(RECORDS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	return parsed if parsed is Dictionary else {}


static func best(id: String) -> Dictionary:
	var r: Variant = records().get(id, {})
	return r if r is Dictionary else {}


## Keeps the better medal, and the better time at that medal or above.
static func record(id: String, medal: int, seconds: float) -> bool:
	var all := records()
	var old: Dictionary = all.get(id, {}) if all.get(id) is Dictionary else {}
	var old_medal := int(old.get("medal", 0))
	var better := medal > old_medal or (medal == old_medal and seconds < float(old.get("time", INF)))
	if better:
		all[id] = {"medal": medal, "time": seconds}
		var file := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(all))
	return better


static func medal_for(trial: Dictionary, seconds: float) -> int:
	var times: Array = trial["medals"]
	if seconds <= float(times[1]):
		return 3
	if seconds <= float(times[0]):
		return 2
	return 1


static func trial(id: String) -> Dictionary:
	for t: Dictionary in TRIALS:
		if t["id"] == id:
			return t
	return {}


# --- The floor -------------------------------------------------------------------

func _ready() -> void:
	name = &"LabTrials"
	_gate = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 1200)
	shape.shape = rect
	_gate.add_child(shape)
	_gate.position = Vector2(FLOOR_LEFT, GROUND_Y - 600.0)
	add_child(_gate)
	_gate_art = ColorRect.new()
	_gate_art.color = Color(0.32, 0.08, 0.07, 0.85)
	_gate_art.size = Vector2(16, 1100)
	_gate_art.position = Vector2(FLOOR_LEFT - 8.0, GROUND_Y - 1100.0)
	add_child(_gate_art)
	_set_gate(false)
	var board := TrialBoard.new()
	board.trials = self
	board.position = Vector2(FLOOR_LEFT - 200.0, GROUND_Y)
	add_child(board)
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_label = DarkUI.label("", 30, DarkUI.BONE)
	_label.position = Vector2(40, 150)
	_label.size = Vector2(900, 120)
	_label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.05))
	_label.add_theme_constant_override(&"outline_size", 6)
	_layer.add_child(_label)
	EventBus.player_parried.connect(func() -> void: _count("parries"))
	EventBus.player_perfect_dodge.connect(func() -> void: _count("dodges"))
	EventBus.style_changed.connect(func(rank: int, _fill: float) -> void:
		if not active.is_empty() and active["goal"] == "style":
			progress = maxi(progress, rank))


func _set_gate(closed: bool) -> void:
	(_gate.get_child(0) as CollisionShape2D).set_deferred(&"disabled", not closed)
	_gate_art.visible = closed


func running() -> bool:
	return not active.is_empty()


func start(id: String) -> bool:
	var t := trial(id)
	if t.is_empty() or running():
		return false
	_patch = get_tree().get_first_node_in_group(&"player") as Node2D
	if _patch == null:
		return false
	active = t
	elapsed = 0.0
	progress = 0
	won = false
	_wave = 0
	_patch.global_position = START
	_patch.set(&"velocity", Vector2.ZERO)
	var health := _patch.get(&"health") as HealthComponent
	health.max_health = GameState.max_health
	health.set_health(health.max_health)
	health.floor_health = 1
	health.damaged.connect(_on_hurt)
	_set_gate(true)
	_spawn_wave()
	AudioManager.play_sfx(&"page_flip", 0.7)
	_update_label()
	return true


func _physics_process(delta: float) -> void:
	if not running():
		return
	elapsed += delta
	_alive = _alive.filter(func(n: Node) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion())
	if _alive.is_empty():
		if active["goal"] == "clear":
			_wave += 1
			if _wave >= (active["waves"] as Array).size():
				_end(true)
				return
		_spawn_wave()
	var target := int(active.get("target", 0))
	if active["goal"] != "clear" and progress >= target:
		_end(true)
		return
	if elapsed >= TIME_LIMIT:
		_end(false, "Out of time.")
		return
	_update_label()


func _spawn_wave() -> void:
	var waves: Array = active["waves"]
	var wave: Array = waves[mini(_wave, waves.size() - 1)]
	var i := 0
	for group: Array in wave:
		for n in int(group[1]):
			var enemy := (load(SCENES[group[0]]) as PackedScene).instantiate() as Node2D
			var x := lerpf(FLOOR_LEFT + 700.0, FLOOR_RIGHT - 150.0, fmod(i * 0.37 + 0.1, 1.0))
			var y := GROUND_Y - 60.0
			if group[0] == "moth":
				y = GROUND_Y - 320.0 - (i % 3) * 60.0
			elif group[0] == "crane":
				y = GROUND_Y - 420.0
			enemy.position = Vector2(x, y)
			enemy.set(&"scrap_drop", 0)
			if group[2]:
				enemy.set(&"inked", true)
			enemy.add_to_group(&"lab_trial_enemies")
			get_parent().add_child(enemy)
			_alive.append(enemy)
			i += 1


func _count(goal: String) -> void:
	if running() and active["goal"] == goal:
		progress += 1


func _on_hurt(_amount: int, _from: Vector2) -> void:
	if not running():
		return
	if active.get("no_hits", false):
		_end.call_deferred(false, "Touched.")
		return
	var health := _patch.get(&"health") as HealthComponent
	if health.current <= 1:
		_end.call_deferred(false, "Torn to the last thread.")


func _update_label() -> void:
	var goal := ""
	match active["goal"]:
		"clear":
			goal = "wave %d/%d" % [_wave + 1, (active["waves"] as Array).size()]
		"parries":
			goal = "parries %d/%d" % [progress, active["target"]]
		"dodges":
			goal = "perfect dodges %d/%d" % [progress, active["target"]]
		"style":
			goal = "style %s" % StyleMeter.RANKS[mini(progress, StyleMeter.RANKS.size() - 1)]
	_label.text = "%s   %s   %s\n%s" % [active["name"], Rematch.clock(elapsed), goal, active["text"]]


func _end(success: bool, why := "") -> void:
	if not running():
		return
	var t := active
	active = {}
	won = success
	for node in get_tree().get_nodes_in_group(&"lab_trial_enemies"):
		node.queue_free()
	_alive.clear()
	var health := _patch.get(&"health") as HealthComponent
	if is_instance_valid(health):
		health.floor_health = 0
		if health.damaged.is_connected(_on_hurt):
			health.damaged.disconnect(_on_hurt)
		health.set_health(health.max_health)
	_set_gate(false)
	_label.text = ""
	var medal := medal_for(t, elapsed) if success else 0
	var new_best := success and record(t["id"], medal, elapsed)
	AudioManager.play_sfx(&"checkpoint" if success else &"hurt", 1.0)
	_card(t, medal, why, new_best)
	finished.emit(success)


func _card(t: Dictionary, medal: int, why: String, new_best: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var box := DarkUI.dialog(layer, Vector2(720, 240))
	box.add_child(DarkUI.label(t["name"], 34, DarkUI.BONE))
	if medal > 0:
		box.add_child(DarkUI.label("%s, in %s" % [MEDALS[medal], Rematch.clock(elapsed)], 40, MEDAL_COLORS[medal]))
		box.add_child(DarkUI.label("A new best." if new_best else "Your best stands.", 22, DarkUI.ASH, true))
	else:
		box.add_child(DarkUI.label("Failed. %s" % why, 34, DarkUI.ASH))
	get_tree().create_timer(2.6, false).timeout.connect(layer.queue_free)


## The board beside the trial floor's gate.
class TrialBoard extends Interactable:
	var trials: LabTrials
	var _panel: CanvasLayer

	func _init() -> void:
		prompt_text = "Read the trial board"
		prompt_offset = Vector2(0, -260)
		collision_layer = 32
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(200, 200)
		shape.shape = rect
		shape.position = Vector2(0, -100)
		add_child(shape)
		var post := ColorRect.new()
		post.color = Color(0.16, 0.12, 0.1)
		post.size = Vector2(14, 200)
		post.position = Vector2(-7, -200)
		add_child(post)
		var card := ColorRect.new()
		card.color = Color(0.09, 0.08, 0.1)
		card.size = Vector2(150, 110)
		card.position = Vector2(-75, -230)
		add_child(card)
		var edge := ReferenceRect.new()
		edge.border_color = DarkUI.BLOOD
		edge.border_width = 3.0
		edge.editor_only = false
		edge.size = card.size
		card.add_child(edge)
		var title := DarkUI.label("TRIALS", 26, DarkUI.BONE)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size = Vector2(150, 40)
		title.position = Vector2(0, 34)
		card.add_child(title)
		super._ready()

	func can_interact() -> bool:
		return not trials.running() and not is_instance_valid(_panel)

	func interact(_player: Patch) -> void:
		_panel = TrialPanel.open(get_tree().root, trials)


## The list of trials, with each one's best medal and time.
class TrialPanel extends CanvasLayer:
	var trials: LabTrials

	static func open(parent: Node, with: LabTrials) -> TrialPanel:
		var panel := TrialPanel.new()
		panel.trials = with
		parent.add_child(panel)
		return panel

	func _ready() -> void:
		layer = 32
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var box := DarkUI.dialog(self, Vector2(980, 640))
		box.add_child(DarkUI.label("Trials", 40, DarkUI.BONE))
		box.add_child(DarkUI.label("The gate drops behind you. Torn to your last point, you fail. Any finish is Bronze; fast ones are Silver and Gold. Bests are kept for every save.", 22, DarkUI.ASH, true))
		var first: Control = null
		for t: Dictionary in LabTrials.TRIALS:
			var b := DarkUI.button(row_text(t["id"]), 22)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var rec := LabTrials.best(t["id"])
			if int(rec.get("medal", 0)) > 0:
				b.add_theme_color_override(&"font_color", LabTrials.MEDAL_COLORS[int(rec["medal"])])
			b.pressed.connect(_pick.bind(t["id"]))
			box.add_child(b)
			if first == null:
				first = b
		var close_button := DarkUI.button("Leave the board")
		close_button.pressed.connect(close)
		box.add_child(close_button)
		first.grab_focus.call_deferred()

	static func row_text(id: String) -> String:
		var t := LabTrials.trial(id)
		var rec := LabTrials.best(id)
		var medal := int(rec.get("medal", 0))
		var best := "no medal yet" if medal == 0 else "%s, %s" % [LabTrials.MEDALS[medal], Rematch.clock(float(rec["time"]))]
		return "%s: %s   (%s)" % [t["name"], t["text"], best]

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()

	func _pick(id: String) -> void:
		close()
		trials.start(id)

	func close() -> void:
		get_tree().paused = false
		queue_free()
