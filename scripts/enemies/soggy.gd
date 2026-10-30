class_name Soggy
extends CharacterBody2D
## A Soggy: a wad of waterlogged paper sent by the Sogg. The basic enemy.
## On a standing page it patrols and turns at walls and ledges; on a flat page it
## wanders and chases Patch when he gets close. Drops Scraps when dried out (defeated).

const SCRAP_SCENE := preload("res://scenes/pickups/scrap.tscn")

@export var patrol_speed := 130.0
@export var chase_speed := 235.0
@export var chase_range := 540.0
@export var gravity := 2000.0
@export var scrap_drop := 2

var view_mode: PageView.Mode = PageView.Mode.SIDE
var _direction := -1.0
var _knockback := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_left := 0.0
var _home := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var ledge_check: RayCast2D = $LedgeCheck


func _ready() -> void:
	_home = global_position
	var page := get_tree().get_first_node_in_group("page") as Page
	if page:
		view_mode = page.view_mode
	if view_mode == PageView.Mode.TOP:
		motion_mode = MOTION_MODE_FLOATING
		ledge_check.enabled = false
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if view_mode == PageView.Mode.SIDE:
		_side_behaviour(delta)
	else:
		_top_behaviour(delta)
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 3000.0 * delta)
	move_and_slide()
	sprite.flip_h = _direction > 0.0
	# Squishy wobble while moving.
	var wobble := sin(Time.get_ticks_msec() * 0.012) * 0.06
	sprite.scale = Vector2(1.0 + wobble, 1.0 - wobble)


func _side_behaviour(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	ledge_check.position.x = 40.0 * _direction
	if is_on_floor() and (is_on_wall() or not ledge_check.is_colliding()):
		_direction = -_direction
		ledge_check.position.x = 40.0 * _direction
	velocity.x = patrol_speed * _direction


func _top_behaviour(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and global_position.distance_to(player.global_position) < chase_range:
		var to_player := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * chase_speed, 900.0 * delta)
		_direction = signf(to_player.x) if to_player.x != 0.0 else _direction
		return
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(1.0, 2.5)
		var back_home := (_home - global_position).limit_length(1.0) * 0.6
		_wander = (Vector2.from_angle(randf() * TAU) + back_home).normalized() * patrol_speed
	velocity = velocity.move_toward(_wander, 600.0 * delta)
	if _wander.x != 0.0:
		_direction = signf(_wander.x)


func _on_hit(hitbox: Hitbox) -> void:
	if health.take_damage(hitbox.damage, hitbox.global_position):
		var away := (global_position - hitbox.global_position).normalized()
		_knockback = away * hitbox.knockback * 0.6
		if view_mode == PageView.Mode.SIDE:
			_knockback.y = -200.0
		var tween := create_tween()
		sprite.modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	contact_hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"enemy_pop", randf_range(0.9, 1.1))
	for i in scrap_drop:
		var scrap := SCRAP_SCENE.instantiate() as Collectible
		scrap.persistent = false
		scrap.position = position + Vector2(randf_range(-40, 40), randf_range(-50, -10))
		get_parent().add_child.call_deferred(scrap)
	# Dried out: the wad shrinks and puffs away.
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.2), 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
