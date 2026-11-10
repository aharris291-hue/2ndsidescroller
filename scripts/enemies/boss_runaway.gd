class_name BossRunaway
extends CharacterBody2D
## The Runaway, at the bottom of the Last Margin (the true ending): Patch as he was on
## the night of the flood, the fox who pulled his tail out of Drizzle's hands and ran,
## printed in wet ink. Same painting, same rig (DarkRig, on Papers.INK), same shears.
##
## He fights the way Patch fought before he learned better:
## - Stalks to a shears' length, glints, and cuts three times (four in the last third),
##   stepping in with each cut. A parry staggers him: his Hold tears and his seams show.
## - Takes three cuts close together, then runs: a dash to the far end of the floor.
##   That's what he does. From the second third he throws ink from there, and in the
##   last third he comes back the length of the floor in one low lunge (jump it, or
##   dodge through it).
## - From the second third, light cuts may meet his guard. A heavy cut breaks it and
##   leaves him open.
## At zero health he doesn't fall apart. He kneels, and waits to be cut. Cutting him does
## nothing: Patch has to put the shears down and hold out his paw (MendSpot). Then the
## ink runs off him, the fox under it is Patch, and the book's true ending follows.

enum Mode { WAITING, STALK, WINDUP, COMBO, RUN, THROW, LUNGE, GUARD, STAGGER, KNEEL, MENDED }

const SHOT_SCENE := preload("res://scenes/enemies/ink_shot.tscn")
const HAND_DIALOGUE := "runaway_hand"

@export var boss_name := "The Runaway"
@export var start_zone: Area2D
@export var arena_left := 256.0
@export var arena_right := 2300.0
@export var floor_y := 896.0
@export var run_speed := 380.0
@export var attack_time := 0.2
@export var reach := 150.0
@export var defeated_flag := "boss_runaway_defeated"
@export_file("*.tscn") var next_page := "res://scenes/levels/postgame/the_last_margin_end.tscn"

## What DarkRig reads (he looks like Patch to it).
var state: int = Patch.State.NORMAL
var combo_step := 0
var view_mode: PageView.Mode = PageView.Mode.SIDE
var charge_level := 0
var _attack_kind: int = Patch.Attack.LIGHT
var _heavy_phase := 0

var mode := Mode.WAITING
var facing := -1.0
var _left := 0.0
var _swings := 0
var _recent_hits: Array[float] = []
var _refused := 0.0
var _clock := 0.0

var visual: Node2D
var rig: DarkRig
var blade: Hitbox
var hurtbox: Hurtbox
var hold: HoldComponent
var mend_spot: MendSpot
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_build()
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	hurtbox.hit.connect(_on_hurt)
	health.died.connect(_on_defeated)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag):
		queue_free()


func _build() -> void:
	visual = Node2D.new()
	visual.name = &"Visual"
	add_child(visual)
	rig = DarkRig.new()
	rig.display_height = 160.0
	rig.feet_offset = Vector2(0, 0)
	visual.add_child(rig)
	rig.set_paper(Papers.INK)
	rig.set_mended(false)
	var body_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 26.0
	capsule.height = 120.0
	body_shape.shape = capsule
	body_shape.position = Vector2(0, -60)
	add_child(body_shape)
	hurtbox = Hurtbox.new()
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 8
	var hurt_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 140)
	hurt_shape.shape = rect
	hurt_shape.position = Vector2(0, -70)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	blade = Hitbox.new()
	blade.collision_layer = 16
	blade.collision_mask = 0
	blade.monitoring = false
	blade.damage = 2
	blade.knockback = 560.0
	blade.active = false
	var cut := CollisionShape2D.new()
	var cut_rect := RectangleShape2D.new()
	cut_rect.size = Vector2(130, 110)
	cut.shape = cut_rect
	cut.position = Vector2(80, -70)
	blade.add_child(cut)
	visual.add_child(blade)
	# Hits are traced back to their owner (Patch's parry tears this one's Hold).
	hurtbox.owner = self
	blade.owner = self


func start_fight() -> void:
	if mode != Mode.WAITING:
		return
	mode = Mode.STALK
	_left = 1.0
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("Patch, in ink. The same ears, the same shears, the same torn stump where a tail should be. He looked at Patch the way you look at someone who has come to take something off you.")


## 0, 1 or 2: which third of his health he is in.
func phase() -> int:
	return clampi(3 - ceili(float(health.current) / health.max_health * 3.0), 0, 2)


func _player() -> Patch:
	return get_tree().get_first_node_in_group(&"player") as Patch


func _physics_process(delta: float) -> void:
	_clock += delta
	_refused = maxf(_refused - delta, 0.0)
	_left -= delta
	velocity.y = minf(velocity.y + 2300.0 * delta, 1400.0)
	var p := _player()
	match mode:
		Mode.STALK:
			_stalk(p, delta)
		Mode.WINDUP:
			velocity.x = 0.0
			if _left <= 0.0:
				_begin_swing()
		Mode.COMBO:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			if _left <= 0.0:
				_end_swing()
		Mode.RUN:
			if (facing > 0.0 and global_position.x >= _run_target()) or (facing < 0.0 and global_position.x <= _run_target()) or _left <= 0.0:
				_arrived()
		Mode.THROW:
			velocity.x = 0.0
			if _left <= 0.0:
				_after_throw()
		Mode.LUNGE:
			if _left <= 0.0 or global_position.x <= arena_left + 80.0 or global_position.x >= arena_right - 80.0:
				_end_lunge()
		Mode.GUARD:
			velocity.x = 0.0
			if _left <= 0.0:
				_set_mode(Mode.STALK, 0.4)
		Mode.STAGGER, Mode.KNEEL, Mode.MENDED, Mode.WAITING:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_left + 40.0, arena_right - 40.0)
	visual.scale.x = facing
	rig.drive(self, delta)


func _set_mode(m: Mode, time: float) -> void:
	mode = m
	_left = time
	_heavy_phase = 0
	charge_level = 0
	blade.active = false
	blade.set_deferred("monitorable", false)
	match m:
		Mode.WINDUP:
			state = Patch.State.HEAVY
			charge_level = 1
		Mode.COMBO:
			state = Patch.State.ATTACK
		Mode.RUN, Mode.LUNGE:
			state = Patch.State.DASH
		Mode.GUARD:
			state = Patch.State.GUARD
		Mode.STAGGER, Mode.KNEEL:
			state = Patch.State.HURT
		_:
			state = Patch.State.NORMAL


func _stalk(p: Patch, _delta: float) -> void:
	if p == null:
		velocity.x = 0.0
		return
	var dx := p.global_position.x - global_position.x
	facing = signf(dx) if dx != 0.0 else facing
	if absf(dx) > reach:
		velocity.x = facing * run_speed * (1.0 + 0.12 * phase())
	else:
		velocity.x = 0.0
		if _left <= 0.0:
			_windup()


func _windup() -> void:
	_set_mode(Mode.WINDUP, [0.55, 0.45, 0.36][phase()])
	_swings = 3 if phase() < 2 else 4
	combo_step = 0
	# The glint: the shears catch the light before the cut.
	var flash := create_tween()
	flash.tween_property(rig, "modulate", Color(2.2, 2.0, 1.8), 0.08)
	flash.tween_property(rig, "modulate", Color.WHITE, 0.2)
	AudioManager.play_sfx(&"tab_pull", 0.8, -4.0)


func _begin_swing() -> void:
	_set_mode(Mode.COMBO, attack_time + 0.1)
	_attack_kind = Patch.Attack.THRUST if combo_step == _swings - 1 else Patch.Attack.LIGHT
	velocity.x = facing * 340.0
	blade.active = true
	blade.set_deferred("monitorable", true)
	AudioManager.play_sfx(&"swipe", randf_range(0.8, 0.95))


func _end_swing() -> void:
	combo_step += 1
	if combo_step < _swings:
		_begin_swing()
	else:
		_set_mode(Mode.STALK, [1.1, 0.85, 0.65][phase()])


## He runs. Always to the far end from Patch.
func _run() -> void:
	var p := _player()
	var px := p.global_position.x if p else global_position.x
	facing = 1.0 if px < (arena_left + arena_right) * 0.5 else -1.0
	_set_mode(Mode.RUN, 2.5)
	velocity.x = facing * run_speed * 2.2
	_recent_hits.clear()
	AudioManager.play_sfx(&"ink_rush", 0.9)


func _run_target() -> float:
	return arena_right - 160.0 if facing > 0.0 else arena_left + 160.0


func _arrived() -> void:
	velocity.x = 0.0
	facing = -facing
	if phase() >= 1:
		_set_mode(Mode.THROW, 0.5)
		_throw_ink.call_deferred(2 + phase())
	else:
		_set_mode(Mode.STALK, 0.8)


func _throw_ink(count: int) -> void:
	var p := _player()
	for i in count:
		if mode != Mode.THROW or not is_inside_tree():
			return
		var shot := SHOT_SCENE.instantiate() as InkShot
		shot.position = position + Vector2(facing * 60.0, -90)
		shot.use_gravity = false
		var aim := Vector2(facing, 0)
		if p:
			aim = (p.global_position + Vector2(0, -50) - shot.position).normalized()
			aim = Vector2(signf(aim.x) if aim.x != 0.0 else facing, clampf(aim.y, -0.3, 0.3)).normalized()
		shot.velocity = aim * 560.0
		get_parent().add_child(shot)
		AudioManager.play_sfx(&"swipe", 0.5)
		_left = 0.5
		await get_tree().create_timer(0.38, false).timeout


func _after_throw() -> void:
	if phase() >= 2:
		_set_mode(Mode.LUNGE, 1.6)
		velocity.x = facing * run_speed * 2.6
		blade.damage = 2
		blade.active = true
		blade.set_deferred("monitorable", true)
		_attack_kind = Patch.Attack.THRUST
		AudioManager.play_sfx(&"ink_rush", 0.75)
	else:
		_set_mode(Mode.STALK, 0.6)


func _end_lunge() -> void:
	velocity.x = 0.0
	_set_mode(Mode.STALK, 0.9)


func _on_hurt(hitbox: Hitbox) -> void:
	if mode == Mode.KNEEL:
		if _refused <= 0.0:
			_refused = 4.0
			DialogueUI.narrate("The shears went through him and came out clean. Nothing in the book was going to let Patch cut his way out of this one.")
		return
	if mode in [Mode.WAITING, Mode.MENDED]:
		return
	if mode == Mode.GUARD:
		if hitbox.pierces_guard or hitbox.damage >= 2:
			_set_mode(Mode.STAGGER, 1.4)
			hold.take_hold(hold.max_hold)
			DialogueUI.narrate("The heavy cut went through his guard like it wasn't there. He'd never learned to take one.")
		else:
			AudioManager.play_sfx(&"slam", 1.4)
		return
	# From the second third, he starts to see light cuts coming.
	if phase() >= 1 and mode == Mode.STALK and hitbox.damage < 2 and randf() < 0.35:
		_set_mode(Mode.GUARD, 0.9)
		AudioManager.play_sfx(&"slam", 1.4)
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"enemy_pop", 0.75)
		rig.modulate = Color(1.8, 1.7, 1.9)
		create_tween().tween_property(rig, "modulate", Color.WHITE, 0.2)
		if health.is_dead():
			return
		_recent_hits.append(_clock)
		_recent_hits = _recent_hits.filter(func(t: float) -> bool: return _clock - t < 2.5)
		if _recent_hits.size() >= 3 and mode in [Mode.STALK, Mode.WINDUP]:
			_run()


## A parry knocks his cut aside, and him off his feet.
func on_parried(_by: Node) -> void:
	if mode == Mode.COMBO or mode == Mode.LUNGE:
		velocity.x = -facing * 300.0
		_set_mode(Mode.STAGGER, 1.2)


# --- Hold and the Unstitch (see BossStagger) -----------------------------------

func can_stagger() -> bool:
	return mode == Mode.STAGGER


func finisher_point() -> Vector2:
	return global_position + Vector2(0, -80)


func _on_hold_broken() -> void:
	_set_mode(Mode.STAGGER, hold.stagger_time)


func unstitch(_by: Node) -> void:
	if mode != Mode.STAGGER:
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	AudioManager.play_sfx(&"drip", 0.8)
	if BossStagger.unstitch(self, health, hold):
		DialogueUI.narrate("Patch cut along the seam where the ink was thinnest. A whole sheet of the night came off him and was rain again.")
		_set_mode(Mode.STAGGER, 0.6)


func _on_defeated() -> void:
	_set_mode(Mode.KNEEL, 0.0)
	EventBus.boss_defeated.emit()
	for shot in get_parent().get_children():
		if shot is InkShot:
			shot.queue_free()
	# Down on his knees: lower, folded over.
	var kneel := create_tween().set_parallel()
	kneel.tween_property(visual, "position:y", 22.0, 0.5).set_trans(Tween.TRANS_BACK)
	kneel.tween_property(visual, "rotation", 0.12 * facing, 0.5)
	kneel.tween_property(rig, "scale:y", rig.scale.y * 0.82, 0.5)
	DialogueUI.narrate("He went down on his knees in the ink and put his shears on the paper and waited, with his eyes shut, for Patch to finish it.")
	mend_spot = MendSpot.new()
	mend_spot.position = Vector2(0, 0)
	mend_spot.runaway = self
	add_child(mend_spot)


## Patch holds out his paw instead.
func take_hand() -> void:
	if mode != Mode.KNEEL:
		return
	mode = Mode.MENDED
	if is_instance_valid(mend_spot):
		mend_spot.queue_free()
	var p := _player()
	if p:
		p.set(&"input_enabled", false)
	AudioManager.play_sfx(&"heartbeat")
	DialogueUI.start(HAND_DIALOGUE)
	await EventBus.dialogue_finished
	# The ink runs off him: the fox under it is Patch.
	var mat := rig.material as ShaderMaterial
	var t := create_tween()
	if mat:
		t.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"amount", v), 1.0, 0.0, 2.2)
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	await t.finished
	GameState.set_flag(defeated_flag)
	GameState.set_flag("true_ending")
	# After the ending, the book opens again in the Spine, by the door he came through.
	GameState.set_checkpoint(LastMarginDoor.HUB, LastMarginDoor.HUB_SPOT)
	Papers.refresh()
	GameState.save_game()
	if p:
		p.set(&"input_enabled", true)
	if not next_page.is_empty():
		SceneManager.change_page(next_page)


## Where Patch puts the shears down.
class MendSpot extends Interactable:
	var runaway: BossRunaway

	func _init() -> void:
		prompt_text = "Put the shears down. Hold out your paw."
		prompt_offset = Vector2(0, -230)
		collision_layer = 32
		collision_mask = 2

	func _ready() -> void:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(360, 200)
		shape.shape = rect
		shape.position = Vector2(0, -100)
		add_child(shape)
		super._ready()

	func can_interact() -> bool:
		return is_instance_valid(runaway) and runaway.mode == BossRunaway.Mode.KNEEL

	func interact(_player: Patch) -> void:
		runaway.take_hand()
