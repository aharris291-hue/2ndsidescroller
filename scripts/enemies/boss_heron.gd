class_name BossHeron
extends Node2D
## The Grey Heron, Watermark Marsh's boss: the watermark bird from the reeds, which
## stood and watched the night of the flood and did nothing either.
##
## It stalks the peat between two ink pools, keeping a neck's length from Patch, and:
## - Stabs: its head draws back (a ripple marks the spot), then the neck shoots out and
##   the beak spears where Patch stood. Into ink it only splashes. Into peat it sticks
##   fast, and while it pulls, its head and beak are open to the shears (three cuts, or
##   the Hold broken for an Unstitch).
## - Sweeps (from the second third of its health): it spreads its wings low and a gust of
##   torn feathers runs the length of the floor both ways. Nothing on the peat survives
##   it standing; a blot in the ink is untouched. In the last third it shakes moths out
##   of its feathers as well, and stabs sooner.
## At zero health it folds down into the reeds, and is only paper with a bird printed
## on it.
##
## The art faces left; `scale.x = -1` turns it to face right. The beak, head and neck
## points are where they sit in the painting (tools/art/dark_heron.py).

enum State { WAITING, STALKING, WINDUP, STAB, STUCK, SWEEP, DEFEATED }

const MOTH_SCENE := preload("res://scenes/enemies/paper_moth.tscn")
const BEAK_TIP := Vector2(-411, -489)
const HEAD := Vector2(-240, -588)
const NECK := Vector2(-208, -490)

@export var boss_name := "The Grey Heron"
@export var exit_door: PageDoor
@export var start_zone: Area2D
@export var arena_left := 320.0
@export var arena_right := 1700.0
@export var floor_y := 896.0
## How far from Patch it likes to stand (along the floor).
@export var reach := 430.0
@export var walk_speed := 170.0
## Seconds of wind-up before each stab, per third of its health.
@export var stab_windups: Array[float] = [0.85, 0.7, 0.55]
## Seconds between attacks, per third.
@export var rests: Array[float] = [1.3, 1.0, 0.75]
@export var stuck_time := 2.4
@export var sweep_warn := 1.3
@export var defeated_flag := "boss_heron_defeated"
@export var defeat_dialogue := "heron_down"

var state := State.WAITING
var attacks := 0
var _rest_left := 1.5
var _target := Vector2.ZERO
var _hits_this_stuck := 0
var _told_stuck := false
var _head_home := Vector2.ZERO
var _tween: Tween

var body: Sprite2D
var head: Node2D
var neck: Line2D
var beak: Hitbox
var skull: Hurtbox
@onready var health: HealthComponent = $HealthComponent

var hold: HoldComponent
var bestiary_id := "heron"


func _ready() -> void:
	_build()
	_head_home = head.position
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	skull.hit.connect(_on_skull_hit)
	health.died.connect(_on_defeated)
	beak.active = false
	_set_open(false)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag) and not Rematch.watch(self):
		_show_exit()
		queue_free()
		return
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)


## The painted bird in two pieces (tools/art/dark_heron.py), the neck between them,
## the beak that hurts and the head that can be cut.
func _build() -> void:
	const BODY_TEX := preload("res://assets/art/dark/bosses/heron_body.png")
	const HEAD_TEX := preload("res://assets/art/dark/bosses/heron_head.png")
	var top_left := Vector2(-BODY_TEX.get_width() / 2.0, -BODY_TEX.get_height())
	neck = Line2D.new()
	neck.width = 34.0
	neck.default_color = Color(0.34, 0.32, 0.29)
	# Shadowed feathers at the shoulder, fading lighter and thinner toward the head,
	# so the stretched neck reads as the same grey paper as the body.
	neck.gradient = Gradient.new()
	neck.gradient.set_color(0, Color(0.22, 0.21, 0.2))
	neck.gradient.set_color(1, Color(0.5, 0.47, 0.42))
	neck.width_curve = Curve.new()
	neck.width_curve.add_point(Vector2(0.0, 1.0))
	neck.width_curve.add_point(Vector2(1.0, 0.6))
	neck.begin_cap_mode = Line2D.LINE_CAP_ROUND
	neck.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(neck)
	body = Sprite2D.new()
	body.texture = BODY_TEX
	body.centered = false
	body.position = top_left
	add_child(body)
	head = Node2D.new()
	head.position = NECK
	add_child(head)
	var art := Sprite2D.new()
	art.texture = HEAD_TEX
	art.centered = false
	art.position = top_left - NECK
	head.add_child(art)
	beak = Hitbox.new()
	beak.collision_layer = 16
	beak.collision_mask = 0
	beak.monitoring = false
	beak.damage = 2
	beak.knockback = 700.0
	var tip := CollisionShape2D.new()
	var tip_shape := CircleShape2D.new()
	tip_shape.radius = 46.0
	tip.shape = tip_shape
	tip.position = BEAK_TIP - NECK
	beak.add_child(tip)
	head.add_child(beak)
	# The head and the length of the beak, from the eye to the tip.
	skull = Hurtbox.new()
	skull.collision_layer = 0
	skull.collision_mask = 8
	var along := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	var from := HEAD - NECK
	var to := BEAK_TIP - NECK
	capsule.radius = 52.0
	capsule.height = from.distance_to(to) + capsule.radius * 2.0
	along.shape = capsule
	along.position = (from + to) / 2.0
	along.rotation = (to - from).angle() - PI / 2.0
	skull.add_child(along)
	head.add_child(skull)
	for node: Node in [beak, skull]:
		node.owner = self


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.STALKING
	_rest_left = 1.2
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("The heron turned its head and looked at him with one pale eye, the way it had looked at him from the reeds that night.")


## 0, 1 or 2: which third of its health it is in.
func phase() -> int:
	return clampi(3 - ceili(float(health.current) / health.max_health * 3.0), 0, 2)


func _physics_process(delta: float) -> void:
	_draw_neck()
	if state != State.STALKING:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# Face Patch, and keep a neck's length away from him.
	var side := 1.0 if player.global_position.x < global_position.x else -1.0
	scale.x = side
	var want := clampf(player.global_position.x + reach * side, arena_left, arena_right)
	global_position.x = move_toward(global_position.x, want, walk_speed * delta)
	head.position = _head_home + Vector2(0, sin(Time.get_ticks_msec() * 0.003) * 6.0)
	_rest_left -= delta
	if _rest_left <= 0.0:
		attacks += 1
		var sweep_every := 3 if phase() == 1 else 2
		if phase() >= 1 and attacks % sweep_every == 0:
			_sweep()
		else:
			_stab(player.global_position + Vector2(0, 40))


func _stab(at: Vector2) -> void:
	state = State.WINDUP
	_target = Vector2(clampf(at.x, arena_left - 300.0, arena_right + 300.0), minf(at.y, floor_y))
	var windup := stab_windups[phase()]
	var mark := _ripple(_target, windup)
	AudioManager.play_sfx(&"page_flip", 0.45, -6.0)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# Draw back.
	_tween.tween_property(head, "position", _head_home + Vector2(70, -40), windup).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(head, "rotation", 0.3, windup)
	_tween.tween_callback(func() -> void:
		state = State.STAB
		beak.active = true)
	# Strike: the neck shoots out so the beak tip lands on the mark.
	var local := to_local(_target)
	var b := BEAK_TIP - NECK
	var dir := (local - NECK).normalized()
	var pose := local - dir * b.length()
	var turn := b.angle_to(dir)
	_tween.tween_property(head, "position", pose, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(head, "rotation", turn, 0.11)
	_tween.tween_callback(func() -> void:
		mark.queue_free()
		_landed())


func _landed() -> void:
	get_tree().create_timer(0.15, false).timeout.connect(func() -> void: beak.active = false)
	if InkPool.ink_at(get_tree(), _target + Vector2(0, 12)):
		# Into the ink: a splash, and nothing to hold it.
		AudioManager.play_sfx(&"enemy_pop", 0.4, -4.0)
		_recover(0.45)
		return
	state = State.STUCK
	_hits_this_stuck = 0
	AudioManager.play_sfx(&"tab_pull", 0.5)
	if not _told_stuck:
		_told_stuck = true
		DialogueUI.narrate("Its beak went into the peat to the eyes. It pulled. The peat held.")
	_set_open(true)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# It strains to pull free.
	for i in 4:
		_tween.tween_property(head, "position:x", head.position.x + 6.0, stuck_time / 8.0)
		_tween.tween_property(head, "position:x", head.position.x - 6.0, stuck_time / 8.0)
	_tween.tween_callback(func() -> void:
		if state == State.STUCK:
			_recover(0.5))


func _recover(time: float) -> void:
	if state == State.DEFEATED:
		return
	state = State.WINDUP  # busy until the head is home
	beak.active = false
	_set_open(false)
	BossStagger.close(hold)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(head, "position", _head_home, time).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(head, "rotation", 0.0, time)
	_tween.tween_callback(func() -> void:
		if state != State.DEFEATED:
			state = State.STALKING
			_rest_left = rests[phase()])


func _sweep() -> void:
	state = State.SWEEP
	if attacks <= 3:
		DialogueUI.narrate("It spread its wings low over the peat.")
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(body, "scale", Vector2(1.18, 0.9), sweep_warn).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(body, "self_modulate", Color(1.25, 1.2, 1.1), sweep_warn)
	_tween.tween_callback(func() -> void:
		AudioManager.play_sfx(&"dash", 0.5)
		for d in [-1.0, 1.0]:
			_gust(d)
		if phase() == 2:
			for i in 2:
				var moth := MOTH_SCENE.instantiate() as Node2D
				moth.position = global_position + Vector2(randf_range(-200.0, 200.0), -420.0)
				get_parent().add_child.call_deferred(moth))
	_tween.tween_property(body, "scale", Vector2.ONE, 0.4)
	_tween.parallel().tween_property(body, "self_modulate", Color.WHITE, 0.4)
	_tween.tween_callback(func() -> void:
		if state == State.SWEEP:
			state = State.STALKING
			_rest_left = rests[phase()] + 0.4)


## A gust of torn feathers along the floor, from the heron outwards.
func _gust(direction: float) -> void:
	var gust := Node2D.new()
	gust.position = Vector2(global_position.x, floor_y)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([Vector2(-20, 0), Vector2(-110 * direction, -250), Vector2(60 * direction, -170), Vector2(130 * direction, 0)])
	art.color = Color(0.82, 0.78, 0.68, 0.32)
	gust.add_child(art)
	var feathers := CPUParticles2D.new()
	feathers.amount = 26
	feathers.lifetime = 0.5
	feathers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	feathers.emission_rect_extents = Vector2(40, 120)
	feathers.position = Vector2(0, -120)
	feathers.direction = Vector2(-direction, -0.2)
	feathers.initial_velocity_min = 80.0
	feathers.initial_velocity_max = 200.0
	feathers.gravity = Vector2(0, 120)
	feathers.scale_amount_min = 3.0
	feathers.scale_amount_max = 6.0
	feathers.color = Color(0.86, 0.82, 0.72, 0.85)
	gust.add_child(feathers)
	var hitbox := Hitbox.new()
	hitbox.collision_layer = 16
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.damage = 2
	hitbox.knockback = 520.0
	hitbox.unblockable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(140, 260)
	shape.shape = rect
	shape.position = Vector2(0, -130)
	hitbox.add_child(shape)
	gust.add_child(hitbox)
	gust.add_to_group(&"heron_gusts")
	get_parent().add_child(gust)
	var far := arena_left - 400.0 if direction < 0.0 else arena_right + 400.0
	var t := gust.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(gust, "position:x", far, absf(far - gust.position.x) / 1500.0)
	t.tween_callback(gust.queue_free)


func _ripple(at: Vector2, time: float) -> Node2D:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var a := i / 24.0 * TAU
		points.append(Vector2(cos(a) * 64.0, sin(a) * 14.0))
	ring.polygon = points
	ring.color = Color(0.75, 0.78, 0.9, 0.0)
	ring.position = at + Vector2(0, 4)
	ring.z_index = 6
	get_parent().add_child(ring)
	var t := ring.create_tween()
	t.tween_property(ring, "color:a", 0.5, time)
	t.parallel().tween_property(ring, "scale", Vector2(0.45, 0.45), time).from(Vector2(1.3, 1.3))
	return ring


func _on_skull_hit(hitbox: Hitbox) -> void:
	if state != State.STUCK:
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"enemy_pop", 0.7)
		head.modulate = Color(1.8, 1.6, 1.5)
		create_tween().tween_property(head, "modulate", Color.WHITE, 0.25)
		_hits_this_stuck += 1
		if not health.is_dead() and _hits_this_stuck >= 3 and not hold.is_broken():
			_recover(0.4)


func _on_defeated() -> void:
	if Rematch.intercept(self):
		return
	state = State.DEFEATED
	_kill_tween()
	beak.active = false
	_set_open(false)
	Bestiary.record(self)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	for gust in get_tree().get_nodes_in_group(&"heron_gusts"):
		gust.queue_free()
	var t := create_tween().set_parallel()
	t.tween_property(head, "position", Vector2(-260, -40), 1.6).set_trans(Tween.TRANS_BOUNCE)
	t.tween_property(head, "rotation", -1.2, 1.6)
	t.tween_property(body, "position:y", body.position.y + 120.0, 2.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "modulate", Color(0.6, 0.62, 0.7, 0.75), 2.2)
	await t.finished
	if not defeat_dialogue.is_empty():
		DialogueUI.start(defeat_dialogue)
		await EventBus.dialogue_finished
	_show_exit()
	GameState.save_game()


func _show_exit() -> void:
	if exit_door:
		exit_door.visible = true
		exit_door.set_deferred("monitorable", true)


func _set_open(open: bool) -> void:
	skull.set_deferred("monitoring", open)
	head.self_modulate = Color.WHITE if open else Color(0.85, 0.85, 0.92)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _draw_neck() -> void:
	# The neck stretches from the shoulders to wherever the head has gone.
	# A slight sag in the middle keeps it from looking like a rod.
	var a := NECK + Vector2(4, 24)
	var b := head.position + Vector2(8, -6)
	var mid := (a + b) * 0.5 + Vector2(0, minf(a.distance_to(b) * 0.08, 30.0))
	neck.points = PackedVector2Array([a, mid, b])
	neck.visible = a.distance_to(b) > 40.0


# --- Hold and the Unstitch (see BossStagger) -----------------------------------

func can_stagger() -> bool:
	return state == State.STUCK


func finisher_point() -> Vector2:
	return skull.global_position


func _on_hold_broken() -> void:
	# The peat keeps it fast for the stagger.
	if _tween and _tween.is_valid():
		_tween.kill()
	get_tree().create_timer(hold.stagger_time, false).timeout.connect(func() -> void:
		if state == State.STUCK:
			_recover(0.5))


func unstitch(_by: Node) -> void:
	if state != State.STUCK:
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	body.modulate = Color(1.9, 1.6, 1.5)
	create_tween().tween_property(body, "modulate", Color.WHITE, 0.4)
	if BossStagger.unstitch(self, health, hold):
		DialogueUI.narrate("Patch cut along the seam of its neck. A whole page of feathers came away and floated off on the ink.")
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if state == State.STUCK:
				_recover(0.5))
