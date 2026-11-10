class_name RedactBox
extends Node2D
## The Redactor's box (BossRedactor._redact): first a red outline ruled round Patch,
## then (shut) two walls too tall to jump, and then (flood) the ink to the brim. Patch
## caught inside takes two; a ribbon inside is struck out. Its origin is the middle of
## its floor.

const INK := Color(0.05, 0.04, 0.05)

var size := Vector2(448, 420)
var is_shut := false
var _outline: Line2D
var _ink: Polygon2D
var _walls: Array[StaticBody2D] = []
var _hit: Hitbox


func _ready() -> void:
	add_to_group(&"redactor_boxes")
	z_index = 4
	var w := size.x / 2.0
	# The tell: a ruled red box, faintly filled, blinking.
	var wash := Polygon2D.new()
	wash.name = &"Wash"
	wash.color = Color(0.85, 0.1, 0.08, 0.14)
	wash.polygon = PackedVector2Array([Vector2(-w, 0), Vector2(-w, -size.y), Vector2(w, -size.y), Vector2(w, 0)])
	add_child(wash)
	_outline = Line2D.new()
	_outline.width = 10.0
	_outline.default_color = Color(0.95, 0.12, 0.08, 1.0)
	_outline.closed = true
	_outline.points = PackedVector2Array([Vector2(-w, 0), Vector2(-w, -size.y), Vector2(w, -size.y), Vector2(w, 0)])
	add_child(_outline)
	var blink := create_tween().set_loops(6)
	blink.tween_property(_outline, "modulate:a", 0.35, 0.06)
	blink.tween_property(_outline, "modulate:a", 1.0, 0.06)
	_ink = Polygon2D.new()
	_ink.color = Color(INK, 0.92)
	_ink.polygon = PackedVector2Array([Vector2(-w + 12, -size.y), Vector2(w - 12, -size.y), Vector2(w - 12, 0), Vector2(-w + 12, 0)])
	_ink.scale = Vector2(1, 0)
	add_child(_ink)
	_hit = Hitbox.new()
	_hit.collision_layer = 16
	_hit.collision_mask = 0
	_hit.monitoring = false
	_hit.damage = 2
	_hit.knockback = 300.0
	_hit.unblockable = true
	_hit.active = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x - 30.0, size.y)
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	_hit.add_child(shape)
	add_child(_hit)


## Whether a point (Patch's origin) is inside the box.
func holds(point: Vector2) -> bool:
	var local := point - global_position
	return absf(local.x) < size.x / 2.0 - 6.0 and local.y < 10.0 and local.y > -size.y


## The walls come down: solid, black-edged, too tall to jump.
func shut() -> void:
	if is_shut:
		return
	is_shut = true
	get_node("Wash").visible = false
	_outline.default_color = INK
	_outline.width = 22.0
	_outline.modulate.a = 1.0
	for side in [-1.0, 1.0]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, size.y)
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
		body.position = Vector2(side * size.x / 2.0, -size.y / 2.0)
		_walls.append(body)
	# Anyone standing in a wall's line is pushed to whichever side he was nearer.
	for patch in get_tree().get_nodes_in_group(&"player"):
		var p := patch as Node2D
		for side in [-1.0, 1.0]:
			var wx: float = global_position.x + side * size.x / 2.0
			var d: float = p.global_position.x - wx
			if absf(d) < 40.0 and p.global_position.y > global_position.y - size.y:
				p.global_position.x = wx + (signf(d) if d != 0.0 else -side) * 42.0
	AudioManager.play_sfx(&"slam", 1.1, -3.0)
	var rise := create_tween()
	rise.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_property(_ink, "scale:y", 0.35, 0.9)


## Ink to the brim: whoever is inside takes it; then the box comes away.
func flood() -> void:
	remove_from_group(&"redactor_boxes")
	_ink.scale.y = 1.0
	_hit.active = true
	for r in get_tree().get_nodes_in_group(&"warp_ribbons"):
		var ribbon := r as Node2D
		if holds(ribbon.global_position) and ribbon.has_method("eaten"):
			ribbon.eaten()
	AudioManager.play_sfx(&"hit_wet", 0.5)
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_interval(0.15)
	t.tween_callback(func() -> void:
		_hit.active = false
		for wall in _walls:
			wall.queue_free()
		_walls.clear())
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)
