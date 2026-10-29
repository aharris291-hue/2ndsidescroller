class_name Patch
extends CharacterBody2D
## Patch the paper fox. One controller covers both page views:
## SIDE (a standing page: gravity, jumping, coyote time, jump buffering) and
## TOP (a flat page or the Margin: eight-way movement). Attacks, dash, damage
## and interaction work the same in both.

enum State { NORMAL, DASH, ATTACK, HURT, DEAD }

@export_group("Side view")
@export var run_speed := 430.0
@export var ground_acceleration := 2800.0
@export var ground_friction := 3200.0
@export var air_acceleration := 1900.0
@export var gravity := 2300.0
@export var max_fall_speed := 1300.0
@export var jump_velocity := -940.0
## Releasing jump early multiplies upward speed by this, for short hops.
@export var jump_cut := 0.45
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Top view")
@export var walk_speed := 380.0
@export var top_acceleration := 3200.0

@export_group("Combat")
@export var attack_time := 0.18
@export var attack_cooldown := 0.3
@export var attack_reach := 74.0
@export var dash_speed := 1150.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.45
@export var hurt_time := 0.28

var view_mode: PageView.Mode = PageView.Mode.SIDE: set = set_view_mode
var facing := Vector2.RIGHT
var input_enabled := true
## Falling below this y (side view) counts as falling off the page. Set by the Page.
var fall_limit := INF

var state := State.NORMAL
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _state_left := 0.0
var _attack_cooldown_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector2.RIGHT
var _was_on_floor := false
var _last_safe_position := Vector2.ZERO
var _anim_time := 0.0

@onready var visual: Node2D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_hitbox: Hitbox = $AttackHitbox
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	health.max_health = GameState.max_health
	health.set_health(GameState.health)
	health.changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hit.connect(_on_hurtbox_hit)
	attack_hitbox.active = false
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.player_health_changed.emit(health.current, health.max_health)
	_last_safe_position = global_position


func set_view_mode(mode: PageView.Mode) -> void:
	view_mode = mode
	motion_mode = MOTION_MODE_FLOATING if mode == PageView.Mode.TOP else MOTION_MODE_GROUNDED
	if mode == PageView.Mode.TOP:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_state_left = maxf(_state_left - delta, 0.0)

	match state:
		State.NORMAL:
			_process_normal(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DASH:
			_process_dash()
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, ground_friction * delta)

	move_and_slide()
	_after_move()
	_update_visual(delta)


func _move_input() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func _action_pressed(action: StringName) -> bool:
	return input_enabled and Input.is_action_just_pressed(action)


# --- States ------------------------------------------------------------------

func _process_normal(delta: float) -> void:
	var input := _move_input()
	if view_mode == PageView.Mode.SIDE:
		_side_movement(input.x, delta)
	else:
		_top_movement(input, delta)

	if _action_pressed(&"attack") and _attack_cooldown_left <= 0.0 and GameState.has_ability(&"crease_swipe"):
		_start_attack()
	elif _action_pressed(&"dash") and _dash_cooldown_left <= 0.0 and GameState.has_ability(&"fold_dash"):
		_start_dash(input)
	elif _action_pressed(&"interact"):
		_try_interact()


func _side_movement(input_x: float, delta: float) -> void:
	if input_x != 0.0:
		facing = Vector2(signf(input_x), 0)
	var target := input_x * run_speed
	var rate := ground_acceleration if is_on_floor() else air_acceleration
	if input_x == 0.0 and is_on_floor():
		rate = ground_friction
	velocity.x = move_toward(velocity.x, target, rate * delta)
	_apply_gravity(delta)

	# Coyote time: a short grace period to jump after walking off a ledge.
	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	# Jump buffer: a jump pressed just before landing still counts.
	if _action_pressed(&"jump"):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		AudioManager.play_sfx(&"jump", randf_range(0.95, 1.05))
		_squash(Vector2(0.8, 1.2))
	if velocity.y < 0.0 and Input.is_action_just_released(&"jump"):
		velocity.y *= jump_cut


func _top_movement(input: Vector2, delta: float) -> void:
	if input != Vector2.ZERO:
		# Snap facing to four directions so attacks read clearly.
		facing = Vector2(signf(input.x), 0) if absf(input.x) >= absf(input.y) else Vector2(0, signf(input.y))
	velocity = velocity.move_toward(input * walk_speed, top_acceleration * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _start_attack() -> void:
	state = State.ATTACK
	_state_left = attack_time
	_attack_cooldown_left = attack_cooldown
	var offset := facing * attack_reach
	if view_mode == PageView.Mode.SIDE:
		offset.y -= 6.0
	attack_hitbox.position = offset
	attack_hitbox.rotation = facing.angle()
	attack_hitbox.active = true
	AudioManager.play_sfx(&"swipe", randf_range(0.9, 1.15))
	_squash(Vector2(1.15, 0.9))


func _process_attack(delta: float) -> void:
	# Patch can still drift and fall mid-swipe, just more slowly.
	if view_mode == PageView.Mode.SIDE:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.5 * delta)
		_apply_gravity(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, top_acceleration * delta)
	if _state_left <= 0.0:
		attack_hitbox.active = false
		state = State.NORMAL


func _start_dash(input: Vector2) -> void:
	state = State.DASH
	_state_left = dash_time
	_dash_cooldown_left = dash_cooldown
	if view_mode == PageView.Mode.SIDE:
		_dash_direction = Vector2(signf(input.x) if input.x != 0.0 else facing.x, 0)
	else:
		_dash_direction = input.normalized() if input != Vector2.ZERO else facing
	AudioManager.play_sfx(&"swipe", 0.7)
	_squash(Vector2(1.35, 0.7))


func _process_dash() -> void:
	# Fold Dash: Patch folds into a paper dart. No gravity while dashing.
	velocity = _dash_direction * dash_speed
	if _state_left <= 0.0:
		velocity *= 0.35
		state = State.NORMAL


func _process_hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, ground_friction * 0.6 * delta)
	if view_mode == PageView.Mode.SIDE:
		_apply_gravity(delta)
	if _state_left <= 0.0:
		state = State.NORMAL


func _after_move() -> void:
	if view_mode == PageView.Mode.SIDE:
		var on_floor := is_on_floor()
		if on_floor and not _was_on_floor:
			_squash(Vector2(1.2, 0.82))
		if on_floor and state == State.NORMAL:
			_last_safe_position = global_position
		_was_on_floor = on_floor
		if global_position.y > fall_limit and state != State.DEAD:
			_fell_off_page()
	elif state == State.NORMAL:
		_last_safe_position = global_position


func _fell_off_page() -> void:
	global_position = _last_safe_position + Vector2(-facing.x * 48.0, -24.0)
	velocity = Vector2.ZERO
	health.take_damage(1, global_position)


# --- Damage, death, interaction --------------------------------------------

func _on_hurtbox_hit(hitbox: Hitbox) -> void:
	if state == State.DASH or state == State.DEAD:
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		var away := (global_position - hitbox.global_position).normalized()
		if view_mode == PageView.Mode.SIDE:
			away = Vector2(signf(away.x) if away.x != 0.0 else -facing.x, -0.6).normalized()
		velocity = away * hitbox.knockback


func _on_damaged(_amount: int, _from: Vector2) -> void:
	if health.is_dead():
		return
	state = State.HURT
	_state_left = hurt_time
	attack_hitbox.active = false
	AudioManager.play_sfx(&"hurt")


func _on_health_changed(current: int, maximum: int) -> void:
	GameState.health = current
	EventBus.player_health_changed.emit(current, maximum)


func _on_died() -> void:
	state = State.DEAD
	input_enabled = false
	attack_hitbox.active = false
	AudioManager.play_sfx(&"hurt", 0.7)
	EventBus.player_died.emit()
	var tween := create_tween()
	tween.tween_property(visual, "rotation", deg_to_rad(90.0) * facing.x, 0.4)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.8)
	await tween.finished
	SceneManager.respawn_at_checkpoint()


func _try_interact() -> void:
	var best: Interactable = null
	var best_distance := INF
	for area in interact_area.get_overlapping_areas():
		var target := area as Interactable
		if target and target.can_interact():
			var distance := global_position.distance_squared_to(target.global_position)
			if distance < best_distance:
				best = target
				best_distance = distance
	if best:
		best.interact(self)


func _on_dialogue_started() -> void:
	input_enabled = false
	velocity.x = 0.0
	if view_mode == PageView.Mode.TOP:
		velocity = Vector2.ZERO


func _on_dialogue_finished() -> void:
	# Wait a moment so the button that closed the dialogue doesn't also act in-game.
	await get_tree().create_timer(0.15).timeout
	if state != State.DEAD:
		input_enabled = true


# --- Paper-puppet animation --------------------------------------------------

func _squash(amount: Vector2) -> void:
	var sign_x := signf(visual.scale.x) if visual.scale.x != 0.0 else 1.0
	visual.scale = Vector2(amount.x * sign_x, amount.y)


func _update_visual(delta: float) -> void:
	# Patch is a flat paper cut-out, so he animates like a puppet:
	# flip to face, bob while walking, tilt into movement, and spring back from squashes.
	if state == State.DEAD:
		return
	var dir := signf(facing.x) if facing.x != 0.0 else signf(visual.scale.x)
	var target_scale := Vector2(dir, 1.0)
	visual.scale = Vector2(
		move_toward(absf(visual.scale.x), 1.0, 4.0 * delta) * dir,
		move_toward(visual.scale.y, target_scale.y, 4.0 * delta))

	var moving := velocity.length() > 40.0
	var grounded := view_mode == PageView.Mode.TOP or is_on_floor()
	_anim_time += delta * (12.0 if moving else 3.0)
	var bob := absf(sin(_anim_time)) * (7.0 if moving and grounded else 1.5)
	visual.position.y = -bob
	var tilt := 0.0
	if view_mode == PageView.Mode.SIDE:
		tilt = clampf(velocity.x / run_speed, -1.0, 1.0) * 0.08
		if not is_on_floor():
			tilt += clampf(velocity.y / max_fall_speed, -1.0, 1.0) * 0.12 * dir
	if state == State.DASH:
		tilt = 0.0
	visual.rotation = lerpf(visual.rotation, tilt, 12.0 * delta)
	# Flash while invulnerable after a hit.
	var blink := Time.get_ticks_msec() % 160 < 80
	visual.modulate.a = 0.45 if health.is_invulnerable() and blink else 1.0
