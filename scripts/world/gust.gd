class_name Gust
extends Area2D
## A gust off the sea between the wharf's sheds (2-4, the Shadow Wharf). It blows in
## bursts: a flutter of paper scraps warns of it, then for `blow_time` seconds it pushes
## Patch along (`strength` px/s, positive = right, harder in the air), then it drops for
## `rest_time`. It fills `size`, standing on its origin.

@export var size := Vector2(640, 512)
@export var strength := -520.0
@export var blow_time := 2.2
@export var rest_time := 2.4
## Where in its cycle it starts, in seconds (so neighbouring gusts don't blow together).
@export var phase := 0.0
## The Spine Peaks: a frost gust, carrying snow instead of paper scraps.
@export var snow := false

const WARN := 0.7

var blowing := false
var _t := 0.0
var _scraps: CPUParticles2D


func _ready() -> void:
	add_to_group(&"gusts")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_scraps = CPUParticles2D.new()
	_scraps.amount = 40
	_scraps.lifetime = 1.4
	_scraps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_scraps.emission_rect_extents = size / 2.0
	_scraps.position = Vector2(0, -size.y / 2.0)
	_scraps.direction = Vector2(signf(strength), -0.1)
	_scraps.spread = 12.0
	_scraps.gravity = Vector2(0, 40)
	_scraps.initial_velocity_min = absf(strength) * 0.8
	_scraps.initial_velocity_max = absf(strength) * 1.3
	_scraps.scale_amount_min = 2.0
	_scraps.scale_amount_max = 5.0
	_scraps.color = Color(0.72, 0.68, 0.6, 0.55)
	if snow:
		_scraps.amount = 90
		_scraps.color = Color(0.88, 0.94, 1.0, 0.7)
		_scraps.scale_amount_min = 1.5
		_scraps.scale_amount_max = 3.5
	_scraps.emitting = false
	add_child(_scraps)
	_t = phase


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, blow_time + rest_time)
	var now := _t < blow_time
	var warning := not now and _t > blow_time + rest_time - WARN
	_scraps.emitting = now or warning
	_scraps.speed_scale = 1.0 if now else 0.35
	blowing = now
	if not now:
		return
	for body in get_overlapping_bodies():
		var patch := body as Patch
		if patch:
			patch.push.x += strength * (0.7 if patch.is_on_floor() else 1.0)
