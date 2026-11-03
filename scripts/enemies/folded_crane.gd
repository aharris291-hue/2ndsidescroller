class_name FoldedCrane
extends PaperEnemy
## A Folded Crane: an origami crane of old sheet music with a needle for a beak. It
## circles high over Patch, glows red, and dives beak-first at where he stood: the
## dive can't be guarded or parried, only dodged. A miss drives the needle into the
## ground and leaves it stuck there, open, until it tears itself free.

enum State { CIRCLE, WINDUP, DIVE, STUCK, RISE }

@export var notice_range := 900.0
@export var hover_height := 330.0
@export var hover_time := 2.4
@export var windup := 0.65
@export var dive_speed := 1150.0
@export var stuck_time := 1.6
@export var circle_speed := 320.0

var state := State.CIRCLE
var _state_left := 0.0
var _dive_dir := Vector2.ZERO
var _home := Vector2.ZERO
var _phase := 0.0


func _init() -> void:
	flies = true
	max_health = 4
	max_hold = 3.0
	contact_damage = 1
	body_size = Vector2(90, 60)
	hurt_size = Vector2(150, 90)
	scrap_drop = 3
	knockback_taken = 0.4


func _ready() -> void:
	super._ready()
	_home = global_position
	_state_left = randf_range(1.0, hover_time)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	_phase += delta
	var target := player()
	_state_left -= delta
	match state:
		State.CIRCLE:
			var anchor := _home
			if target and global_position.distance_to(target.global_position) < notice_range:
				anchor = target.global_position + Vector2(sin(_phase * 1.3) * 220.0, -hover_height)
				if _state_left <= 0.0:
					state = State.WINDUP
					_state_left = windup * tempo
					Tells.red_glow(sprite, windup * tempo)
			face(anchor.x - global_position.x)
			var want := (anchor - global_position).limit_length(1.0) * circle_speed
			velocity = velocity.move_toward(want, 800.0 * delta)
			sprite.rotation = lerp_angle(sprite.rotation, 0.0, 6.0 * delta)
		State.WINDUP:
			# Rears back, wings up.
			velocity = velocity.move_toward(Vector2(0, -60), 1000.0 * delta)
			if target:
				_dive_dir = (target.global_position + Vector2(0, -20) - global_position).normalized()
				face(_dive_dir.x)
			if _state_left <= 0.0:
				state = State.DIVE
				_state_left = 1.4
				contact_hitbox.damage = 2
				contact_hitbox.unblockable = true
				AudioManager.play_sfx(&"swipe", 0.7)
		State.DIVE:
			velocity = _dive_dir * dive_speed
			sprite.rotation = _dive_dir.angle() - (PI if _facing < 0.0 else 0.0)
			if get_slide_collision_count() > 0:
				_stick()
			elif _state_left <= 0.0:
				_end_dive(State.RISE, 0.8)
		State.STUCK:
			velocity = Vector2.ZERO
			sprite.position.x = sin(Time.get_ticks_msec() * 0.05) * 2.0
			if _state_left <= 0.0:
				sprite.position.x = 0.0
				_end_dive(State.RISE, 0.8)
		State.RISE:
			velocity = velocity.move_toward(Vector2(0, -360), 1600.0 * delta)
			sprite.rotation = lerp_angle(sprite.rotation, 0.0, 6.0 * delta)
			if _state_left <= 0.0:
				state = State.CIRCLE
				_state_left = randf_range(hover_time * 0.8, hover_time * 1.2) * tempo
	move(delta)


func _stick() -> void:
	_end_dive(State.STUCK, stuck_time)
	AudioManager.play_sfx(&"slam", 1.3)


func _end_dive(next: State, seconds: float) -> void:
	state = next
	_state_left = seconds
	contact_hitbox.damage = contact_damage
	contact_hitbox.unblockable = false


func is_stuck() -> bool:
	return state == State.STUCK


func hurt(_hitbox: Hitbox) -> void:
	if state == State.WINDUP:
		# Cut out of its wind-up: it flinches back up.
		_end_dive(State.RISE, 0.5)
