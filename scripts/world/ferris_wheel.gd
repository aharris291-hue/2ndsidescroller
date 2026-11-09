class_name FerrisWheel
extends Node2D
## The Big Wheel (Gatefold Fair, 5-2): the fair's ferris wheel, still turning in the
## rain with nobody to stop it. Its gondolas hang level from the rim; their benches are
## one-way platforms Patch rides up. The node stands on its feet (the cell's floor);
## the hub is `hub_height` above. Match climb_check's 'Z' (radius 7 tiles, hub 11
## rows up, seats 2.65 rows under the rim) if these change.

const GONDOLA := preload("res://assets/art/dark/props/gondola.png")
## The bench's top, below the rim point the gondola hangs from.
const DROP := 170.0

@export var radius := 448.0
@export var hub_height := 704.0
@export var gondola_count := 8
## Radians a second; positive turns clockwise (seats rise on the left).
@export var spin_speed := -0.22
@export var spinning := true

var angle := 0.0
var gondolas: Array[AnimatableBody2D] = []
var _spokes: Node2D


func _ready() -> void:
	add_to_group(&"ferris_wheels")
	_build_frame()
	for i in gondola_count:
		var body := AnimatableBody2D.new()
		body.name = "Gondola%d" % i
		body.collision_mask = 0
		body.sync_to_physics = false
		var sprite := Sprite2D.new()
		sprite.texture = GONDOLA
		sprite.offset = Vector2(0, GONDOLA.get_height() / 2.0)
		sprite.position = Vector2(0, -DROP)
		body.add_child(sprite)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(132, 20)
		shape.shape = rect
		shape.position = Vector2(0, 10)
		shape.one_way_collision = true
		body.add_child(shape)
		add_child(body)
		gondolas.append(body)
	_place()


func _build_frame() -> void:
	var hub := Vector2(0, -hub_height)
	var iron := Color(0.46, 0.38, 0.33)
	for side in [-1.0, 1.0]:
		var leg := Line2D.new()
		leg.points = PackedVector2Array([Vector2(side * radius * 0.55, 0), hub])
		leg.width = 22.0
		leg.default_color = iron
		add_child(leg)
	_spokes = Node2D.new()
	_spokes.position = hub
	add_child(_spokes)
	var rim := Line2D.new()
	rim.width = 14.0
	rim.default_color = Color(0.72, 0.26, 0.18)
	rim.closed = true
	var inner := Line2D.new()
	inner.width = 7.0
	inner.default_color = iron
	inner.closed = true
	for k in 48:
		var a := TAU * k / 48.0
		rim.add_point(Vector2.from_angle(a) * radius)
		inner.add_point(Vector2.from_angle(a) * radius * 0.82)
	_spokes.add_child(rim)
	_spokes.add_child(inner)
	for k in gondola_count * 2:
		var spoke := Line2D.new()
		spoke.points = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(TAU * k / (gondola_count * 2.0)) * radius])
		spoke.width = 6.0
		spoke.default_color = iron
		_spokes.add_child(spoke)
	var boss := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		pts.append(Vector2.from_angle(TAU * k / 12.0) * (34.0 if k % 2 == 0 else 24.0))
	boss.polygon = pts
	boss.color = Color(0.55, 0.42, 0.18)
	_spokes.add_child(boss)


func _physics_process(delta: float) -> void:
	if not spinning:
		return
	angle = wrapf(angle + spin_speed * delta, 0.0, TAU)
	_place()


func _place() -> void:
	_spokes.rotation = angle
	for i in gondolas.size():
		var a := angle + TAU * i / gondolas.size()
		gondolas[i].position = Vector2(0, -hub_height) + Vector2.from_angle(a) * radius + Vector2(0, DROP)
