class_name WaveLock
extends Area2D
## A stretch of the Gutter that seals itself when Patch walks in (the finale's
## gauntlet). Soaked-page gates swell shut at both ends, and Soggies rise out of the
## floodwater in waves. Clear every wave and the gates sag open again. Once cleared,
## the lock stays open, even after loading a save.

const SOGGY_SCENE := preload("res://scenes/enemies/soggy.tscn")

## The gates (wave_gate.tscn) that close while the lock is running.
@export var gates: Array[Node2D] = []
## How many Soggies rise in each wave.
@export var waves: Array[int] = [2, 3]
## Where they rise: a span of floor, in page coordinates.
@export var spawn_left := 0.0
@export var spawn_right := 0.0
@export var spawn_y := 0.0
@export_multiline var start_caption := ""
@export_multiline var clear_caption := ""

var _wave := -1
var _alive := 0
var _running := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	for gate in gates:
		_set_gate(gate, false, true)
	if GameState.is_collected(_unique_id()):
		set_deferred("monitoring", false)


func is_running() -> bool:
	return _running


func _on_body_entered(body: Node2D) -> void:
	if _running or not body is Patch or GameState.is_collected(_unique_id()):
		return
	_running = true
	for gate in gates:
		_set_gate(gate, true)
	AudioManager.play_sfx(&"slam", 0.7)
	if not start_caption.is_empty():
		DialogueUI.narrate(start_caption)
	_next_wave()


func _next_wave() -> void:
	_wave += 1
	if _wave >= waves.size():
		_clear()
		return
	_alive = waves[_wave]
	for i in waves[_wave]:
		var soggy := SOGGY_SCENE.instantiate() as Node2D
		var t := (i + 0.5) / waves[_wave]
		soggy.position = Vector2(lerpf(spawn_left, spawn_right, t) + randf_range(-40.0, 40.0), spawn_y - 60.0)
		soggy.tree_exiting.connect(_on_soggy_gone)
		# They rise up out of the water.
		soggy.scale = Vector2(1.0, 0.1)
		soggy.create_tween().tween_property(soggy, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
		get_parent().add_child.call_deferred(soggy)


func _on_soggy_gone() -> void:
	if not _running:
		return
	_alive -= 1
	if _alive <= 0:
		# A breath between waves.
		get_tree().create_timer(0.8, false).timeout.connect(_next_wave)


func _clear() -> void:
	_running = false
	GameState.mark_collected(_unique_id())
	set_deferred("monitoring", false)
	for gate in gates:
		_set_gate(gate, false)
	AudioManager.play_sfx(&"checkpoint")
	if not clear_caption.is_empty():
		DialogueUI.narrate(clear_caption)


func _set_gate(gate: Node2D, closed: bool, instant := false) -> void:
	for child in gate.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not closed)
	if instant:
		gate.visible = closed
		return
	gate.visible = true
	var art := gate.get_node_or_null("Sprite2D") as Node2D
	if art == null:
		gate.visible = closed
		return
	var tween := gate.create_tween()
	if closed:
		art.scale.y = 0.05
		tween.tween_property(art, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(art, "scale:y", 0.05, 0.4)
		tween.tween_callback(func() -> void:
			gate.visible = false
			art.scale.y = 1.0)


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]
