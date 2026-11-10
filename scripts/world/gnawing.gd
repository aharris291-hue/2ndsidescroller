class_name Gnawing
extends Node2D
## The Gnawing (6-5): the silverfish all at once. The last pages of the book are being
## eaten, and when Patch comes in, they come after him: a wall of them, the whole height
## of the page, eating it as they come. Run.
##
## It waits at its letter in the map. Once Patch is `trigger_ahead` past it, its front
## comes on, picking up speed, until it reaches `stop_x` (pixels, where the page is too
## thick for them: the last shutter) and falls back. Touching the front hurts and throws
## Patch on ahead of it; it never leaves him inside it. It eats a laid ribbon too.

const FISH := preload("res://assets/art/dark/enemies/silverfish.png")

@export var speed := 290.0
@export var top_speed := 360.0
## Pixels per second it gains each second.
@export var accel := 8.0
@export var trigger_ahead := 320.0
@export var stop_x := 0.0
@export var height := 2200.0
## How far behind Patch it starts when he comes in already past its letter (a bookmark).
@export var start_behind := 760.0

var running := false
var done := false
## Where its front is, in global x.
var front := 0.0
var _speed := 0.0
var _hit: Hitbox
var _mass: Node2D
var _fish: Array[Sprite2D] = []
var _crumbs: CPUParticles2D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"gnawing")
	front = global_position.x
	_mass = Node2D.new()
	_mass.top_level = true
	_mass.z_index = 3
	add_child(_mass)
	# The mass: a black, chewed edge with the paper's grey showing in the bites.
	var body := Polygon2D.new()
	body.color = Color(0.03, 0.03, 0.04)
	var points := PackedVector2Array([Vector2(-2400, -height), Vector2(0, -height)])
	var y := -height
	var i := 0
	while y < 400.0:
		y += randf_range(26.0, 60.0)
		points.append(Vector2(-randf_range(0.0, 46.0) - (24.0 if i % 2 else 0.0), y))
		i += 1
	points.append(Vector2(-2400, y))
	body.polygon = points
	_mass.add_child(body)
	for n in 14:
		var fish := Sprite2D.new()
		fish.texture = FISH
		fish.scale = Vector2.ONE * randf_range(0.7, 1.15)
		fish.flip_h = true
		fish.position = Vector2(randf_range(-160.0, -10.0), -height + (n + 0.5) * height / 14.0 + 300.0)
		fish.modulate = Color(0.75, 0.75, 0.8)
		_mass.add_child(fish)
		_fish.append(fish)
	_crumbs = CPUParticles2D.new()
	_crumbs.amount = 60
	_crumbs.lifetime = 0.9
	_crumbs.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_crumbs.emission_rect_extents = Vector2(10, 700)
	_crumbs.direction = Vector2(1, -0.3)
	_crumbs.spread = 40.0
	_crumbs.initial_velocity_min = 80.0
	_crumbs.initial_velocity_max = 260.0
	_crumbs.gravity = Vector2(0, 600)
	_crumbs.scale_amount_min = 3.0
	_crumbs.scale_amount_max = 8.0
	_crumbs.color = Color(0.72, 0.68, 0.58)
	_crumbs.position = Vector2(0, -700)
	_crumbs.emitting = false
	_mass.add_child(_crumbs)
	_hit = Hitbox.new()
	_hit.collision_layer = 16
	_hit.collision_mask = 0
	_hit.monitoring = false
	_hit.damage = 1
	_hit.knockback = 900.0
	_hit.unblockable = true
	_hit.active = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, height + 400.0)
	shape.shape = rect
	shape.position = Vector2(-60, -height / 2.0 + 200.0)
	_hit.add_child(shape)
	_mass.add_child(_hit)
	_mass.visible = false
	_place()


func _patch() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _physics_process(delta: float) -> void:
	var patch := _patch()
	if done or patch == null:
		return
	if not running:
		if patch.global_position.x > global_position.x + trigger_ahead:
			start(patch)
		return
	_t += delta
	_speed = minf(_speed + accel * delta, top_speed)
	front += _speed * delta
	if stop_x > 0.0 and front >= stop_x:
		front = stop_x
		_fall_back()
		return
	_place()
	# Never leave him inside it.
	if patch.global_position.x < front - 50.0:
		patch.global_position.x = front + 60.0
	for r in get_tree().get_nodes_in_group(&"warp_ribbons"):
		var ribbon := r as Node2D
		if ribbon.global_position.x < front + 20.0 and ribbon.has_method("eaten"):
			ribbon.eaten()
	# It eats whatever is in the way, its own kind included.
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := e as Node2D
		if enemy and enemy.global_position.x < front - 20.0 and not enemy.is_queued_for_deletion():
			enemy.queue_free()
	for n in _fish.size():
		_fish[n].position.x = -80.0 + sin(_t * 9.0 + n * 1.7) * 40.0
	if fmod(_t, 0.5) < delta:
		AudioManager.play_sfx(&"page_flip", randf_range(1.6, 2.2), -10.0)


func start(patch: Node2D = null) -> void:
	if running or done:
		return
	running = true
	_speed = speed
	if patch:
		front = maxf(global_position.x, patch.global_position.x - start_behind)
	_mass.visible = true
	_hit.active = true
	_crumbs.emitting = true
	_place()
	AudioManager.play_sfx(&"growl", 0.6)
	DialogueUI.narrate("Behind him the page went dark, and then it went away: not torn, eaten, the whole height of it, by more of them than he could count. They were coming down the page faster than he could think.")


func _place() -> void:
	_mass.global_position = Vector2(front, global_position.y)


func _fall_back() -> void:
	running = false
	done = true
	_hit.active = false
	_crumbs.emitting = false
	_place()
	AudioManager.play_sfx(&"slam", 0.6, -4.0)
	var t := create_tween()
	t.tween_property(_mass, "modulate:a", 0.0, 1.6)
	t.parallel().tween_property(_mass, "global_position:x", front - 600.0, 1.6)
	t.tween_callback(func() -> void: _mass.visible = false)
