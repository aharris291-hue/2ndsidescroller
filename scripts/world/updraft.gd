class_name Updraft
extends Area2D
## A column of warm air out of a fairground vent (Gatefold Fair): the steam organs and
## the generators under the boards still breathe. A paper plane (Patch gliding) that
## flies into it is lifted up the column; anything else just feels the warmth. It fills
## `size`, standing on its origin. With `rest_time` above 0 it breathes in bursts, and
## the steam thins for a moment (`WARN`) before it stops.

@export var size := Vector2(128, 768)
@export var blow_time := 3.0
@export var rest_time := 0.0
## Where in its cycle it starts, in seconds.
@export var phase := 0.0
## The Gatefold (5-3): a vent under a hinged card flap. Shut, nothing comes up; a
## PullTab whose `flips` names this `tag` flips it.
@export var flap := false
@export var open := true
@export var tag := ""

const WARN := 0.6

var blowing := true
var _t := 0.0
var _steam: CPUParticles2D
var _flap: Polygon2D


func _ready() -> void:
	add_to_group(&"updrafts")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_steam = CPUParticles2D.new()
	_steam.amount = int(clampf(size.y / 12.0, 24.0, 120.0))
	_steam.lifetime = size.y / 420.0
	_steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_steam.emission_rect_extents = Vector2(size.x * 0.35, 8.0)
	_steam.direction = Vector2.UP
	_steam.spread = 6.0
	_steam.gravity = Vector2.ZERO
	_steam.initial_velocity_min = 360.0
	_steam.initial_velocity_max = 460.0
	_steam.scale_amount_min = 3.0
	_steam.scale_amount_max = 9.0
	_steam.color = Color(0.82, 0.8, 0.76, 0.28)
	add_child(_steam)
	var vent := Polygon2D.new()
	var w := size.x * 0.4
	vent.polygon = PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.8, -14), Vector2(-w * 0.8, -14)])
	vent.color = Color(0.22, 0.19, 0.17)
	add_child(vent)
	if flap:
		_flap = Polygon2D.new()
		_flap.polygon = PackedVector2Array([Vector2(0, -6), Vector2(size.x * 0.9, -6), Vector2(size.x * 0.9, 6), Vector2(0, 6)])
		_flap.color = Color(0.55, 0.16, 0.13)
		_flap.position = Vector2(-size.x * 0.45, -16)
		var trim := Line2D.new()
		trim.points = PackedVector2Array([Vector2(4, 0), Vector2(size.x * 0.9 - 4, 0)])
		trim.width = 3.0
		trim.default_color = Color(0.78, 0.62, 0.3)
		_flap.add_child(trim)
		add_child(_flap)
		add_to_group(&"vent_flaps")
		_show_flap(false)
	_t = phase


## A pull tab flips the flap: open it, or shut it over the vent.
func flip() -> void:
	open = not open
	AudioManager.play_sfx(&"page_flip", 0.8 if open else 0.6)
	_show_flap(true)


func _show_flap(animate: bool) -> void:
	if _flap == null:
		return
	# Open, the flap stands up on its hinge beside the vent; shut, it lies over it.
	var angle := -PI / 2.0 if open else 0.0
	if animate:
		create_tween().tween_property(_flap, "rotation", angle, 0.35).set_trans(Tween.TRANS_BACK)
	else:
		_flap.rotation = angle
	_steam.emitting = open


func _physics_process(delta: float) -> void:
	if not open:
		blowing = false
		return
	if rest_time > 0.0:
		_t = fmod(_t + delta, blow_time + rest_time)
		blowing = _t < blow_time
		_steam.emitting = _t < blow_time - WARN or _t > blow_time + rest_time - 0.15
	elif not blowing:
		blowing = true
	if not blowing:
		return
	for body in get_overlapping_bodies():
		if body is Patch:
			body.updraft_left = 0.1
