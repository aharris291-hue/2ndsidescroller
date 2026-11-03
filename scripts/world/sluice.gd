class_name Sluice
extends Interactable
## A sluice gate on the millrace (1-4). Its tab winds the gate up, and the stretch of
## race it holds back drains: every Current whose middle lies within `drain_left` ..
## `drain_right` px of the gate stops flowing. The race is drained a section at a time,
## one sluice each. Once opened it stays open, even after a reload.
##
## Stands on its origin like the other text-map entities.

const GATE := preload("res://assets/art/dark/props/sluice_gate.png")

@export var drain_left := 0.0
@export var drain_right := 1600.0
@export_multiline var caption := ""

signal opened

var is_open := false
var _gate: Sprite2D


func _ready() -> void:
	add_to_group(&"sluices")
	prompt_text = "Open the sluice"
	collision_layer = 32
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 160)
	shape.shape = rect
	shape.position = Vector2(0, -80)
	add_child(shape)
	_gate = Sprite2D.new()
	_gate.texture = GATE
	_gate.centered = false
	_gate.position = Vector2(-32, -256)
	_gate.region_enabled = true
	_gate.region_rect = Rect2(0, 0, 64, 256)
	add_child(_gate)
	prompt_offset = Vector2(0, -300)
	super._ready()
	if GameState.is_collected(_unique_id()):
		# Deferred, so the currents downstream are in the tree to be stopped.
		_open.call_deferred(false)


func can_interact() -> bool:
	return not is_open


func interact(_player: Patch) -> void:
	if is_open:
		return
	GameState.mark_collected(_unique_id())
	AudioManager.play_sfx(&"tab_pull", 0.7)
	if not caption.is_empty():
		DialogueUI.narrate(caption)
	_open(true)


## The currents this sluice drains.
func drains() -> Array[Current]:
	var out: Array[Current] = []
	for node in get_tree().get_nodes_in_group(&"currents"):
		var current := node as Current
		if current == null:
			continue
		var dx := current.global_position.x - global_position.x
		if dx >= drain_left and dx <= drain_right:
			out.append(current)
	return out


func _open(animate: bool) -> void:
	is_open = true
	for current in drains():
		current.set_flowing(false)
	if animate:
		# The gate winds up into its frame.
		var wind := create_tween()
		wind.tween_property(_gate, "position:y", -256.0 - 160.0, 1.4).set_trans(Tween.TRANS_SINE)
		wind.parallel().tween_property(_gate, "modulate", Color(0.7, 0.7, 0.7), 1.4)
	else:
		_gate.position.y = -256.0 - 160.0
		_gate.modulate = Color(0.7, 0.7, 0.7)
	opened.emit()


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]
