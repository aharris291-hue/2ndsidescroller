class_name ThreadBridge
extends Node2D
## A taut red thread strung across a gap, walkable from above. Its knot (at the right
## end) can be cut with the shears: the thread snaps, the bridge falls away and the
## story flag `cut_flag` is set. Once cut it stays cut for the rest of the page.

const THREAD := preload("res://assets/art/dark/props/thread_bridge.png")

## Bridge length in pixels, running right from this node.
@export var length := 448.0
@export var cut_flag := "cut_the_thread"
@export_multiline var cut_caption := ""

var _cut := false
var _body: StaticBody2D
var _line: Sprite2D
var _knot: Node2D


func _ready() -> void:
	_line = Sprite2D.new()
	_line.texture = THREAD
	_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_line.region_enabled = true
	_line.region_rect = Rect2(0, 0, length, 16)
	_line.centered = false
	_line.position = Vector2(0, -14)
	_line.scale = Vector2(1, 1.8)
	add_child(_line)
	_body = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var segment := SegmentShape2D.new()
	segment.a = Vector2(0, -6)
	segment.b = Vector2(length, -6)
	shape.shape = segment
	shape.one_way_collision = true
	_body.add_child(shape)
	add_child(_body)
	_knot = _make_knot()
	add_child(_knot)


func _make_knot() -> Node2D:
	var knot := Node2D.new()
	knot.position = Vector2(length + 10, -10)
	var dot := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 10:
		var a := i / 10.0 * TAU
		points.append(Vector2(cos(a), sin(a)) * (14.0 if i % 2 == 0 else 10.0))
	dot.polygon = points
	dot.color = Color(0.62, 0.13, 0.1)
	knot.add_child(dot)
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	hurtbox.add_child(shape)
	knot.add_child(hurtbox)
	hurtbox.hit.connect(_on_hit)
	return knot


func _on_hit(hitbox: Hitbox) -> void:
	if _cut or not hitbox.owner is Patch:
		return
	cut()


func cut() -> void:
	_cut = true
	GameState.set_flag(cut_flag)
	AudioManager.play_sfx(&"shears", 0.8)
	AudioManager.play_sfx(&"tab_pull", 0.6)
	for shape in _body.get_children():
		(shape as CollisionShape2D).set_deferred("disabled", true)
	# The thread whips down and away from the knot.
	_line.centered = false
	var tween := create_tween().set_parallel()
	tween.tween_property(_line, "rotation", deg_to_rad(80), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_line, "modulate:a", 0.0, 0.9)
	tween.tween_property(_knot, "scale", Vector2(0.4, 0.4), 0.2)
	if not cut_caption.is_empty():
		DialogueUI.narrate(cut_caption)
