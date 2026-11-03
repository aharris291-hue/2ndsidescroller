class_name BellStone
extends Node2D
## A flagstone with a bell rope through an iron ring (1-3, the Drowned Chapel). It is
## pressed while a PushBlock rests on it; the page rings the bell once every stone in
## the room is pressed. Seen from above, so it sits on the floor under everything.

signal pressed_changed(pressed: bool)

const TEX := preload("res://assets/art/dark/props/bell_stone.png")

var pressed := false
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group(&"bell_stones")
	z_index = -1
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	var now := false
	for node in get_tree().get_nodes_in_group(&"push_blocks"):
		var block := node as PushBlock
		if block == null:
			continue
		var half := block.size_px() / 2.0 - Vector2(8, 8)
		var d := (global_position - block.global_position).abs()
		if d.x < half.x and d.y < half.y:
			now = true
			break
	if now != pressed:
		pressed = now
		_sprite.modulate = Color(0.75, 0.9, 0.8) if pressed else Color.WHITE
		if pressed:
			AudioManager.play_sfx(&"tab_pull", 0.45, -6.0)
		pressed_changed.emit(pressed)
