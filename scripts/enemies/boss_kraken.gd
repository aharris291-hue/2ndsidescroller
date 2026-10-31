class_name BossKraken
extends Node2D
## The Blotch Kraken, the Chapter 2 boss: a harbor's worth of spilled ink with one eye.
##
## Loop: its tentacles slam down where Patch stands (a shadow warns him first). Tape Tail
## both blotter rings to drop the pink blotting paper onto it; the blotters soak up its
## ink and it slumps, eye exposed, for a few seconds. Swipe the eye. Three hits (or the
## timer) and it shakes the blotters off, sends Soggies, and slams faster.
## At zero health it is soaked dry, not destroyed, and the Drizzle reveal plays.

enum State { WAITING, ATTACKING, STUNNED, DEFEATED }

const SOGGY_SCENE := preload("res://scenes/enemies/soggy.tscn")
const TENTACLE_TEXTURE := preload("res://assets/art/characters/kraken_tentacle.png")

@export var boss_name := "The Blotch Kraken"
## The two YANK GrapplePoints that drop the blotters.
@export var rings: Array[Node] = []
## The blotter sprites that fall onto the Kraken (one per ring).
@export var blotters: Array[Node2D] = []
@export var exit_door: PageDoor
@export var start_zone: Area2D
## Seconds between tentacle slams per phase, from full health down.
@export var slam_intervals: Array[float] = [2.0, 1.55, 1.15]
@export var warn_time := 0.75
@export var stun_time := 5.0
@export var arena_left := 128.0
@export var arena_right := 1440.0
@export var floor_y := 896.0
@export var defeated_flag := "boss_kraken_defeated"
@export var defeat_dialogue := "kraken_drizzle"

var state := State.WAITING
var _slam_left := 1.5
var _stun_left := 0.0
var _hits_this_stun := 0
var _blotter_home: Array[Vector2] = []
var _rest_position := Vector2.ZERO

@onready var body: Sprite2D = $Body
@onready var eye: Hurtbox = $Eye
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	_rest_position = position
	eye.hit.connect(_on_eye_hit)
	health.died.connect(_on_defeated)
	for ring in rings:
		(ring as GrapplePoint).yanked.connect(_on_ring_yanked)
	for blotter in blotters:
		_blotter_home.append(blotter.position)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag):
		_show_exit()
		for blotter in blotters:
			blotter.visible = false
		for ring in rings:
			(ring as GrapplePoint).enabled = false
		queue_free()
		return
	_set_eye_exposed(false)
	_set_rings_enabled(false)
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.ATTACKING
	_set_rings_enabled(true)
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("The harbor ink heaved up into a Kraken! Tape Tail both blotter rings to drop the blotting paper on it!")


func _physics_process(delta: float) -> void:
	# A slow, heavy sway, like a spill that can't sit still.
	var sway := sin(Time.get_ticks_msec() * 0.0016) * 10.0
	match state:
		State.ATTACKING:
			position = position.lerp(_rest_position + Vector2(0, sway), 4.0 * delta)
			_slam_left -= delta
			if _slam_left <= 0.0:
				_slam_left = _slam_interval()
				_slam()
		State.STUNNED:
			_stun_left -= delta
			if _stun_left <= 0.0:
				_recover()


func _slam_interval() -> float:
	var phase := clampi(slam_intervals.size() - ceili(float(health.current) / health.max_health * slam_intervals.size()), 0, slam_intervals.size() - 1)
	return slam_intervals[phase]


func _slam() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var x := player.global_position.x if player else randf_range(arena_left, arena_right)
	x = clampf(x + randf_range(-40.0, 40.0), arena_left, arena_right)
	var tentacle := Node2D.new()
	tentacle.position = Vector2(x, -700.0)
	var art := Sprite2D.new()
	art.texture = TENTACLE_TEXTURE
	art.offset = Vector2(0, -TENTACLE_TEXTURE.get_height() / 2.0)
	tentacle.add_child(art)
	var hitbox := Hitbox.new()
	hitbox.collision_layer = 16
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.damage = 2
	hitbox.knockback = 650.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 260)
	shape.shape = rect
	shape.position = Vector2(0, -140)
	hitbox.add_child(shape)
	tentacle.add_child(hitbox)
	# The warning: a dark ink shadow on the floor where it will land.
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 20:
		var a := i / 20.0 * TAU
		points.append(Vector2(cos(a) * 70.0, sin(a) * 16.0))
	shadow.polygon = points
	shadow.color = Color(0.1, 0.12, 0.3, 0.0)
	shadow.position = Vector2(x, floor_y)
	get_parent().add_child(shadow)
	get_parent().add_child(tentacle)
	hitbox.active = false

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(shadow, "color:a", 0.55, warn_time)
	tween.tween_callback(func() -> void: hitbox.active = true)
	tween.tween_property(tentacle, "position:y", floor_y + 8.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: AudioManager.play_sfx(&"enemy_pop", 0.5))
	tween.tween_interval(0.25)
	tween.tween_callback(func() -> void: hitbox.active = false)
	tween.tween_interval(0.45)
	tween.tween_property(tentacle, "position:y", -700.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(shadow, "color:a", 0.0, 0.3)
	tween.tween_callback(tentacle.queue_free)
	tween.tween_callback(shadow.queue_free)


func _on_ring_yanked() -> void:
	if state != State.ATTACKING:
		return
	# Each yanked ring drops its blotter part-way; both together finish the job.
	for i in rings.size():
		var ring := rings[i] as GrapplePoint
		if ring.used and i < blotters.size() and blotters[i].position == _blotter_home[i]:
			var drop := create_tween()
			drop.tween_property(blotters[i], "position", _blotter_home[i] + Vector2(0, 260), 0.35).set_trans(Tween.TRANS_BACK)
	for ring in rings:
		if not (ring as GrapplePoint).used:
			return
	_stun()


func _stun() -> void:
	state = State.STUNNED
	_stun_left = stun_time
	_hits_this_stun = 0
	DialogueUI.narrate("The blotters soaked up its ink! The Kraken slumped down. Swipe its eye!")
	AudioManager.play_sfx(&"tab_pull", 0.6)
	var tween := create_tween().set_parallel()
	# Slump so the eye sits at Patch's height.
	tween.tween_property(self, "position", _rest_position + Vector2(-130, 166), 0.5).set_trans(Tween.TRANS_BOUNCE)
	for i in blotters.size():
		tween.tween_property(blotters[i], "position", _rest_position + Vector2(-110 + i * 200, -300), 0.5)
	tween.tween_property(body, "self_modulate", Color(0.8, 0.85, 1.1), 0.5)
	_set_eye_exposed(true)


func _on_eye_hit(hitbox: Hitbox) -> void:
	if state != State.STUNNED:
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"enemy_pop", 0.6)
		var flash := create_tween()
		eye.modulate = Color(1.8, 1.6, 1.6)
		flash.tween_property(eye, "modulate", Color.WHITE, 0.25)
		_hits_this_stun += 1
		if not health.is_dead() and _hits_this_stun >= 3:
			_recover()


func _recover() -> void:
	if state == State.DEFEATED:
		return
	state = State.ATTACKING
	_slam_left = 1.2
	_set_eye_exposed(false)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position", _rest_position, 0.6).set_trans(Tween.TRANS_BACK)
	tween.tween_property(body, "self_modulate", Color.WHITE, 0.6)
	for i in blotters.size():
		tween.tween_property(blotters[i], "position", _blotter_home[i], 0.8)
	for ring in rings:
		(ring as GrapplePoint).reset()
	for i in 2:
		var soggy := SOGGY_SCENE.instantiate() as Node2D
		soggy.position = Vector2(randf_range(arena_left + 100.0, arena_right - 200.0), floor_y - 300.0)
		get_parent().add_child.call_deferred(soggy)


func _on_defeated() -> void:
	state = State.DEFEATED
	_set_eye_exposed(false)
	eye.visible = false
	_set_rings_enabled(false)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 2.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(body, "self_modulate", Color(0.75, 0.85, 1.2, 0.85), 2.2)
	for blotter in blotters:
		tween.tween_property(blotter, "modulate", Color(0.5, 0.5, 0.9), 2.2)
	await tween.finished
	if not defeat_dialogue.is_empty():
		DialogueUI.start(defeat_dialogue)
		await EventBus.dialogue_finished
	_show_exit()
	GameState.save_game()


func _show_exit() -> void:
	if exit_door:
		exit_door.visible = true
		exit_door.set_deferred("monitorable", true)


func _set_rings_enabled(enabled: bool) -> void:
	for ring in rings:
		(ring as GrapplePoint).enabled = enabled


func _set_eye_exposed(exposed: bool) -> void:
	# The eye always glares; it can only be hit while the Kraken is stunned.
	eye.modulate = Color.WHITE if exposed else Color(0.75, 0.75, 0.9)
	eye.set_deferred("monitoring", exposed)
