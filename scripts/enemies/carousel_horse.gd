class_name CarouselHorse
extends PaperEnemy
## A Carousel Horse (Gatefold Fair): torn loose from the carousel with its brass pole
## still through it, it goes round and round on its own now, bounding on the pole like
## a pogo. It paces in short hops; when Patch is near it rears (a white glint) and
## charges in three long bounds, landing hard on each. The charge can be guarded and
## parried: a parry, or running it into a wall, topples it onto its side, open to the
## shears until it rights itself.

enum State { PACE, REAR, CHARGE, TOPPLED, RIGHTING }

@export var notice_range := 820.0
@export var pace_hop := Vector2(160.0, -420.0)
@export var charge_hop := Vector2(620.0, -560.0)
@export var rear_time := 0.55
@export var toppled_time := 1.8
@export var rest_time := 1.2

var state := State.PACE
var bounds := 0
var _state_left := 0.0
var _was_on_floor := true


func _init() -> void:
	bestiary_id = "carousel_horse"
	max_health = 5
	max_hold = 3.5
	contact_damage = 1
	body_size = Vector2(110, 150)
	hurt_size = Vector2(170, 170)
	scrap_drop = 3
	knockback_taken = 0.35


func _ready() -> void:
	super._ready()
	_state_left = randf_range(0.4, rest_time)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if reeling(delta):
		return
	var target := player()
	var dx := (target.global_position.x - global_position.x) if target else 0.0
	_state_left -= delta
	var landed := is_on_floor() and not _was_on_floor
	match state:
		State.PACE:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
				if _state_left <= 0.0:
					face(dx)
					if target and absf(dx) < notice_range and absf(target.global_position.y - global_position.y) < 300.0:
						_rear()
					else:
						velocity = Vector2(pace_hop.x * _facing, pace_hop.y)
						_state_left = rest_time * 0.6
			if landed:
				AudioManager.play_sfx(&"slam", 1.6, -10.0)
		State.REAR:
			velocity.x = 0.0
			sprite.rotation = lerpf(sprite.rotation, 0.35 * _facing, 10.0 * delta)
			if _state_left <= 0.0:
				state = State.CHARGE
				bounds = 0
				contact_hitbox.damage = 2
				_bound()
		State.CHARGE:
			sprite.rotation = lerpf(sprite.rotation, -0.15 * _facing, 8.0 * delta)
			if is_on_wall():
				_topple()
			elif landed:
				AudioManager.play_sfx(&"slam", 0.9, -4.0)
				if bounds >= 3:
					state = State.PACE
					contact_hitbox.damage = contact_damage
					_state_left = rest_time * tempo
				else:
					_bound()
		State.TOPPLED:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			if _state_left <= 0.0 and not hold.is_broken():
				state = State.RIGHTING
				_state_left = 0.4
		State.RIGHTING:
			sprite.rotation = lerpf(sprite.rotation, 0.0, 12.0 * delta)
			if _state_left <= 0.0:
				sprite.rotation = 0.0
				state = State.PACE
				contact_hitbox.active = true
				_state_left = rest_time
	if state != State.REAR and state != State.TOPPLED and state != State.CHARGE:
		sprite.rotation = lerpf(sprite.rotation, 0.0, 8.0 * delta)
	_was_on_floor = is_on_floor()
	move(delta)


func _rear() -> void:
	state = State.REAR
	_state_left = rear_time * tempo
	Tells.glint(self, Vector2(-60 * _facing, -150), 0.7)
	AudioManager.play_sfx(&"growl", 1.4, -6.0)


func _bound() -> void:
	bounds += 1
	var target := player()
	if target:
		face(target.global_position.x - global_position.x)
	velocity = Vector2(charge_hop.x * _facing, charge_hop.y)


func _topple() -> void:
	state = State.TOPPLED
	_state_left = toppled_time
	contact_hitbox.damage = contact_damage
	contact_hitbox.active = false
	velocity.x = -_facing * 200.0
	var tween := create_tween()
	tween.tween_property(sprite, "rotation", 1.45 * -_facing, 0.25).set_trans(Tween.TRANS_BACK)
	AudioManager.play_sfx(&"slam", 0.7)
	hold.take_hold(1.5)


## A parried bound throws it off its pole's balance.
func on_parried(_by: Node) -> void:
	if state == State.CHARGE or state == State.REAR:
		_topple()


func is_toppled() -> bool:
	return state == State.TOPPLED


func hurt(_hitbox: Hitbox) -> void:
	if state == State.REAR:
		# Cut out of its rear: it drops back to pacing.
		state = State.PACE
		_state_left = rest_time
