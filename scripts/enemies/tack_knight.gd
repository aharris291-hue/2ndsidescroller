class_name TackKnight
extends CharacterBody2D
## A Tack Knight: a cardboard soldier with a bottle-cap shield and a pencil lance.
## Swipes from the front clang off the shield. Get behind it, break its guard with
## the heavy third hit of a combo, or dodge its charge: after a charge it's dazed and
## open from every side.

enum State { PATROL, WINDUP, CHARGE, DAZED }

const SCRAP_SCENE := preload("res://scenes/pickups/scrap.tscn")

@export var patrol_speed := 90.0
@export var charge_speed := 640.0
@export var notice_range := 560.0
@export var notice_height := 160.0
@export var windup_time := 0.6
@export var charge_time := 1.3
@export var dazed_time := 1.5
@export var gravity := 2000.0
@export var scrap_drop := 4
## Hits that get through the shield from the front anyway (the combo finisher, a slam).
@export var guard_break_damage := 2

var state := State.PATROL
var view_mode: PageView.Mode = PageView.Mode.SIDE
var _direction := -1.0
var _aim := Vector2.LEFT
var _state_left := 0.0
var _knockback := Vector2.ZERO
var _clang_left := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var _sprite_scale := sprite.scale
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var ledge_check: RayCast2D = $LedgeCheck


func _ready() -> void:
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
	if view_mode == PageView.Mode.SIDE and not is_on_floor():
		velocity.y += gravity * delta
	_state_left -= delta
	_clang_left = maxf(_clang_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	match state:
		State.PATROL:
			_patrol(player)
		State.WINDUP:
			_set_speed(0.0)
			sprite.position.x = sin(Time.get_ticks_msec() * 0.08) * 4.0
			if _state_left <= 0.0:
				sprite.position.x = 0.0
				state = State.CHARGE
				_state_left = charge_time
				AudioManager.play_sfx(&"swipe", 0.6)
		State.CHARGE:
			_set_speed(charge_speed)
			var blocked := is_on_wall() or (view_mode == PageView.Mode.SIDE and is_on_floor() and not ledge_check.is_colliding())
			if _state_left <= 0.0 or blocked:
				_daze(blocked)
		State.DAZED:
			_set_speed(0.0)
			sprite.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.12
			if _state_left <= 0.0:
				sprite.rotation = 0.0
				state = State.PATROL
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 3000.0 * delta)
	move_and_slide()
	sprite.flip_h = _direction < 0.0
	ledge_check.position.x = 50.0 * _direction


func _patrol(player: Node2D) -> void:
	if player:
		var to_player := player.global_position - global_position
		var noticed := false
		if view_mode == PageView.Mode.SIDE:
			noticed = absf(to_player.x) < notice_range and absf(to_player.y) < notice_height
		else:
			noticed = to_player.length() < notice_range
		if noticed:
			_aim = to_player.normalized() if view_mode == PageView.Mode.TOP else Vector2(signf(to_player.x), 0)
			if _aim.x != 0.0:
				_direction = signf(_aim.x)
			state = State.WINDUP
			_state_left = windup_time
			return
	if view_mode == PageView.Mode.SIDE and is_on_floor() and (is_on_wall() or not ledge_check.is_colliding()):
		_direction = -_direction
	_aim = Vector2(_direction, 0)
	_set_speed(patrol_speed)


func _set_speed(speed: float) -> void:
	if view_mode == PageView.Mode.SIDE:
		velocity.x = speed * _direction
	else:
		velocity = _aim * speed


func _daze(hit_something: bool) -> void:
	state = State.DAZED
	_state_left = dazed_time
	if hit_something:
		AudioManager.play_sfx(&"slam", 0.9)


func _on_hit(hitbox: Hitbox) -> void:
	var from_front := signf(hitbox.global_position.x - global_position.x) == _direction
	if view_mode == PageView.Mode.TOP:
		from_front = (hitbox.global_position - global_position).normalized().dot(_aim) > 0.3
	if from_front and state != State.DAZED and hitbox.damage < guard_break_damage:
		if _clang_left > 0.0:
			return
		# Clang: the shield turns the blow and shoves Patch back.
		_clang_left = 0.2
		AudioManager.play_sfx(&"tab_pull", 1.6)
		var player := hitbox.owner as Patch
		if player:
			player.velocity = (player.global_position - global_position).normalized() * 520.0
		var flash := create_tween()
		sprite.modulate = Color(1.0, 0.9, 0.5)
		flash.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		if from_front and state != State.DAZED:
			# Guard broken.
			_daze(false)
		var away := (global_position - hitbox.global_position).normalized()
		_knockback = away * hitbox.knockback * 0.35
		var tween := create_tween()
		sprite.modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	contact_hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"enemy_pop", 0.6)
	for i in scrap_drop:
		var scrap := SCRAP_SCENE.instantiate() as Collectible
		scrap.persistent = false
		scrap.position = position + Vector2(randf_range(-50, 50), randf_range(-70, -20))
		get_parent().add_child.call_deferred(scrap)
	# It folds flat and topples over.
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "rotation", -1.4 * _direction, 0.4).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
