class_name SluiceWheel
extends Interactable
## An iron hand wheel in the sluice house (3-3): a turn swings the gates on one channel
## and the ink in it runs the other way. Every InkCurrent whose block overlaps one of
## `channels` (rectangles in px relative to the wheel) reverses (or stops and starts, with
## `toggle`). The wheels keep their setting only for the visit.
##
## Stands on its origin like the other text-map entities.

const TEX := preload("res://assets/art/dark/props/sluice_wheel.png")

@export var channels: Array[Rect2] = [Rect2(-64, 0, 128, 128)]
@export var toggle := false

signal turned

var turns := 0
var _wheel: Sprite2D


func _ready() -> void:
	add_to_group(&"sluice_wheels")
	prompt_text = "Turn the wheel"
	collision_layer = 32
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110, 140)
	shape.shape = rect
	shape.position = Vector2(0, -70)
	add_child(shape)
	var post := ColorRect.new()
	post.color = Color(0.2, 0.15, 0.1)
	post.size = Vector2(12, 60)
	post.position = Vector2(-6, -60)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(post)
	_wheel = Sprite2D.new()
	_wheel.texture = TEX
	_wheel.position = Vector2(0, -78)
	add_child(_wheel)
	prompt_offset = Vector2(0, -150)
	super._ready()


func currents() -> Array[Node]:
	var out: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"ink_currents"):
		var current := node as Node2D
		var block := Rect2(current.global_position, current.get("size"))
		for channel in channels:
			if block.intersects(Rect2(global_position + channel.position, channel.size)):
				out.append(current)
				break
	return out


func interact(_player: Patch) -> void:
	turn()


func turn() -> void:
	turns += 1
	for current in currents():
		if toggle:
			current.flowing = not current.flowing
		else:
			current.direction = -current.direction
			current.flowing = current.flowing  # refreshes its silt
	AudioManager.play_sfx(&"tab_pull", 0.6)
	var spin := create_tween()
	spin.tween_property(_wheel, "rotation", _wheel.rotation + PI, 0.5).set_trans(Tween.TRANS_BACK)
	turned.emit()
