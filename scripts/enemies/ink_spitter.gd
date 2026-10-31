class_name InkSpitter
extends CharacterBody2D
## An Ink Spitter: a cracked ink bottle that plants itself and lobs gobs of ink at
## Patch whenever he's in range. It swells before each throw (the tell). Slow and
## fragile up close, dangerous at a distance, so the answer is to close in.

const BLOB_SCENE := preload("res://scenes/enemies/ink_blob.tscn")
const SCRAP_SCENE := preload("res://scenes/pickups/scrap.tscn")

@export var fire_range := 780.0
@export var fire_interval := 2.2
@export var windup := 0.45
## Side view: how long a lobbed gob takes to arrive, at the shortest and longest range.
@export var flight_time := Vector2(0.55, 1.1)
@export var top_shot_speed := 460.0
@export var gravity := 2000.0
@export var scrap_drop := 2

var view_mode: PageView.Mode = PageView.Mode.SIDE
var _fire_left := 1.0
var _windup_left := 0.0
var _knockback := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var _sprite_scale := sprite.scale
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox


func _ready() -> void:
	var page := get_tree().get_first_node_in_group("page") as Page
	if page:
		view_mode = page.view_mode
	if view_mode == PageView.Mode.TOP:
		motion_mode = MOTION_MODE_FLOATING
	_fire_left = randf_range(0.6, fire_interval)
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if view_mode == PageView.Mode.SIDE and not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = _knockback.x
	if view_mode == PageView.Mode.TOP:
		velocity = _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 3000.0 * delta)
	move_and_slide()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	sprite.flip_h = to_player.x > 0.0
	if _windup_left > 0.0:
		_windup_left -= delta
		var swell := 1.0 + (1.0 - _windup_left / windup) * 0.25
		sprite.scale = _sprite_scale * Vector2(swell, 2.0 - swell)
		if _windup_left <= 0.0:
			sprite.scale = _sprite_scale
			_throw(to_player)
		return
	_fire_left -= delta
	if _fire_left <= 0.0 and to_player.length() < fire_range:
		_fire_left = fire_interval
		_windup_left = windup


func _throw(to_player: Vector2) -> void:
	var blob := BLOB_SCENE.instantiate() as InkBlob
	blob.position = position + Vector2(0, -60)
	var aim := to_player + Vector2(0, -30) - Vector2(0, -60)
	if view_mode == PageView.Mode.SIDE:
		var t := lerpf(flight_time.x, flight_time.y, clampf(aim.length() / fire_range, 0.0, 1.0))
		blob.velocity = Vector2(aim.x / t, aim.y / t - 0.5 * blob.fall_gravity * t)
	else:
		blob.use_gravity = false
		blob.velocity = aim.normalized() * top_shot_speed
	get_parent().add_child(blob)
	AudioManager.play_sfx(&"swipe", 0.55)


func _on_hit(hitbox: Hitbox) -> void:
	if health.take_damage(hitbox.damage, hitbox.global_position):
		_windup_left = 0.0
		sprite.scale = _sprite_scale
		_fire_left = maxf(_fire_left, 0.8)
		var away := (global_position - hitbox.global_position).normalized()
		_knockback = away * hitbox.knockback * 0.5
		var tween := create_tween()
		sprite.modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	contact_hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"enemy_pop", 0.8)
	for i in scrap_drop:
		var scrap := SCRAP_SCENE.instantiate() as Collectible
		scrap.persistent = false
		scrap.position = position + Vector2(randf_range(-40, 40), randf_range(-60, -20))
		get_parent().add_child.call_deferred(scrap)
	# The bottle cracks and its ink drains away.
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", _sprite_scale * Vector2(1.3, 0.1), 0.3)
	tween.tween_property(sprite, "modulate", Color(0.2, 0.2, 0.4, 0.0), 0.35)
	tween.chain().tween_callback(queue_free)
