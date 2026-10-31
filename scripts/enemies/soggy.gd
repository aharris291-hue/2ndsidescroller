class_name Soggy
extends CharacterBody2D
## A Soggy: a wad of waterlogged paper sent by the Sogg. The basic enemy.
## On a standing page it patrols and turns at walls and ledges until it spots Patch,
## then charges, and when it's close it crouches (a tell) and lunges. On a flat page it
## wanders and chases Patch when he gets close. Drops Scraps when dried out (defeated).

const SCRAP_SCENE := preload("res://scenes/pickups/scrap.tscn")

@export var patrol_speed := 130.0
@export var chase_speed := 235.0
@export var chase_range := 540.0
@export var gravity := 2000.0
@export var scrap_drop := 2
## Side view: how far ahead (and how far up or down) it notices Patch.
@export var notice_range := 460.0
@export var notice_height := 150.0
## The lunge: how close it has to be, the crouch before it, and the leap itself.
@export var lunge_range := 210.0
@export var lunge_windup := 0.35
@export var lunge_speed := Vector2(560.0, -560.0)
@export var lunge_cooldown := 1.4

var view_mode: PageView.Mode = PageView.Mode.SIDE
var _direction := -1.0
var _knockback := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_left := 0.0
var _home := Vector2.ZERO
var _windup_left := 0.0
var _lunge_cooldown_left := 0.0
var _lunging := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var _sprite_scale := sprite.scale
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
	if _windup_left > 0.0:
		wobble = 0.18 + sin(Time.get_ticks_msec() * 0.06) * 0.05
	sprite.scale = _sprite_scale * Vector2(1.0 + wobble, 1.0 - wobble)


func _side_behaviour(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif _lunging:
		_lunging = false
	if _lunging:
		return
	_lunge_cooldown_left = maxf(_lunge_cooldown_left - delta, 0.0)
	if _windup_left > 0.0:
		# Crouched and shaking: the tell before a lunge.
		_windup_left -= delta
		velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
		sprite.modulate = Color(1.0, 0.75, 0.75)
		if _windup_left <= 0.0:
			sprite.modulate = Color.WHITE
			_lunging = true
			_lunge_cooldown_left = lunge_cooldown
			velocity = Vector2(lunge_speed.x * _direction, lunge_speed.y)
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and is_on_floor():
		var to_player := player.global_position - global_position
		if absf(to_player.x) < notice_range and absf(to_player.y) < notice_height:
			_direction = signf(to_player.x) if to_player.x != 0.0 else _direction
			ledge_check.position.x = 40.0 * _direction
			if absf(to_player.x) < lunge_range and _lunge_cooldown_left <= 0.0:
				_windup_left = lunge_windup
				return
			# Charge, but don't run off a ledge after him.
			velocity.x = chase_speed * _direction if ledge_check.is_colliding() and not is_on_wall() else 0.0
			return
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
		# A hit knocks it out of a lunge wind-up.
		_windup_left = 0.0
		sprite.modulate = Color.WHITE
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
	tween.tween_property(sprite, "scale", _sprite_scale * Vector2(1.4, 0.2), 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
