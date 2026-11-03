class_name ChapelGate
extends StaticBody2D
## An iron grille across a doorway, seen from above (1-3, the Drowned Chapel). It
## covers two cells above its origin (a doorway two tiles tall) and sinks into the
## floor when the page opens it.

var is_open := false
var _bars: Node2D
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 128)
	_shape.shape = rect
	_shape.position = Vector2(0, -64)
	add_child(_shape)
	_bars = Node2D.new()
	add_child(_bars)
	var frame := ColorRect.new()
	frame.color = Color(0.06, 0.05, 0.05)
	frame.position = Vector2(-14, -128)
	frame.size = Vector2(28, 128)
	_bars.add_child(frame)
	for i in 5:
		var bar := ColorRect.new()
		bar.color = Color(0.34, 0.32, 0.3)
		bar.position = Vector2(-8, -122 + i * 26)
		bar.size = Vector2(16, 14)
		_bars.add_child(bar)


func open(instant := false) -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	if instant:
		_bars.visible = false
		return
	AudioManager.play_sfx(&"slam", 0.6, -4.0)
	var sink := create_tween()
	sink.tween_property(_bars, "modulate:a", 0.0, 0.6)
	sink.tween_callback(func() -> void: _bars.visible = false)
