class_name PaperMoth
extends PaperEnemy
## A Paper Moth: a moth folded from drowned book pages. They come in swarms, flutter
## just out of reach above Patch, and dart in one at a time after a white glint (a
## parry, or a quick cut, swats one). One cut tears a moth; a slow heavy cut gives the
## rest of the swarm time to dart, so quick cuts are the answer.

enum State { FLUTTER, WINDUP, DART, RECOVER }

@export var notice_range := 720.0
@export var dart_interval := 2.6
@export var windup := 0.4
@export var dart_speed := 640.0
@export var dart_time := 0.45
@export var flutter_speed := 260.0

var state := State.FLUTTER
var _home := Vector2.ZERO
var _state_left := 0.0
var _phase := 0.0
var _dart_dir := Vector2.ZERO


func _init() -> void:
	flies = true
	max_health = 1
	max_hold = 1.0
	contact_damage = 1
	body_size = Vector2(56, 40)
	hurt_size = Vector2(110, 80)
	scrap_drop = 1
	knockback_taken = 1.0


func _ready() -> void:
	super._ready()
	_home = global_position
	_phase = randf() * TAU
	_state_left = randf_range(0.5, dart_interval)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if reeling(delta):
		return
	_phase += delta * 6.0
	# Wings beat: a quick squash, so a swarm never moves in step.
	sprite.scale = _sprite_scale * Vector2(1.0, 0.8 + 0.2 * absf(sin(_phase)))
	var target := player()
	_state_left -= delta
	match state:
		State.FLUTTER:
			var anchor := _home + Vector2(0, -40)
			if target and global_position.distance_to(target.global_position) < notice_range:
				var side := signf(global_position.x - target.global_position.x)
				anchor = target.global_position + Vector2((side if side != 0.0 else 1.0) * 170.0, -170.0)
				face(target.global_position.x - global_position.x)
				if _state_left <= 0.0:
					state = State.WINDUP
					_state_left = windup * tempo
					Tells.glint(self, Vector2(0, -50), 0.6)
			anchor += Vector2(cos(_phase * 0.4) * 40.0, sin(_phase * 0.7) * 30.0)
			var want := (anchor - global_position).limit_length(1.0) * flutter_speed
			velocity = velocity.move_toward(want, 900.0 * delta)
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
			if _state_left <= 0.0:
				state = State.DART
				_state_left = dart_time
				var aim := (target.global_position + Vector2(0, -50)) if target else global_position
				_dart_dir = (aim - global_position).normalized()
				face(_dart_dir.x)
				AudioManager.play_sfx(&"swipe", 1.5)
		State.DART:
			velocity = _dart_dir * dart_speed
			if _state_left <= 0.0 or get_slide_collision_count() > 0:
				state = State.RECOVER
				_state_left = 0.5
		State.RECOVER:
			velocity = velocity.move_toward(Vector2(0, -120), 1200.0 * delta)
			if _state_left <= 0.0:
				state = State.FLUTTER
				_state_left = randf_range(dart_interval * 0.7, dart_interval * 1.3) * tempo
	move(delta)


func hurt(_hitbox: Hitbox) -> void:
	state = State.RECOVER
	_state_left = 0.6


func on_parried(_by: Node) -> void:
	state = State.RECOVER
	_state_left = 1.0
	_knockback = -_dart_dir * 500.0
