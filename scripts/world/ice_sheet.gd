class_name IceSheet
extends Node2D
## Black ice on the Spine Peaks (4-1): a glaze over the top of a run of ground. Patch
## skates on it (see Patch.ice_left): slow to get going, slower to stop. TextLevel lays
## one along the top of each run of '=' cells; it fills `size` from a top-left origin
## (the top of the ground), and only its top 24 px or so is drawn.

@export var size := Vector2(256, 64)

var _sensor: Area2D


func _ready() -> void:
	add_to_group(&"ice")
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x, 28)
	shape.shape = rect
	shape.position = Vector2(size.x / 2.0, -10)
	_sensor.add_child(shape)
	add_child(_sensor)
	z_index = 1


func _physics_process(_delta: float) -> void:
	for body in _sensor.get_overlapping_bodies():
		if body is Patch and (body as Patch).is_on_floor():
			(body as Patch).ice_left = 0.1


## Is this point (a foot) on the ice? For tests and enemies.
func covers(at: Vector2) -> bool:
	var local := to_local(at)
	return local.x >= 0.0 and local.x <= size.x and absf(local.y) <= 20.0


func _draw() -> void:
	# A cold, glassy skin: pale at the lip, deep blue-black under it, with a long
	# sheen and a few cracks, so it reads as slick against the slate.
	var w := size.x
	draw_rect(Rect2(0, -6, w, 30), Color(0.55, 0.7, 0.82, 0.38))
	draw_rect(Rect2(0, -6, w, 5), Color(0.86, 0.94, 1.0, 0.85))
	draw_rect(Rect2(0, -1, w, 3), Color(0.32, 0.46, 0.6, 0.6))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = int(global_position.x * 13.0 + global_position.y)
	var x := rnd.randf_range(10.0, 60.0)
	while x < w - 20.0:
		var length := rnd.randf_range(30.0, 90.0)
		draw_line(Vector2(x, 6), Vector2(minf(x + length, w - 4.0), 4), Color(0.9, 0.97, 1.0, 0.35), 2.0)
		x += length + rnd.randf_range(40.0, 120.0)
	x = rnd.randf_range(20.0, 80.0)
	while x < w - 20.0:
		var a := Vector2(x, 2)
		for i in 3:
			var b := a + Vector2(rnd.randf_range(-12.0, 12.0), rnd.randf_range(5.0, 9.0))
			draw_line(a, b, Color(0.08, 0.12, 0.16, 0.55), 1.5)
			a = b
		x += rnd.randf_range(90.0, 200.0)
