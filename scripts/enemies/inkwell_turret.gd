class_name InkwellTurret
extends PaperEnemy
## An Inkwell Turret: a cracked cut-glass inkwell with a pen nib for a barrel. It
## never moves; it turns to face Patch and fires a straight shot of ink after a white
## glint at the nib. Close in and cut it, or cut the shot to send it straight back.

const SHOT_SCENE := preload("res://scenes/enemies/ink_shot.tscn")
## The nib's tip, relative to the turret's feet, when it faces left.
const NIB := Vector2(-88, -96)

@export var fire_range := 900.0
@export var fire_interval := 2.6
@export var windup := 0.55
@export var shot_speed := 520.0

var _fire_left := 1.5
var _windup_left := 0.0


func _init() -> void:
	max_health = 5
	max_hold = 4.0
	contact_damage = 1
	body_size = Vector2(120, 110)
	hurt_size = Vector2(150, 120)
	scrap_drop = 3
	knockback_taken = 0.0


func _ready() -> void:
	super._ready()
	_fire_left = randf_range(0.8, fire_interval)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	velocity.x = 0.0
	var target := player()
	if target == null or is_staggered():
		move(delta)
		return
	var to_target := target.global_position - global_position
	if _windup_left <= 0.0:
		face(to_target.x)
	if _windup_left > 0.0:
		_windup_left -= delta
		sprite.position.x = sin(Time.get_ticks_msec() * 0.09) * 3.0
		if _windup_left <= 0.0:
			sprite.position.x = 0.0
			_fire()
	else:
		_fire_left -= delta
		if _fire_left <= 0.0 and to_target.length() < fire_range:
			_fire_left = fire_interval * tempo
			_windup_left = windup * tempo
			Tells.glint(self, nib(), 0.8)
	move(delta)


func nib() -> Vector2:
	return Vector2(NIB.x * -_facing, NIB.y)


func _fire() -> void:
	var shot := SHOT_SCENE.instantiate() as InkShot
	shot.position = position + nib()
	shot.use_gravity = false
	var target := player()
	var aim := Vector2(_facing, 0)
	if target:
		aim = (target.global_position + Vector2(0, -60) - (global_position + nib())).normalized()
		# Mostly level: a turret, not a mortar.
		aim = Vector2(signf(aim.x) if aim.x != 0.0 else _facing, clampf(aim.y, -0.35, 0.35)).normalized()
	shot.velocity = aim * shot_speed
	get_parent().add_child(shot)
	AudioManager.play_sfx(&"swipe", 0.5)


func hurt(_hitbox: Hitbox) -> void:
	_windup_left = 0.0
	sprite.position.x = 0.0
	_fire_left = maxf(_fire_left, 0.9)
