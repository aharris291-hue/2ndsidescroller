extends Page
## 1-2 The Sheepfold. Fluff's pen is shut on its far side until it has been held for a
## night: walking into the pen (the "hold_the_fold" trigger) shuts the gate behind
## Patch too, and the Sogg sends three waves at the fold.
##   1. Soggies rise out of the flooded pen.
##   2. More Soggies, and Ink Spitters climb up onto the barn roof.
##   3. The "sheep" still standing in the pen throw off their wool, and an Inked Soggy
##      comes over the wall.
## Beating all three opens both gates for good ("sheepfold_held") and Fluff speaks.
## If Patch is torn mid-fight the page reloads and the night starts again.

const SOGGY := preload("res://scenes/enemies/soggy.tscn")
const SPITTER := preload("res://scenes/enemies/ink_spitter.tscn")
const HELD_FLAG := "sheepfold_held"
const PEN_LEFT := 88 * 64.0
const PEN_RIGHT := 128 * 64.0
const FLOOR_Y := 20 * 64.0
const ROOF_Y := 15 * 64.0

var wave := 0
var _alive := 0
var _running := false
var _west: Node2D
var _east: Node2D


func _ready() -> void:
	super._ready()
	var level := get_node(^"Level")
	for child in level.get_children():
		if String(child.name).begins_with("wave_gate"):
			if child.position.x < PEN_LEFT:
				_west = child
			else:
				_east = child
	var held: bool = GameState.get_flag(HELD_FLAG)
	_set_gate(_west, false, true)
	_set_gate(_east, not held, true)


func is_running() -> bool:
	return _running


## The story trigger at the pen's mouth.
func hold_the_fold() -> void:
	if _running or GameState.get_flag(HELD_FLAG):
		return
	_running = true
	_set_gate(_west, true)
	AudioManager.play_sfx(&"slam", 0.7)
	DialogueUI.narrate("Behind him, Fluff dragged the gate shut. \"Here they come. Don't let them reach the barn.\"")
	_next_wave()


func _next_wave() -> void:
	wave += 1
	match wave:
		1:
			for i in 3:
				_spawn(SOGGY, Vector2(lerpf(PEN_LEFT + 400.0, PEN_RIGHT - 200.0, i / 2.0), FLOOR_Y - 60.0), true)
		2:
			for i in 2:
				_spawn(SOGGY, Vector2(lerpf(PEN_LEFT + 300.0, PEN_RIGHT - 300.0, i), FLOOR_Y - 60.0), true)
			for x in [103 * 64.0, 108 * 64.0]:
				_spawn(SPITTER, Vector2(x, ROOF_Y - 4.0), false)
		3:
			DialogueUI.narrate("The sheep at the back of the pen stood up on their hind legs.")
			for node in get_tree().get_nodes_in_group(&"enemies"):
				if node is Soggy and (node as Soggy).is_disguised():
					(node as Soggy).throw_off_wool()
					_track(node)
			var inked := _spawn(SOGGY, Vector2(PEN_RIGHT - 120.0, FLOOR_Y - 400.0), false)
			inked.set(&"inked", true)
		_:
			_win()


func _spawn(scene: PackedScene, at: Vector2, rise: bool) -> Node2D:
	var enemy := scene.instantiate() as Node2D
	enemy.position = at
	enemy.set(&"scrap_drop", 1)
	if rise:
		enemy.scale = Vector2(1.0, 0.1)
		enemy.create_tween().tween_property(enemy, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	_track(enemy)
	add_child.call_deferred(enemy)
	return enemy


func _track(enemy: Node) -> void:
	_alive += 1
	enemy.tree_exiting.connect(_on_enemy_gone)


func _on_enemy_gone() -> void:
	if not _running or not is_inside_tree():
		return
	_alive -= 1
	if _alive <= 0:
		_alive = 0
		get_tree().create_timer(1.0, false).timeout.connect(_next_wave)


func _win() -> void:
	_running = false
	GameState.set_flag(HELD_FLAG)
	_set_gate(_west, false)
	_set_gate(_east, false)
	AudioManager.play_sfx(&"checkpoint")
	DialogueUI.start("fluff_fold_held")


func _set_gate(gate: Node2D, closed: bool, instant := false) -> void:
	if gate == null:
		return
	for child in gate.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not closed)
	if instant:
		gate.visible = closed
		return
	gate.visible = true
	var art := gate.get_node_or_null(^"Sprite2D") as Node2D
	var tween := gate.create_tween()
	if closed:
		art.scale.y = 0.05
		tween.tween_property(art, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(art, "scale:y", 0.05, 0.4)
		tween.tween_callback(func() -> void:
			gate.visible = false
			art.scale.y = 1.0)
