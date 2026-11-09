class_name InkCurrent
extends Area2D
## A current running through settled ink (Region 3, Watermark Marsh): pale silt streams
## along it, and a blot swimming in it is carried (`direction` * `strength` px/s on top
## of his own swimming). It only moves Patch while he is Blot Diving; on the surface it
## is just ink. Covers `size` from its origin at the top-left, like an InkPool.
## A SluiceWheel can turn it off or reverse it (`flowing`, `direction`).

const STREAK := preload("res://assets/art/dark/props/ink_current.png")

@export var size := Vector2(512, 128)
@export var direction := Vector2.RIGHT
@export var strength := 300.0
@export var flowing := true:
	set(value):
		flowing = value
		_refresh()

var _silt: CPUParticles2D


func _ready() -> void:
	add_to_group(&"ink_currents")
	collision_layer = 0
	collision_mask = 2
	z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	_silt = CPUParticles2D.new()
	_silt.texture = STREAK
	_silt.amount = maxi(6, int(size.x * size.y / 9000.0))
	_silt.lifetime = 1.6
	_silt.preprocess = 1.6
	_silt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_silt.emission_rect_extents = size / 2.0
	_silt.position = size / 2.0
	_silt.gravity = Vector2.ZERO
	_silt.spread = 4.0
	_silt.scale_amount_min = 0.4
	_silt.scale_amount_max = 0.9
	_silt.particle_flag_align_y = false
	_silt.color = Color(0.8, 0.8, 0.72, 0.5)
	add_child(_silt)
	_refresh()


func _refresh() -> void:
	if _silt == null:
		return
	_silt.emitting = flowing
	_silt.direction = direction.normalized()
	_silt.angle_min = rad_to_deg(direction.angle())
	_silt.angle_max = _silt.angle_min
	_silt.initial_velocity_min = strength * 0.6
	_silt.initial_velocity_max = strength * 0.9


func _physics_process(_delta: float) -> void:
	if not flowing:
		return
	for body in get_overlapping_bodies():
		if body.get("blotting") == true:
			body.push += direction.normalized() * strength
