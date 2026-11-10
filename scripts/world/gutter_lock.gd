class_name GutterLock
extends Area2D
## A wave lock in the Gutter Descent (F-1), placed from a text map. When Patch walks
## in, two soaked-page gates swell shut, one at each end of the stretch, and the
## flood gives back what it drowned in waves: every kind of enemy in the book, some of
## them inked. When every wave is beaten the gates sag open again and stay open (even
## after loading a save).
##
## Its origin is the floor at the left gate, the cell its letter stands on; the right
## gate is `width` tiles along. `height` is how tall the gates are: make it the height
## of the room, so nothing flies over them.

const TILE := 64.0
const GATE_ART := preload("res://assets/art/dark/props/gutter_gate.png")
## A wave is a string of letters, one enemy each; a capital letter is inked.
const KINDS := {
	"s": "res://scenes/enemies/soggy.tscn",
	"p": "res://scenes/enemies/ink_spitter.tscn",
	"m": "res://scenes/enemies/paper_moth.tscn",
	"k": "res://scenes/enemies/tack_knight.tscn",
	"c": "res://scenes/enemies/folded_crane.tscn",
	"b": "res://scenes/enemies/mimic_book.tscn",
	"h": "res://scenes/enemies/carousel_horse.tscn",
	"i": "res://scenes/enemies/silverfish.tscn",
}
## Fliers come in high, out of the dark over the water.
const FLIERS := "mc"

## Tiles from the left gate to the right one.
@export var width := 20
@export var height := 384.0
@export var waves: PackedStringArray = []
@export_multiline var start_caption := ""
@export_multiline var clear_caption := ""

var wave := -1
var gates: Array[StaticBody2D] = []
var _alive := 0
var _running := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Patch must be well inside before it shuts, so the gate never lands on him.
	rect.size = Vector2((width - 4) * TILE, height)
	shape.shape = rect
	shape.position = Vector2(width * TILE / 2.0, -height / 2.0)
	add_child(shape)
	for x in [0.0, width * TILE]:
		gates.append(_make_gate(x))
	body_entered.connect(_on_body_entered)
	if is_cleared():
		set_deferred("monitoring", false)


func is_running() -> bool:
	return _running


func is_cleared() -> bool:
	return GameState.is_collected(_unique_id())


func _make_gate(x: float) -> StaticBody2D:
	var gate := StaticBody2D.new()
	gate.collision_layer = 1
	gate.collision_mask = 0
	gate.position = Vector2(x, 0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, height)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	shape.disabled = true
	gate.add_child(shape)
	var art := Sprite2D.new()
	art.name = &"Sprite2D"
	art.texture = GATE_ART
	art.centered = false
	art.offset = Vector2(-56, -330)
	art.scale = Vector2(1.0, height / 330.0)
	gate.add_child(art)
	gate.visible = false
	add_child(gate)
	return gate


func _on_body_entered(body: Node2D) -> void:
	if _running or not body.is_in_group(&"player") or is_cleared():
		return
	_running = true
	for gate in gates:
		_set_gate(gate, true)
	AudioManager.play_sfx(&"slam", 0.7)
	if not start_caption.is_empty():
		DialogueUI.narrate(start_caption)
	_next_wave.call_deferred()


func _next_wave() -> void:
	wave += 1
	if wave >= waves.size():
		_clear()
		return
	var letters := waves[wave].replace(" ", "")
	_alive = letters.length()
	for i in letters.length():
		var c := letters[i]
		var path: String = KINDS.get(c.to_lower(), KINDS["s"])
		var foe := (load(path) as PackedScene).instantiate() as Node2D
		if c != c.to_lower():
			foe.set(&"inked", true)
		var t := (i + 0.5) / letters.length()
		var x := lerpf(2.5 * TILE, (width - 2.5) * TILE, t) + randf_range(-30.0, 30.0)
		var y := -height + 120.0 if FLIERS.contains(c.to_lower()) else -40.0
		foe.position = position + Vector2(x, y)
		foe.tree_exiting.connect(_on_foe_gone)
		# They come up out of the flood.
		foe.modulate.a = 0.0
		foe.create_tween().tween_property(foe, "modulate:a", 1.0, 0.5)
		get_parent().add_child.call_deferred(foe)
	AudioManager.play_sfx(&"growl", 0.8 + 0.1 * wave, -6.0)


func _on_foe_gone() -> void:
	if not _running:
		return
	_alive -= 1
	if _alive <= 0:
		# A breath between waves.
		get_tree().create_timer(0.9, false).timeout.connect(_next_wave)


func _clear() -> void:
	_running = false
	GameState.mark_collected(_unique_id())
	set_deferred("monitoring", false)
	for gate in gates:
		_set_gate(gate, false)
	AudioManager.play_sfx(&"checkpoint")
	if not clear_caption.is_empty():
		DialogueUI.narrate(clear_caption)


func _set_gate(gate: StaticBody2D, closed: bool) -> void:
	for child in gate.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not closed)
	gate.visible = true
	var art := gate.get_node("Sprite2D") as Sprite2D
	var full := height / 330.0
	var tween := gate.create_tween()
	if closed:
		art.scale.y = 0.05
		tween.tween_property(art, "scale:y", full, 0.25).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(art, "scale:y", 0.05, 0.4)
		tween.tween_callback(func() -> void:
			gate.visible = false
			art.scale.y = full)


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", name]
