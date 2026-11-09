class_name ClockworkNeedle
extends Node2D
## One of Bindwell's sewing machines (4-2, the Fold Works): an iron head hanging from a
## rail, running back and forth above the floor. When Patch is under it (or every
## `beat` seconds) it stops, the pin shudders and the thread pulls tight (the tell),
## then the pin stabs straight down to whatever is under it. It sticks there for
## `stuck_time`: three cuts to the stuck pin snap it, and the machine runs on harmless.
##
## Its origin is on the rail; the rail runs from `rail_left` to `rail_right` (px, from
## the origin). The pin reaches at most `max_drop` px below the rail.

const HEAD_TEX := preload("res://assets/art/dark/props/clockwork_head.png")
const PIN_TEX := preload("res://assets/art/dark/props/clockwork_pin.png")
const RAIL_TEX := preload("res://assets/art/dark/props/needle_rail.png")
const SCALE := 0.6
## Where the pin hangs, in head-art px (tools/art/dark_props_r4.py), and its tip.
const PIN_COLUMN := 37.5
const PIN_TOP := 174.0
const PIN_LENGTH := 320.0
const PIN_X := 24.0

enum State { RUNNING, TELL, STAB, STUCK, RETRACT, SNAPPED }

@export var rail_left := -384.0
@export var rail_right := 384.0
@export var speed := 150.0
@export var max_drop := 640.0
## The beat: it stabs at least this often, even with Patch nowhere near.
@export var beat := 3.2
@export var tell_time := 0.55
@export var stuck_time := 0.8
@export var scrap_drop := 3
var bestiary_id := "clockwork_needle"

var state := State.RUNNING
var carriage: Node2D
var pin: Node2D
var health: HealthComponent
var stab: Hitbox
var pin_hurt: Hurtbox
var _bar: Line2D
var _dir := 1.0
var _t := 0.0
var _beat_left := 0.0
var _drop := 0.0
var _rest_y := 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"clockwork_needles")
	_build()
	_beat_left = beat * randf_range(0.5, 1.0)
	health.died.connect(_on_snapped)


func _build() -> void:
	var rail := Sprite2D.new()
	rail.texture = RAIL_TEX
	rail.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rail.region_enabled = true
	rail.region_rect = Rect2(0, 0, rail_right - rail_left + 160.0, RAIL_TEX.get_height())
	rail.position = Vector2((rail_left + rail_right) / 2.0, -4)
	add_child(rail)
	health = HealthComponent.new()
	health.name = &"HealthComponent"
	health.max_health = 3
	health.invulnerability_time = 0.18
	add_child(health)
	carriage = Node2D.new()
	add_child(carriage)
	var head := Sprite2D.new()
	head.texture = HEAD_TEX
	head.centered = false
	head.scale = Vector2(SCALE, SCALE)
	head.position = Vector2(-PIN_COLUMN * SCALE, 0)
	_rest_y = PIN_TOP * SCALE
	# The needle bar: steel from the head down to the pin's clamp, so the pin
	# never floats loose when it stabs.
	_bar = Line2D.new()
	_bar.width = 7.0
	_bar.default_color = Color(0.42, 0.43, 0.46)
	carriage.add_child(_bar)
	pin = Node2D.new()
	pin.position = Vector2(0, _rest_y)
	carriage.add_child(pin)
	carriage.add_child(head)
	var pin_art := Sprite2D.new()
	pin_art.texture = PIN_TEX
	pin_art.centered = false
	pin_art.scale = Vector2(SCALE, SCALE)
	pin_art.position = Vector2(-PIN_X * SCALE, 0)
	pin.add_child(pin_art)
	var tip_y := PIN_LENGTH * SCALE
	stab = Hitbox.new()
	stab.collision_layer = 16
	stab.collision_mask = 0
	stab.monitoring = false
	stab.damage = 2
	stab.knockback = 520.0
	stab.active = false
	var point := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 90)
	point.shape = rect
	point.position = Vector2(0, tip_y - 45.0)
	stab.add_child(point)
	pin.add_child(stab)
	pin_hurt = Hurtbox.new()
	pin_hurt.collision_layer = 0
	pin_hurt.collision_mask = 8
	pin_hurt.monitoring = false
	var shaft := CollisionShape2D.new()
	var long := RectangleShape2D.new()
	long.size = Vector2(56, tip_y)
	shaft.shape = long
	shaft.position = Vector2(0, tip_y / 2.0)
	pin_hurt.add_child(shaft)
	pin.add_child(pin_hurt)
	pin_hurt.hit.connect(_on_hit)
	for node: Node in [stab, pin_hurt]:
		node.owner = self
	_draw_bar()


func _physics_process(delta: float) -> void:
	_t = maxf(_t - delta, 0.0)
	match state:
		State.RUNNING, State.SNAPPED:
			carriage.position.x += _dir * speed * delta
			if carriage.position.x > rail_right:
				carriage.position.x = rail_right
				_dir = -1.0
			elif carriage.position.x < rail_left:
				carriage.position.x = rail_left
				_dir = 1.0
			if state == State.RUNNING:
				_beat_left -= delta
				if _beat_left <= 0.0 or _patch_below():
					_start_tell()
		State.TELL:
			pin.position.x = sin(_t * 90.0) * 2.5
			if _t <= 0.0:
				pin.position.x = 0.0
				_start_stab()
		State.STUCK:
			if _t <= 0.0:
				_retract()
	_draw_bar()


func _patch_below() -> bool:
	var patch := get_tree().get_first_node_in_group(&"player") as Node2D
	if patch == null:
		return false
	var local := to_local(patch.global_position)
	return absf(local.x - carriage.position.x) < 36.0 and local.y > 0.0 and local.y < max_drop + 120.0


func _start_tell() -> void:
	state = State.TELL
	_t = tell_time
	AudioManager.play_sfx(&"tab_pull", 0.6, -4.0)
	Tells.glint(self, carriage.position + Vector2(0, _rest_y + PIN_LENGTH * SCALE - 30.0), tell_time)


## How far the pin can go before it meets the floor (or a raised peak).
func _reach() -> float:
	var space := get_world_2d().direct_space_state
	var from := to_global(carriage.position + Vector2(0, _rest_y + PIN_LENGTH * SCALE))
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, max_drop), 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return max_drop
	return maxf((hit["position"] as Vector2).y - from.y, 0.0)


func _start_stab() -> void:
	state = State.STAB
	_drop = _reach()
	stab.active = true
	var tween := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(pin, "position:y", _rest_y + _drop, 0.12)
	await tween.finished
	if state != State.STAB:
		return
	AudioManager.play_sfx(&"heavy", 0.7)
	stab.active = false
	state = State.STUCK
	pin_hurt.monitoring = true
	_t = stuck_time


func _retract() -> void:
	state = State.RETRACT
	pin_hurt.monitoring = false
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(pin, "position:y", _rest_y, 0.45)
	await tween.finished
	if state == State.RETRACT:
		state = State.RUNNING
		_beat_left = beat


func _on_hit(hitbox: Hitbox) -> void:
	if state != State.STUCK:
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		AudioManager.play_sfx(&"parry", 1.3, -4.0)
		var tween := create_tween()
		pin.modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(pin, "modulate", Color.WHITE, 0.15)


## Three cuts and the pin snaps off at the clamp: the machine runs on, toothless.
func _on_snapped() -> void:
	Bestiary.record(self)
	state = State.SNAPPED
	stab.active = false
	pin_hurt.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"enemy_pop", 0.7)
	var broken := pin
	pin = Node2D.new()
	pin.position = Vector2(0, _rest_y)
	carriage.add_child(pin)
	broken.reparent(get_parent())
	var tween := broken.create_tween().set_parallel()
	tween.tween_property(broken, "position:y", broken.position.y + 240.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(broken, "rotation", 0.6 * _dir, 0.5)
	tween.tween_property(broken, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(broken.queue_free)
	const SCRAP := preload("res://scenes/pickups/scrap.tscn")
	for i in scrap_drop:
		var scrap := SCRAP.instantiate() as Collectible
		scrap.persistent = false
		scrap.position = position + carriage.position + Vector2(randf_range(-40, 40), _rest_y + _drop + PIN_LENGTH * SCALE - 30.0)
		get_parent().add_child.call_deferred(scrap)


func _draw_bar() -> void:
	_bar.points = PackedVector2Array([Vector2(0, _rest_y - 30.0), Vector2(pin.position.x, pin.position.y + 6.0)])
