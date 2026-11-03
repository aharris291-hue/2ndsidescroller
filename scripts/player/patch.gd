class_name Patch
extends CharacterBody2D
## Patch the paper fox, armed with Gran's stork shears. One controller covers both
## page views: SIDE (a standing page: gravity, jumping, coyote time, jump buffering)
## and TOP (a flat page or the Margin: eight-way movement).
##
## Combat (see the Redesign Bible, Phase 2): a 4-hit light combo (3 in the air),
## heavy and charged heavy cuts, an up-heavy launcher, the Plunge (down + heavy in
## the air), the Edge-On dodge (perfect dodges slow time), guard and parry, the
## Thread meter (hits fill it; Mend spends a charge to heal) and the Unstitch
## finisher on enemies whose Hold has broken.

enum State { NORMAL, DASH, ATTACK, HURT, DEAD, GRAPPLE, SLAM, HEAVY, GUARD, MEND, FINISHER }
enum Attack { LIGHT, THRUST, AIR, OVERHEAD, HEAVY, LAUNCHER, CHARGED, PLUNGE }
enum Grapple { SHOOT, ZIP, RETRACT }
## What each kind of cut counts as on the style meter.
const STYLE_MOVES := {
	Attack.LIGHT: &"light", Attack.THRUST: &"thrust", Attack.AIR: &"air",
	Attack.OVERHEAD: &"overhead", Attack.HEAVY: &"heavy", Attack.LAUNCHER: &"launcher",
	Attack.CHARGED: &"charged", Attack.PLUNGE: &"plunge",
}

## After the finale Patch has a new tail: a strip of the Lanternfold map, taped on.

@export_group("Side view")
@export var run_speed := 430.0
@export var ground_acceleration := 2800.0
@export var ground_friction := 3200.0
@export var air_acceleration := 1900.0
@export var gravity := 2300.0
@export var max_fall_speed := 1300.0
## How much of a jump Patch gets off soaked paper.
const SOFT_JUMP := 0.6
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
## How long each swipe's hitbox is live (shorter than the swipe, so one swipe hits once).
@export var attack_active_time := 0.07
## Light cuts chain into a four-hit combo on the ground (the fourth is a thrust),
## three in the air.
@export var combo_window := 0.35
@export var combo_length := 4
@export var air_combo_length := 3
@export var finisher_damage := 2
@export var finisher_knockback := 1.7
@export var hurt_time := 0.28

@export_group("Heavy")
@export var heavy_windup := 0.12
@export var heavy_recover := 0.24
@export var heavy_damage := 2
@export var heavy_hold := 3.0
## Hold heavy this long for charge levels 1, 2 and 3 (level 3 is the Full Cut).
@export var charge_levels: Array[float] = [0.45, 0.9, 1.4]
@export var charge_damage: Array[int] = [3, 4, 5]
@export var charge_hold: Array[float] = [4.0, 5.0, 8.0]

@export_group("Edge-On dodge")
@export var dash_speed := 950.0
@export var dash_time := 0.25
@export var dash_cooldown := 0.35
## A hit that arrives this early in a dodge counts as a perfect dodge.
@export var perfect_dodge_window := 0.12

@export_group("Guard")
## Guard pressed this close before a hit lands is a parry (8 frames).
@export var parry_window := 0.133
@export var parry_hold := 4.0
@export var guard_push := 320.0

@export_group("Thread")
@export var mend_time := 1.2
@export var mend_heal := 2
## How far ahead a staggered enemy can be and still be Unstitched.
@export var finisher_range := 170.0

@export_group("Tape Tail")
## How far the Tape Tail reaches to a GrapplePoint, in pixels.
@export var grapple_range := 600.0
@export var tape_shoot_speed := 2600.0
@export var zip_speed := 1500.0
## Side view: the hop Patch gets when he lets go of a ring.
@export var zip_release_hop := -620.0

@export_group("Pop-Up Slam")
## Side view: the little hop before Patch slams down, and how fast he falls.
@export var slam_hop := -380.0
@export var slam_fall_speed := 1700.0
## The shockwave: radius, damage, and how long Patch is stuck after landing.
@export var slam_radius := 170.0
@export var slam_damage := 2
@export var slam_recover_time := 0.22

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
var _attack_active_left := 0.0
## Which hit of the combo the current or last swipe was (1-3), and how long the next
## swipe still counts as part of it.
var combo_step := 0
var _combo_left := 0.0
var _attack_scale := Vector2.ONE
## How long the current light swing lasts (the shears' form changes it).
var _swing_time := 0.18
## Style meter (StyleMeter): rewards varied, clean fighting with extra Thread.
var style: StyleMeter
## Seconds left of standing on soaked paper (SoakedPaper keeps it topped up).
var soft_ground_left := 0.0
## A shove for this physics frame only (a Current sets it); cleared after each move.
var push := Vector2.ZERO
var _attack_knockback := 520.0
var _attack_kind := Attack.LIGHT
var _attack_buffer := 0.0
## Air combo hits since leaving the ground, and air dodges left before landing.
var _air_hits := 0
var _air_dodges_left := 1
var _heavy_phase := 0
var _heavy_held := 0.0
var charge_level := 0
var _guard_time := 0.0
var _guard_press_age := 99.0
var _block_cooldown := 0.0
var _blocking := false
var _perfect_done := false
var _finisher_target: Node2D
## Counters the tests (and the HUD later) can read.
var parries := 0
var perfect_dodges := 0
var _hurt_flash_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector2.RIGHT
var _was_on_floor := false
var _last_safe_position := Vector2.ZERO
## Which way Patch faced on that ground, so a fall puts him back away from the edge.
var _last_safe_facing := 1.0
## True while a conversation is open: Patch can't act, so nothing may hurt him.
var _in_dialogue := false
var _anim_time := 0.0
var _grapple_target: GrapplePoint
var _grapple_phase := Grapple.SHOOT
var _grapple_time := 0.0
var _grapple_reach := 0.0
var _grapple_start := Vector2.ZERO
var _saved_mask := 1
var _highlighted: GrapplePoint
var _tape_line: Line2D
## After letting go of a ring, Patch keeps his swing for a moment even with no input.
var _carry_left := 0.0
## Pop-Up Slam phases: rising into the hop, plunging, then landed (recovering).
var _slam_phase := 0

@onready var visual: Node2D = $Visual
@onready var rig: DarkRig = $Visual/Rig
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_hitbox: Hitbox = $AttackHitbox
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	if GameState.get_flag("has_new_tail"):
		rig.set_mended(true)
	health.max_health = GameState.max_health
	health.set_health(GameState.health)
	health.changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hit.connect(_on_hurtbox_hit)
	attack_hitbox.active = false
	_attack_scale = attack_hitbox.scale
	_attack_knockback = attack_hitbox.knockback
	attack_hitbox.landed.connect(_on_attack_landed)
	if not ShearForms.is_unlocked(GameState.shear_form):
		GameState.shear_form = ShearForms.Form.BILL
	style = StyleMeter.new()
	style.name = &"StyleMeter"
	add_child(style)
	EventBus.thread_changed.emit(GameState.thread, GameState.thread_max)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.player_health_changed.emit(health.current, health.max_health)
	_last_safe_position = global_position
	_tape_line = Line2D.new()
	_tape_line.top_level = true
	_tape_line.width = 13.0
	_tape_line.default_color = Color("f2dc96")
	_tape_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_tape_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_tape_line.z_index = 4
	_tape_line.visible = false
	add_child(_tape_line)


func set_view_mode(mode: PageView.Mode) -> void:
	view_mode = mode
	motion_mode = MOTION_MODE_FLOATING if mode == PageView.Mode.TOP else MOTION_MODE_GROUNDED
	if mode == PageView.Mode.TOP:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if state != State.ATTACK:
		_combo_left = maxf(_combo_left - delta, 0.0)
		if _combo_left <= 0.0:
			combo_step = 0
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	soft_ground_left = maxf(soft_ground_left - delta, 0.0)
	_block_cooldown = maxf(_block_cooldown - delta, 0.0)
	if input_enabled and Input.is_action_just_pressed(&"guard"):
		_guard_press_age = 0.0
		if state == State.GUARD:
			_guard_time = 0.0
	else:
		_guard_press_age += delta
	_state_left = maxf(_state_left - delta, 0.0)
	if view_mode == PageView.Mode.TOP or is_on_floor():
		_air_hits = 0
		_air_dodges_left = 1
	if view_mode == PageView.Mode.SIDE:
		# Coyote time and the jump buffer run in every state, so a jump pressed during
		# a swing, a dodge or a stagger still comes out the moment Patch is free.
		# (A dodge off a ledge keeps its coyote time, so dash-then-jump still works.)
		if is_on_floor():
			_coyote_left = coyote_time
		elif state != State.DASH:
			_coyote_left = maxf(_coyote_left - delta, 0.0)
		if _action_pressed(&"jump"):
			_jump_buffer_left = jump_buffer_time
		else:
			_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	match state:
		State.NORMAL:
			_process_normal(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DASH:
			_process_dash()
		State.HURT:
			_process_hurt(delta)
		State.GRAPPLE:
			_process_grapple(delta)
		State.SLAM:
			_process_slam(delta)
		State.HEAVY:
			_process_heavy(delta)
		State.GUARD:
			_process_guard(delta)
		State.MEND:
			_process_mend(delta)
		State.FINISHER:
			_process_finisher(delta)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, ground_friction * delta)

	# Currents (and anything else that shoves Patch along) add to this frame's move
	# only, so they never build up in his own velocity.
	velocity += push
	move_and_slide()
	velocity -= push
	push = Vector2.ZERO
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

	var armed := GameState.has_ability(&"crease_swipe")
	if _action_pressed(&"interact") and _try_interact():
		pass
	elif _wants_slam() and (armed or GameState.has_ability(&"pop_up_slam")):
		_start_slam()
	elif _action_pressed(&"heavy") and armed:
		_start_heavy()
	elif _action_pressed(&"attack") and _attack_cooldown_left <= 0.0 and armed:
		_start_attack()
	elif _action_pressed(&"dash") and _can_dodge():
		_start_dash(input)
	elif input_enabled and Input.is_action_pressed(&"guard") and armed and view_mode == PageView.Mode.SIDE and is_on_floor():
		# Held from the air, guard goes up on landing; the parry window counts from the press.
		_start_guard()
	elif _action_pressed(&"mend") and _can_mend():
		_start_mend()
	elif _action_pressed(&"grapple") and GameState.has_ability(&"tape_tail"):
		try_grapple()
	elif _action_pressed(&"switch_form") and armed:
		switch_form()
	_update_grapple_highlight()


func _side_movement(input_x: float, delta: float) -> void:
	if input_x != 0.0:
		facing = Vector2(signf(input_x), 0)
	var target := input_x * run_speed
	var rate := ground_acceleration if is_on_floor() else air_acceleration
	if input_x == 0.0 and is_on_floor():
		rate = ground_friction
	_carry_left = 0.0 if is_on_floor() else maxf(_carry_left - delta, 0.0)
	if _carry_left > 0.0 and (input_x == 0.0 or signf(input_x) == signf(velocity.x)):
		# Keep the swing's speed instead of capping it to running speed.
		rate = air_acceleration * 0.12
	velocity.x = move_toward(velocity.x, target, rate * delta)
	_apply_gravity(delta)

	# Coyote time (a grace period to jump after walking off a ledge) and the jump
	# buffer (a jump pressed just before landing still counts) tick in _physics_process.
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		# Soaked paper gives under him: a jump off it is barely a hop.
		velocity.y = jump_velocity * (SOFT_JUMP if soft_ground_left > 0.0 else 1.0)
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
	_attack_buffer = 0.0
	var form := _form()
	_swing_time = attack_time * float(form["speed"])
	_state_left = _swing_time
	_attack_active_left = attack_active_time
	var airborne := view_mode == PageView.Mode.SIDE and not is_on_floor()
	var length := _air_combo_length() if airborne else _combo_length()
	combo_step = combo_step + 1 if combo_step < length and _combo_left > 0.0 else 1
	var last := combo_step == length
	# Back off a little after the last hit, so the combo has a rhythm.
	_attack_cooldown_left = attack_cooldown * float(form["speed"]) if last else 0.0
	# Side view: hold up to cut overhead (things hanging above, flyers).
	var aim := facing
	if view_mode == PageView.Mode.SIDE and input_enabled and Input.is_action_pressed(&"move_up"):
		aim = Vector2.UP
	if airborne:
		_attack_kind = Attack.AIR
		_air_hits += 1
		# The shears keep Patch hanging in the air for a moment while he cuts.
		velocity.y = minf(velocity.y, 60.0) if _air_hits <= _air_combo_length() else velocity.y
	elif aim == Vector2.UP:
		_attack_kind = Attack.OVERHEAD
	else:
		_attack_kind = Attack.THRUST if last else Attack.LIGHT
	var heavy_hit := last and not airborne
	var light_damage := int(form["light_damage"])
	_configure_hitbox(aim, attack_reach, 1.3 if heavy_hit else 1.0,
		finisher_damage + light_damage - 1 if heavy_hit else light_damage,
		1.0 if heavy_hit else float(form["light_hold"]) / float(form["hold_scale"]),
		finisher_knockback if heavy_hit else 1.0, false, Vector2.ONE,
		Hitbox.Reaction.SEND if heavy_hit else Hitbox.Reaction.FLINCH)
	AudioManager.play_sfx(&"shears", (0.85 if heavy_hit else randf_range(0.95, 1.12)), -4.0)
	if heavy_hit:
		AudioManager.play_voice(&"effort")
	elif randf() < 0.35:
		AudioManager.play_voice(&"light")
	_squash(Vector2(1.3, 0.8) if heavy_hit else Vector2(1.15, 0.9))
	_spawn_form_slash(aim, 1.3 if heavy_hit else 1.0)
	if heavy_hit and view_mode == PageView.Mode.SIDE:
		# The thrust lunges forward.
		velocity.x += facing.x * 300.0


## Points the shears' hitbox for one cut.
func _configure_hitbox(aim: Vector2, reach: float, size: float, damage: int, hold: float,
		knockback_scale: float, launch := false, stretch := Vector2.ONE,
		reaction := Hitbox.Reaction.REEL) -> void:
	var form := _form()
	reach *= float(form["reach"])
	var offset := aim * reach * maxf(stretch.x, 1.0) ** 0.5
	if view_mode == PageView.Mode.SIDE and aim.y == 0.0:
		offset.y -= 6.0
	attack_hitbox.position = offset
	attack_hitbox.rotation = aim.angle()
	attack_hitbox.scale = _attack_scale * size * stretch
	attack_hitbox.damage = damage
	attack_hitbox.hold_damage = hold * float(form["hold_scale"])
	attack_hitbox.form = GameState.shear_form
	attack_hitbox.pierces_guard = bool(form["pierce"])
	attack_hitbox.knockback = _attack_knockback * knockback_scale
	attack_hitbox.launch = launch
	attack_hitbox.reaction = Hitbox.Reaction.LAUNCH if launch else reaction
	attack_hitbox.active = true


func _process_attack(delta: float) -> void:
	# Patch can still drift and fall mid-swipe, just more slowly.
	if view_mode == PageView.Mode.SIDE:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.5 * delta)
		_apply_gravity(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, top_acceleration * delta)
	_attack_active_left -= delta
	if _attack_active_left <= 0.0:
		attack_hitbox.active = false
		# Once the cut has landed or missed, a dodge cancels the rest of the swing.
		if _action_pressed(&"dash") and _can_dodge():
			_start_dash(_move_input())
			return
		# So does a jump on the ground (it comes out next frame from the jump buffer).
		if view_mode == PageView.Mode.SIDE and is_on_floor() and _jump_buffer_left > 0.0 \
				and _state_left < _swing_time * 0.5:
			attack_hitbox.active = false
			_combo_left = 0.0
			combo_step = 0
			state = State.NORMAL
			return
	var airborne := view_mode == PageView.Mode.SIDE and not is_on_floor()
	var length := _air_combo_length() if airborne else _combo_length()
	# A form switch mid-swing comes out as a quick transition cut.
	if _action_pressed(&"switch_form") and _state_left < _swing_time * 0.6:
		switch_form()
		return
	# Pressing attack chains into the next hit. An early press is remembered and
	# comes out as soon as the swing reaches its back half.
	if _action_pressed(&"attack"):
		_attack_buffer = 0.2
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	if combo_step < length and _state_left < _swing_time * 0.5 and _attack_buffer > 0.0:
		_attack_buffer = 0.0
		_combo_left = combo_window
		_start_attack()
		return
	if _state_left < _swing_time * 0.5 and _action_pressed(&"heavy"):
		_start_heavy()
		return
	if _state_left <= 0.0:
		attack_hitbox.active = false
		_combo_left = combo_window if combo_step < length else 0.0
		state = State.NORMAL


# --- Heavy, charge and launcher ----------------------------------------------

func _start_heavy() -> void:
	attack_hitbox.active = false
	var target := _find_staggered()
	if target:
		_start_finisher(target)
		return
	var side := view_mode == PageView.Mode.SIDE
	if side and not is_on_floor() and input_enabled and Input.is_action_pressed(&"move_down"):
		_start_slam()
		return
	state = State.HEAVY
	_heavy_held = 0.0
	charge_level = 0
	combo_step = 0
	if side and is_on_floor() and input_enabled and Input.is_action_pressed(&"move_up"):
		# The launcher comes out at once: a rising cut that pops enemies up.
		_release_heavy(Attack.LAUNCHER)
	elif side and not is_on_floor():
		_release_heavy(Attack.HEAVY)
	else:
		_heavy_phase = 0


func _process_heavy(delta: float) -> void:
	if view_mode == PageView.Mode.SIDE:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		_apply_gravity(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, top_acceleration * delta)
	match _heavy_phase:
		0:
			# Charging: held heavy builds up to three levels.
			# Gran's Quick Unpick pattern: charge a third faster.
			_heavy_held += delta * (1.5 if GameState.has_pattern(&"quick_unpick") else 1.0)
			var level := 0
			for threshold in charge_levels:
				if _heavy_held >= threshold:
					level += 1
			if level > charge_level:
				charge_level = level
				AudioManager.play_sfx(&"grapple", 0.8 + level * 0.15)
				_squash(Vector2(0.9, 1.1))
			var held := input_enabled and Input.is_action_pressed(&"heavy")
			if not held:
				_release_heavy(Attack.CHARGED if charge_level > 0 else Attack.HEAVY)
		1:
			# Wind-up: the blade comes down after a beat.
			if _state_left <= 0.0:
				_heavy_strike()
		2:
			_attack_active_left -= delta
			if _attack_active_left <= 0.0:
				attack_hitbox.active = false
				_heavy_phase = 3
				_state_left = heavy_recover
		3:
			if _action_pressed(&"dash") and _can_dodge():
				_start_dash(_move_input())
			elif _action_pressed(&"heavy") and _find_staggered():
				_start_finisher(_find_staggered())
			elif _state_left <= 0.0:
				state = State.NORMAL


func _release_heavy(kind: Attack) -> void:
	_attack_kind = kind
	_heavy_phase = 1
	_state_left = heavy_windup if kind != Attack.LAUNCHER else 0.04
	_squash(Vector2(0.85, 1.15))


func _heavy_strike() -> void:
	_heavy_phase = 2
	_attack_active_left = attack_active_time
	match _attack_kind:
		Attack.LAUNCHER:
			_configure_hitbox(Vector2(facing.x, -0.6).normalized(), attack_reach, 1.2, _heavy_damage(heavy_damage), heavy_hold, 1.0, true)
			_spawn_slash(Vector2(facing.x, -1.0).normalized(), 1.3, Color("fff6dc"))
			AudioManager.play_sfx(&"shears", 0.9)
			AudioManager.play_voice(&"effort", true)
		Attack.CHARGED:
			var i := clampi(charge_level - 1, 0, 2)
			if charge_level >= 3:
				# The Full Cut: a slash that crosses most of the screen.
				_configure_hitbox(facing, attack_reach, 1.0, _heavy_damage(charge_damage[i]), charge_hold[i], 2.2, false, Vector2(7.0, 1.4), Hitbox.Reaction.SEND)
				_spawn_slash(facing, 4.5, Color("ffd36e"))
				_shake_camera(10.0)
				for node in get_tree().get_nodes_in_group(&"full_cut_listeners"):
					if node.has_method("on_full_cut"):
						node.on_full_cut(global_position, facing)
			else:
				_configure_hitbox(facing, attack_reach, 1.3 + 0.35 * i, _heavy_damage(charge_damage[i]), charge_hold[i], 1.6 + 0.3 * i, false, Vector2.ONE, Hitbox.Reaction.SEND)
				_spawn_slash(facing, 1.6 + 0.4 * i, Color("ffe7a8"))
			AudioManager.play_sfx(&"shears", 0.7)
			AudioManager.play_voice(&"heavy" if charge_level >= 2 else &"effort", true)
			if view_mode == PageView.Mode.SIDE:
				velocity.x += facing.x * 240.0
		_:
			_configure_hitbox(facing, attack_reach, 1.35, _heavy_damage(heavy_damage), heavy_hold, 1.4)
			_spawn_slash(facing, 1.5, Color("fff0c8"))
			AudioManager.play_sfx(&"shears", 0.8)
			AudioManager.play_voice(&"effort", true)
	_squash(Vector2(1.35, 0.78))


func _on_attack_landed(target: Node) -> void:
	var stop := 0.05
	var gain := 0.12
	match _attack_kind:
		Attack.THRUST, Attack.HEAVY, Attack.LAUNCHER:
			stop = 0.08
			gain = 0.2
		Attack.CHARGED:
			stop = 0.1 + 0.02 * charge_level
			gain = 0.25
		Attack.PLUNGE:
			stop = 0.07
			gain = 0.2
	style.add(STYLE_MOVES.get(_attack_kind, &"light"))
	GameState.add_thread(gain * style.thread_bonus())
	TimeFX.hitstop(stop)
	AudioManager.play_sfx(&"hit_wet", randf_range(0.9, 1.1), -2.0)
	_spawn_hit_spark(target)
	if state == State.SLAM and _slam_phase == 1:
		# The Plunge bounces Patch back up off whatever it hits.
		attack_hitbox.active = false
		state = State.NORMAL
		velocity = Vector2(velocity.x, -840.0)
		_air_dodges_left = 1
		_squash(Vector2(0.8, 1.25))


# --- Unstitch finisher ---------------------------------------------------------

func _finisher_range() -> float:
	return finisher_range * (1.6 if GameState.has_pattern(&"long_seam") else 1.0)


## Where an Unstitch aims: a boss is cut at its weak point, anything else at its middle.
func _finisher_point(target: Node2D) -> Vector2:
	if target.has_method(&"finisher_point"):
		return target.finisher_point()
	return target.global_position


func _air_combo_length() -> int:
	var by_form := int(_form()["air_combo"]) - 3
	return air_combo_length + by_form + (1 if GameState.has_pattern(&"blanket_stitch") else 0)


func _combo_length() -> int:
	return combo_length + int(_form()["combo"]) - 4


# --- Gran's shears: three forms (see ShearForms) --------------------------------

func _form() -> Dictionary:
	return ShearForms.stats(GameState.shear_form)


func _heavy_damage(base: int) -> int:
	return maxi(base + int(_form()["heavy_bonus"]), 1)


## Cycles to the next unlocked form. Mid-swing it comes out as a quick transition cut,
## so a switch keeps a combo going instead of costing it.
func switch_form() -> bool:
	var next := ShearForms.next(GameState.shear_form)
	if next == GameState.shear_form:
		return false
	var mid_swing := state == State.ATTACK
	GameState.shear_form = next
	EventBus.shear_form_changed.emit(next)
	AudioManager.play_sfx(&"shears", 1.35 if next == ShearForms.Form.WINGS else (0.7 if next == ShearForms.Form.BEAK else 1.0), -6.0)
	_squash(Vector2(0.9, 1.1))
	if mid_swing:
		# The transition cut: one quick hit in the new form that keeps the chain alive.
		_swing_time = attack_time * float(_form()["speed"])
		_state_left = _swing_time
		_attack_active_left = attack_active_time
		_combo_left = combo_window
		combo_step = mini(combo_step, _combo_length() - 1)
		_configure_hitbox(facing, attack_reach, 1.1, 1, 0.75, 1.0, false, Vector2.ONE, Hitbox.Reaction.FLINCH)
		_spawn_form_slash(facing, 1.15)
		style.add(&"switch")
	return true


## The slash a cut leaves, by form: one arc (Bill), two crossing arcs (Wings), or a
## wide pair of jaws snapping shut (Beak).
func _spawn_form_slash(aim: Vector2, size: float) -> void:
	var colour: Color = _form()["colour"]
	match GameState.shear_form:
		ShearForms.Form.WINGS:
			_spawn_slash(aim.rotated(0.35), size * 0.8, colour)
			_spawn_slash(aim.rotated(-0.35), size * 0.8, colour)
		ShearForms.Form.BEAK:
			_spawn_slash(aim.rotated(0.6), size * 1.25, colour)
			_spawn_slash(aim.rotated(-0.6), size * 1.25, colour)
		_:
			_spawn_slash(aim, size, colour)


func _parry_window() -> float:
	var window := parry_window * (2.0 if Settings.assist_wide_parry else 1.0)
	return window * (1.5 if GameState.has_pattern(&"backstitch") else 1.0)


## The nearest enemy in front of Patch whose Hold has broken.
func _find_staggered() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"staggered"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy := _finisher_point(enemy) - global_position
		if absf(to_enemy.x) > _finisher_range() or absf(to_enemy.y) > 130.0:
			continue
		if view_mode == PageView.Mode.SIDE and to_enemy.x * facing.x < -30.0:
			continue
		if to_enemy.length() < best_distance:
			best_distance = to_enemy.length()
			best = enemy
	return best


func _start_finisher(target: Node2D) -> void:
	state = State.FINISHER
	_finisher_target = target
	_state_left = 0.42
	_heavy_phase = 0
	velocity = Vector2.ZERO
	health.grant_invulnerability(0.7)
	var point := _finisher_point(target)
	var side := signf(global_position.x - point.x)
	if side == 0.0:
		side = -facing.x
	facing = Vector2(-side, 0)
	global_position.x = point.x + side * 64.0
	AudioManager.play_sfx(&"shears", 0.65)
	AudioManager.play_voice(&"finisher", true)
	TimeFX.hitstop(0.12)
	_squash(Vector2(0.75, 1.3))


func _process_finisher(delta: float) -> void:
	velocity = Vector2.ZERO
	if view_mode == PageView.Mode.SIDE and not is_on_floor():
		velocity.y = 0.0
	if _heavy_phase == 0 and _state_left < 0.28:
		_heavy_phase = 1
		var target := _finisher_target
		if is_instance_valid(target):
			_spawn_slash(Vector2.UP, 2.0, Color("ff5a4a"))
			_spawn_slash(facing, 2.0, Color("fff6dc"))
			if target.has_method("unstitch"):
				target.unstitch(self)
			else:
				var hp := target.get("health") as HealthComponent
				if hp:
					hp.take_damage(999, global_position)
			var hold := target.get_node_or_null(^"HoldComponent") as HoldComponent
			if hold:
				hold.clear()
			_spawn_hit_spark(target)
		GameState.add_thread(1.0)
		style.add(&"unstitch")
		# Gran's Long Seam pattern: every Unstitch mends half a paper token.
		if GameState.has_pattern(&"long_seam"):
			health.heal(1)
		AudioManager.play_sfx(&"enemy_pop", 0.7)
		TimeFX.hitstop(0.14)
		_shake_camera(16.0)
		_squash(Vector2(1.45, 0.7))
	if _state_left <= 0.0:
		_finisher_target = null
		state = State.NORMAL


# --- Guard and parry -----------------------------------------------------------

func _start_guard() -> void:
	state = State.GUARD
	_guard_time = _guard_press_age
	attack_hitbox.active = false
	combo_step = 0
	_squash(Vector2(0.92, 1.05))


func _process_guard(delta: float) -> void:
	_guard_time += delta
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	_apply_gravity(delta)
	if not (input_enabled and Input.is_action_pressed(&"guard")) or not is_on_floor():
		state = State.NORMAL
	elif _action_pressed(&"dash") and _can_dodge():
		_start_dash(_move_input())


## Guard catches a hit from the front. Returns true if the hit was handled.
func _guard_hit(hitbox: Hitbox) -> bool:
	if hitbox.unblockable:
		return false
	var dx := hitbox.global_position.x - global_position.x
	if absf(dx) > 12.0 and signf(dx) != signf(facing.x):
		return false
	if _guard_time <= _parry_window():
		_parry(hitbox)
		return true
	if _block_cooldown > 0.0:
		return true
	_block_cooldown = 0.3
	velocity.x = -facing.x * guard_push
	AudioManager.play_sfx(&"slam", 1.5)
	_squash(Vector2(0.85, 1.1))
	# Gran's Thimble charm: guarding takes no chip damage.
	var chip := 0 if GameState.has_charm(&"thimble") else hitbox.damage - 1
	if chip > 0:
		_blocking = true
		health.take_damage(chip, hitbox.global_position)
		_blocking = false
	health.grant_invulnerability(0.3)
	return true


## Accessibility (Settings.auto_guard): standing or walking, Patch raises his guard by
## himself against a blockable hit at his front. It's always a block, never a parry,
## so timing the guard yourself still pays.
func _auto_guard(hitbox: Hitbox) -> bool:
	if not Settings.auto_guard or state != State.NORMAL or not is_on_floor() or not GameState.has_ability(&"crease_swipe"):
		return false
	if view_mode != PageView.Mode.SIDE:
		return false
	_guard_time = 99.0
	return _guard_hit(hitbox)


## A parry: Patch snaps the attack aside. The attacker loses a lot of Hold and is
## pushed back; Patch can't be hurt for a moment and is free to counter.
func _parry(hitbox: Hitbox) -> void:
	parries += 1
	EventBus.player_parried.emit()
	health.grant_invulnerability(0.4)
	state = State.NORMAL
	_guard_time = 99.0
	var attacker := hitbox.owner
	if attacker:
		var hold := attacker.get_node_or_null(^"HoldComponent") as HoldComponent
		if hold:
			# Gran's Backstitch pattern: a parry tears more Hold.
			hold.take_hold(parry_hold + (2.0 if GameState.has_pattern(&"backstitch") else 0.0))
		if attacker.has_method("on_parried"):
			attacker.on_parried(self)
	GameState.add_thread(0.34)
	TimeFX.hitstop(0.13)
	AudioManager.play_sfx(&"parry", randf_range(0.95, 1.05))
	if randf() < 0.5:
		AudioManager.play_voice(&"parry", true)
	_spawn_slash(facing, 1.2, Color("bfe8ff"))
	_spawn_parry_flash()
	_shake_camera(8.0)


# --- Mend ------------------------------------------------------------------------

func _can_mend() -> bool:
	if GameState.thread < 1.0 or health.current >= health.max_health:
		return false
	return view_mode == PageView.Mode.TOP or is_on_floor()


func _start_mend() -> void:
	state = State.MEND
	_state_left = mend_time
	attack_hitbox.active = false
	combo_step = 0
	AudioManager.play_voice(&"mend", true, -3.0)


func _process_mend(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, ground_friction * delta)
	if view_mode == PageView.Mode.SIDE:
		_apply_gravity(delta)
	if not (input_enabled and Input.is_action_pressed(&"mend")):
		state = State.NORMAL
		return
	if _state_left <= 0.0:
		GameState.add_thread(-1.0)
		# Waxed Thread charm: one more paper token (2 health).
		health.heal(mend_heal + (2 if GameState.has_charm(&"wax_thread") else 0))
		AudioManager.play_sfx(&"grapple", 1.3)
		_squash(Vector2(1.2, 0.85))
		_spawn_parry_flash(Color("9fe39a"))
		state = State.NORMAL


# --- Edge-On dodge ---------------------------------------------------------------

func _can_dodge() -> bool:
	if _dash_cooldown_left > 0.0 or not GameState.has_ability(&"fold_dash"):
		return false
	if view_mode == PageView.Mode.SIDE and not is_on_floor():
		return _air_dodges_left > 0
	return true


func _start_dash(input: Vector2) -> void:
	state = State.DASH
	attack_hitbox.active = false
	combo_step = 0
	_state_left = dash_time
	_dash_cooldown_left = dash_cooldown
	_perfect_done = false
	if randf() < 0.4:
		AudioManager.play_voice(&"dodge")
	if view_mode == PageView.Mode.SIDE and not is_on_floor():
		_air_dodges_left -= 1
	if view_mode == PageView.Mode.SIDE:
		_dash_direction = Vector2(signf(input.x) if input.x != 0.0 else facing.x, 0)
	else:
		_dash_direction = input.normalized() if input != Vector2.ZERO else facing
	AudioManager.play_sfx(&"swipe", 0.7)
	_squash(Vector2(1.35, 0.7))


func _process_dash() -> void:
	# Edge-On: Patch turns sideways into a thin line of paper. Attacks pass
	# through him, and there's no gravity while it lasts.
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


# --- Pop-Up Slam -----------------------------------------------------------

## The slam button, or (side view, in mid-air) attack while holding down. On a flat
## page there's nothing to guard against from the front, so guard slams too (this
## gives controllers a second slam button where the ice and fold marks need it).
func _wants_slam() -> bool:
	if _action_pressed(&"slam"):
		return true
	if view_mode == PageView.Mode.TOP and _action_pressed(&"guard"):
		return true
	return view_mode == PageView.Mode.SIDE and not is_on_floor() and _action_pressed(&"attack") \
		and input_enabled and Input.is_action_pressed(&"move_down")


func _start_slam() -> void:
	state = State.SLAM
	_slam_phase = 0
	attack_hitbox.active = false
	if view_mode == PageView.Mode.SIDE:
		velocity = Vector2(velocity.x * 0.3, slam_hop if is_on_floor() else minf(velocity.y, 0.0) * 0.2 - 120.0)
		_state_left = 0.14
	else:
		# On a flat page Patch hops on the spot and stamps down.
		velocity = Vector2.ZERO
		_state_left = 0.16
	_squash(Vector2(0.75, 1.25))


func _process_slam(delta: float) -> void:
	match _slam_phase:
		0:
			if view_mode == PageView.Mode.SIDE:
				velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
				velocity.y = minf(velocity.y + gravity * delta, 0.0)
			if _state_left <= 0.0:
				if view_mode == PageView.Mode.SIDE:
					_slam_phase = 1
					velocity = Vector2(0, slam_fall_speed)
					# The Plunge: blade-first, it hurts and bounces off anything below.
					_attack_kind = Attack.PLUNGE
					_configure_hitbox(Vector2.DOWN, 50.0, 1.0, 2, 3.0, 1.2, false, Vector2.ONE, Hitbox.Reaction.CRUSH)
				else:
					_slam_impact()
		1:
			velocity = Vector2(0, slam_fall_speed)
			if is_on_floor():
				_slam_impact()
		2:
			if view_mode == PageView.Mode.SIDE:
				_apply_gravity(delta)
			velocity.x = 0.0
			if _state_left <= 0.0:
				state = State.NORMAL


## Patch lands: a shockwave hurts anything nearby, and every fold mark in reach
## springs its pop-up (see FoldMark). Slam-breakable things (ice) shatter.
func _slam_impact() -> void:
	attack_hitbox.active = false
	_slam_phase = 2
	_state_left = slam_recover_time
	velocity = Vector2.ZERO
	_squash(Vector2(1.45, 0.62))
	AudioManager.play_sfx(&"slam", randf_range(0.95, 1.05))
	var wave := Hitbox.new()
	wave.collision_layer = attack_hitbox.collision_layer
	wave.collision_mask = 0
	wave.monitoring = false
	wave.damage = slam_damage
	wave.knockback = 700.0
	wave.reaction = Hitbox.Reaction.CRUSH
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = slam_radius
	shape.shape = circle
	wave.add_child(shape)
	wave.position = Vector2(0, -10)
	add_child(wave)
	get_tree().create_timer(0.12, false, true).timeout.connect(wave.queue_free)
	# Springing fold marks and shattering ice is the Pop-Up Slam ability (Chapter 3).
	if GameState.has_ability(&"pop_up_slam"):
		for node in get_tree().get_nodes_in_group(&"slam_listeners"):
			if node.has_method("on_slam"):
				node.on_slam(global_position, view_mode)
	_shake_camera(14.0)
	_spawn_slam_ring()


func _shake_camera(amount: float) -> void:
	if not Settings.screen_shake:
		return
	var tween := create_tween()
	for i in 4:
		tween.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * (1.0 - i / 4.0), 0.035)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)


func _spawn_slam_ring() -> void:
	# A puff of paper scraps: a flattened ring that spreads and fades.
	var ring := Line2D.new()
	ring.top_level = true
	ring.width = 8.0
	ring.default_color = Color("f7eed6")
	var points := PackedVector2Array()
	var squash := 0.3 if view_mode == PageView.Mode.SIDE else 1.0
	for i in 25:
		var a := i / 24.0 * TAU
		points.append(Vector2(cos(a), sin(a) * squash) * 30.0)
	ring.points = points
	ring.global_position = global_position + (Vector2(0, 40) if view_mode == PageView.Mode.SIDE else Vector2.ZERO)
	ring.z_index = 4
	add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector2(slam_radius / 30.0, slam_radius / 30.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)


# --- Tape Tail -------------------------------------------------------------

## Fires the Tape Tail at the best GrapplePoint in reach. Returns false if none.
func try_grapple() -> bool:
	var target := _best_grapple_target()
	if target == null:
		return false
	_grapple_target = target
	_grapple_phase = Grapple.SHOOT
	_grapple_time = 0.0
	_grapple_reach = 0.0
	_grapple_start = global_position
	state = State.GRAPPLE
	velocity = Vector2.ZERO
	_tape_line.visible = true
	AudioManager.play_sfx(&"grapple", randf_range(0.95, 1.05))
	var dx := target.global_position.x - global_position.x
	if view_mode == PageView.Mode.SIDE and dx != 0.0:
		facing = Vector2(signf(dx), 0)
	return true


func _best_grapple_target() -> GrapplePoint:
	var best: GrapplePoint = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"grapple_points"):
		var point := node as GrapplePoint
		if point == null or not point.can_grapple():
			continue
		var to_point := point.global_position - global_position
		var distance := to_point.length()
		if distance > grapple_range or distance < 90.0:
			continue
		# Prefer rings ahead of Patch, then the nearest.
		var score := distance - to_point.normalized().dot(facing) * 220.0
		if view_mode == PageView.Mode.SIDE and not _clear_line_to(point.global_position):
			continue
		if score < best_score:
			best_score = score
			best = point
	return best


func _clear_line_to(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target, 1, [get_rid()])
	query.hit_from_inside = false
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _update_grapple_highlight() -> void:
	var best: GrapplePoint = _best_grapple_target() if GameState.has_ability(&"tape_tail") else null
	if best == _highlighted:
		return
	if _highlighted and is_instance_valid(_highlighted):
		_highlighted.highlighted = false
	_highlighted = best
	if best:
		best.highlighted = true


func _process_grapple(delta: float) -> void:
	if _grapple_target == null or not is_instance_valid(_grapple_target):
		_end_grapple()
		return
	_grapple_time += delta
	var anchor := _grapple_target.global_position
	match _grapple_phase:
		Grapple.SHOOT:
			velocity = Vector2.ZERO
			_grapple_reach += tape_shoot_speed * delta
			var to_anchor := anchor - global_position
			_draw_tape(global_position + to_anchor.limit_length(_grapple_reach))
			if _grapple_reach >= to_anchor.length():
				_squash(Vector2(0.85, 1.15))
				if _grapple_target.mode == GrapplePoint.Mode.ZIP:
					_grapple_phase = Grapple.ZIP
					_grapple_time = 0.0
					# Fly over water and gaps: ignore the world until he arrives.
					_saved_mask = collision_mask
					collision_mask = 0
				else:
					_grapple_target.yank()
					_grapple_phase = Grapple.RETRACT
					_grapple_time = 0.0
		Grapple.ZIP:
			var to_anchor := anchor + _grapple_target.land_offset - global_position
			_draw_tape(anchor)
			if to_anchor.length() < zip_speed * delta * 1.5 or _grapple_time > 1.5:
				global_position = anchor + _grapple_target.land_offset
				if view_mode == PageView.Mode.SIDE:
					var swing := (anchor - _grapple_start).normalized()
					velocity = Vector2(swing.x * zip_speed * 0.45, zip_release_hop)
					_carry_left = 0.7
				else:
					velocity = Vector2.ZERO
				_end_grapple()
				return
			velocity = to_anchor.normalized() * zip_speed
		Grapple.RETRACT:
			velocity = Vector2.ZERO
			var t := clampf(1.0 - _grapple_time / 0.15, 0.0, 1.0)
			_draw_tape(global_position.lerp(anchor, t))
			if t <= 0.0:
				_end_grapple()


func _draw_tape(tip: Vector2) -> void:
	_tape_line.points = PackedVector2Array([global_position + Vector2(-facing.x * 30.0, 0), tip])


func _end_grapple() -> void:
	if collision_mask == 0:
		collision_mask = _saved_mask
	_tape_line.visible = false
	_grapple_target = null
	if state == State.GRAPPLE:
		state = State.NORMAL


func _after_move() -> void:
	if view_mode == PageView.Mode.SIDE:
		var on_floor := is_on_floor()
		if on_floor and not _was_on_floor:
			_squash(Vector2(1.2, 0.82))
		if on_floor and state == State.NORMAL and _on_safe_floor():
			_last_safe_position = global_position
			_last_safe_facing = facing.x if facing.x != 0.0 else _last_safe_facing
		_was_on_floor = on_floor
		if global_position.y > fall_limit and state != State.DEAD:
			_fell_off_page()
	elif state == State.NORMAL:
		_last_safe_position = global_position


## True when Patch stands on ground that will still be there when he comes back:
## not a moving or collapsing platform, breakable ice, or a cuttable thread.
func _on_safe_floor() -> bool:
	if get_platform_velocity() != Vector2.ZERO:
		return false
	# A test-only nudge down finds what he's standing on (nothing actually moves).
	var below := move_and_collide(Vector2(0, 8), true)
	if below == null:
		return false
	var body := below.get_collider()
	if body is AnimatableBody2D or body is RigidBody2D or body is CharacterBody2D \
			or body is SlamBreakable:
		return false
	return not (body is Node and (body as Node).is_in_group(&"unsafe_floor"))


func _fell_off_page() -> void:
	# Step back the way Patch came onto that ground, away from the edge he fell from.
	global_position = _last_safe_position + Vector2(-_last_safe_facing * 48.0, -24.0)
	velocity = Vector2.ZERO
	# Assist: a fall just puts him back on the ledge.
	if not Settings.assist_safe_falls:
		health.take_damage(1, global_position)


# --- Damage, death, interaction --------------------------------------------

func _on_hurtbox_hit(hitbox: Hitbox) -> void:
	if _in_dialogue:
		# Patch can't move while someone is talking, so nothing gets a free hit.
		return
	if state == State.DASH:
		# A hit that arrives right at the start of a dodge is a perfect dodge.
		if not _perfect_done and dash_time - _state_left <= perfect_dodge_window * (1.5 if GameState.has_charm(&"heron_pin") else 1.0) and hitbox.damage > 0:
			_perfect_dodge()
		return
	if state == State.DEAD or state == State.FINISHER or (state == State.SLAM and _slam_phase == 1):
		return
	if state == State.GUARD and _guard_hit(hitbox):
		return
	if _auto_guard(hitbox):
		return
	# Assist mode: no single hit takes more than half a paper token.
	var amount := mini(hitbox.damage, 1) if Settings.assist else hitbox.damage
	if health.take_damage(amount, hitbox.global_position):
		var away := (global_position - hitbox.global_position).normalized()
		if view_mode == PageView.Mode.SIDE:
			away = Vector2(signf(away.x) if away.x != 0.0 else -facing.x, -0.6).normalized()
		velocity = away * hitbox.knockback


func _perfect_dodge() -> void:
	_perfect_done = true
	perfect_dodges += 1
	EventBus.player_perfect_dodge.emit()
	GameState.add_thread(0.5)
	TimeFX.slow_motion(0.35, 0.5)
	AudioManager.play_sfx(&"grapple", 1.5)
	_spawn_parry_flash(Color("fff1a8"))


func _on_damaged(_amount: int, _from: Vector2) -> void:
	if health.is_dead() or _blocking:
		return
	if state == State.GRAPPLE:
		_end_grapple()
	if state == State.SLAM and is_instance_valid(camera):
		camera.offset = Vector2.ZERO
	state = State.HURT
	_state_left = hurt_time
	_hurt_flash_left = health.invulnerability_time
	style.hurt()
	attack_hitbox.active = false
	AudioManager.play_sfx(&"hurt", 0.8, -6.0)
	AudioManager.play_voice(&"hurt" if randf() < 0.6 else &"hurt2", true)


func _on_health_changed(current: int, maximum: int) -> void:
	GameState.health = current
	EventBus.player_health_changed.emit(current, maximum)


func _on_died() -> void:
	TimeFX.reset()
	if state == State.GRAPPLE:
		_end_grapple()
	state = State.DEAD
	input_enabled = false
	attack_hitbox.active = false
	AudioManager.play_sfx(&"hurt", 0.7, -6.0)
	AudioManager.play_voice(&"death", true)
	EventBus.player_died.emit()
	var tween := create_tween()
	tween.tween_property(visual, "rotation", deg_to_rad(90.0) * facing.x, 0.4)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.8)
	await tween.finished
	SceneManager.respawn_at_checkpoint()


func _try_interact() -> bool:
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
		return true
	return false


func _on_dialogue_started() -> void:
	_in_dialogue = true
	input_enabled = false
	velocity.x = 0.0
	if view_mode == PageView.Mode.TOP:
		velocity = Vector2.ZERO


func _on_dialogue_finished() -> void:
	# A breath of safety, so an enemy standing in Patch doesn't hit him the instant
	# the box closes.
	_in_dialogue = false
	health.grant_invulnerability(0.5)
	# Wait a moment so the button that closed the dialogue doesn't also act in-game.
	await get_tree().create_timer(0.15).timeout
	# Another conversation may have opened meanwhile (one line chained into the next).
	if state != State.DEAD and not DialogueUI.is_active():
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
	# The rig's legs carry the stride now, so the whole-body bob stays small.
	var bob := absf(sin(_anim_time)) * (3.0 if moving and grounded else 0.0)
	visual.position.y = -bob
	rig.drive(self, delta)
	var tilt := 0.0
	if view_mode == PageView.Mode.SIDE:
		tilt = clampf(velocity.x / run_speed, -1.0, 1.0) * 0.04
		if not is_on_floor():
			tilt += clampf(velocity.y / max_fall_speed, -1.0, 1.0) * 0.12 * dir
	if state == State.DASH or state == State.SLAM:
		tilt = 0.0
	if state == State.GUARD:
		tilt = -0.1 * dir
	visual.rotation = lerpf(visual.rotation, tilt, 12.0 * delta)
	if state == State.DASH:
		# Edge-On: seen side-on, Patch is a thin line of paper.
		visual.scale.x = 0.14 * dir
	var tint := Color.WHITE
	match state:
		State.HEAVY:
			if _heavy_phase == 0 and charge_level > 0:
				var glow := [Color(1.15, 1.1, 0.9), Color(1.3, 1.2, 0.8), Color(1.5, 1.25, 0.6)][charge_level - 1] as Color
				var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
				tint = Color.WHITE.lerp(glow, pulse)
				visual.position.x = randf_range(-1.5, 1.5) * charge_level
		State.GUARD:
			tint = Color(0.85, 0.95, 1.15)
		State.MEND:
			tint = Color(0.9, 1.2, 0.9).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
	if state != State.HEAVY:
		visual.position.x = 0.0
	# Flash while invulnerable after a hit (not after a parry or finisher).
	var blink := Time.get_ticks_msec() % 160 < 80
	_hurt_flash_left = maxf(_hurt_flash_left - delta, 0.0)
	tint.a = 0.45 if _hurt_flash_left > 0.0 and blink else 1.0
	visual.modulate = tint


func _exit_tree() -> void:
	TimeFX.reset()


# --- Effects -------------------------------------------------------------------

## A cut line: a crescent of paper-white that sweeps and fades in front of Patch.
func _spawn_slash(aim: Vector2, size: float, color: Color) -> void:
	var arc := Line2D.new()
	arc.top_level = true
	arc.width = 10.0 * clampf(size, 1.0, 2.0)
	arc.default_color = color
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.1))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.1))
	arc.width_curve = curve
	var radius := 62.0 * size
	var points := PackedVector2Array()
	var stretch := Vector2(1.0, 1.0)
	if size > 3.0:
		stretch = Vector2(1.0, 0.18)
	for i in 13:
		var a := lerpf(-1.1, 1.1, i / 12.0)
		points.append((Vector2.from_angle(a) * radius * stretch).rotated(aim.angle()))
	arc.points = points
	arc.global_position = global_position + Vector2(0, -6) + aim * 12.0
	arc.z_index = 5
	arc.add_to_group(&"vfx")
	get_parent().add_child(arc)
	var tween := arc.create_tween().set_parallel()
	tween.tween_property(arc, "modulate:a", 0.0, 0.18)
	tween.tween_property(arc, "scale", Vector2(1.12, 1.12), 0.18)
	tween.chain().tween_callback(arc.queue_free)


## Paper confetti where a cut lands.
func _spawn_hit_spark(target: Node) -> void:
	var where := global_position + facing * attack_reach
	if target is Node2D and is_instance_valid(target):
		where = (target as Node2D).global_position + Vector2(0, -20)
	for i in 6:
		var bit := Polygon2D.new()
		bit.top_level = true
		bit.polygon = PackedVector2Array([Vector2(-5, -3), Vector2(6, -2), Vector2(2, 4)])
		bit.color = [Color("fff6dc"), Color("f2d38a"), Color("e8e0cc")][i % 3]
		bit.global_position = where
		bit.rotation = randf() * TAU
		bit.z_index = 6
		bit.add_to_group(&"vfx")
		get_parent().add_child(bit)
		var dir := Vector2.from_angle(randf_range(-PI, 0.0) if view_mode == PageView.Mode.SIDE else randf() * TAU)
		var tween := bit.create_tween().set_parallel()
		tween.tween_property(bit, "global_position", where + dir * randf_range(30, 70), 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "rotation", bit.rotation + randf_range(-4, 4), 0.25)
		tween.tween_property(bit, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(bit.queue_free)


## A ring of light: parry (blue-white), perfect dodge (gold) or Mend (green).
func _spawn_parry_flash(color := Color("dff4ff")) -> void:
	var ring := Line2D.new()
	ring.top_level = true
	ring.width = 6.0
	ring.default_color = color
	var points := PackedVector2Array()
	for i in 25:
		points.append(Vector2.from_angle(i / 24.0 * TAU) * 24.0)
	ring.points = points
	ring.global_position = global_position + Vector2(facing.x * 30.0, -10)
	ring.z_index = 6
	ring.add_to_group(&"vfx")
	get_parent().add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector2(3.5, 3.5), 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(ring.queue_free)
