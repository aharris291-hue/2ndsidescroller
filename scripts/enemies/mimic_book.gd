class_name MimicBook
extends PaperEnemy
## A Mimic Book: it lies closed on the ground like any other old book, until Patch
## comes close. Then it snaps open and lunges (a white glint first: it can be
## parried), and hops after him, biting. A cut while it's still pretending catches
## it out: it takes the hit and opens up early.

enum State { DISGUISED, LUNGE, HOP, BITE_WINDUP, BITE, DAZED }

const CLOSED := preload("res://assets/art/dark/props/book.png")
const OPEN := preload("res://assets/art/dark/enemies/mimic_book.png")

@export var wake_range := 170.0
@export var windup := 0.3
@export var lunge_speed := 620.0
@export var hop_interval := 0.8
@export var bite_range := 130.0

var state := State.DISGUISED
var _state_left := 0.0


func _init() -> void:
	bestiary_id = "mimic_book"
	max_health = 3
	max_hold = 2.0
	contact_damage = 1
	body_size = Vector2(80, 80)
	hurt_size = Vector2(110, 96)
	scrap_drop = 4
	knockback_taken = 0.7


func _ready() -> void:
	super._ready()
	_disguise(true)


func _disguise(on: bool) -> void:
	sprite.texture = CLOSED if on else OPEN
	# The closed book is a prop at its own size; the open one is painted at 2x.
	sprite.scale = Vector2.ONE if on else _sprite_scale
	sprite.position.y = -30.0 if on else -49.0
	contact_hitbox.active = not on


func is_disguised() -> bool:
	return state == State.DISGUISED


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if reeling(delta):
		return
	var target := player()
	_state_left -= delta
	var to_target := target.global_position - global_position if target else Vector2.ZERO
	match state:
		State.DISGUISED:
			velocity.x = 0.0
			if target and to_target.length() < wake_range:
				_wake(to_target)
		State.LUNGE:
			velocity.x = _facing * lunge_speed
			if _state_left <= 0.0:
				_to_hop()
		State.HOP:
			face(to_target.x)
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
				if absf(to_target.x) < bite_range and absf(to_target.y) < 120.0:
					state = State.BITE_WINDUP
					_state_left = windup * tempo
					Tells.glint(self, Vector2(_facing * 40.0, -70), 0.6)
				elif _state_left <= 0.0:
					velocity = Vector2(_facing * 280.0, -560.0)
					_state_left = hop_interval * tempo
		State.BITE_WINDUP:
			velocity.x = 0.0
			if _state_left <= 0.0:
				state = State.BITE
				_state_left = 0.25
				velocity = Vector2(_facing * lunge_speed * 0.7, -200.0)
				AudioManager.play_sfx(&"growl", 1.4)
		State.BITE:
			if _state_left <= 0.0:
				_to_hop()
		State.DAZED:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			if _state_left <= 0.0:
				_to_hop()
	move(delta)


func _wake(to_target: Vector2) -> void:
	_disguise(false)
	face(to_target.x)
	Tells.glint(self, Vector2(_facing * 40.0, -70), 0.8)
	state = State.LUNGE
	_state_left = 0.3
	velocity.y = -300.0
	AudioManager.play_sfx(&"growl", 1.2)


func _to_hop() -> void:
	state = State.HOP
	_state_left = hop_interval * tempo


func hurt(hitbox: Hitbox) -> void:
	if state == State.DISGUISED:
		# Caught out: it snaps open early, reeling.
		_disguise(false)
		face(hitbox.global_position.x - global_position.x)
		state = State.DAZED
		_state_left = 0.8
	elif state == State.BITE_WINDUP:
		_to_hop()


func on_parried(_by: Node) -> void:
	state = State.DAZED
	_state_left = 1.2
	_knockback = Vector2(-_facing * 420.0, -260.0)
