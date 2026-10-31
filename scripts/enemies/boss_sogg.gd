class_name BossSogg
extends Node2D
## The Sogg, phases 1 and 2 (the top of the Spine Peaks, Chapter 3). A storm cloud of
## soaked paper that used to be Drizzle, the Weather Page's little rain cloud.
##
## Loop: it drifts high over the arena, raining drips on Patch, then dives down where he
## stands (a shadow warns him first) and sits there soaking the page. A Pop-Up Slam near
## a fold mark under it springs a paper peak into its belly: it reels, pinned, and the
## small pale cloud in its chest (Drizzle) is exposed. Swipe it. Three hits or the timer
## and it tears free. At half health it swells up (phase 2): more rain, faster dives,
## Soggies. At zero it isn't beaten: it grabs Patch and drags him down into the Gutter.

enum State { WAITING, DRIFT, WARN, DIVE, SOAK, STUNNED, DEFEATED }

const SOGGY_SCENE := preload("res://scenes/enemies/soggy.tscn")
const DRIP_SCENE := preload("res://scenes/enemies/ink_drip.tscn")

@export var boss_name := "The Sogg"
## The FoldMarks on the arena floor. A peak springing under the Sogg stuns it.
@export var fold_marks: Array[Node] = []
@export var exit_door: PageDoor
@export var start_zone: Area2D
@export var arena_left := 128.0
@export var arena_right := 1700.0
@export var floor_y := 896.0
## How high the Sogg drifts above the floor between dives.
@export var hover_height := 560.0
## Seconds between dives in phase 1 and phase 2.
@export var dive_intervals: Array[float] = [3.2, 2.2]
@export var rain_intervals: Array[float] = [0.75, 0.45]
@export var warn_time := 0.8
@export var soak_time := 1.8
@export var stun_time := 4.5
## How close (horizontally) a springing peak must be to catch the Sogg.
@export var catch_range := 230.0
@export var defeated_flag := "boss_sogg_phase2_done"
@export var defeat_dialogue := "sogg_drags_patch"
## Where the story goes once the Sogg drags Patch away (the interlude).
@export_file("*.tscn") var next_page := ""

var state := State.WAITING
var phase := 0
var _dive_left := 2.0
var _rain_left := 1.0
var _state_left := 0.0
var _hits_this_stun := 0
var _dive_x := 0.0
var _shadow: Polygon2D

@onready var body: Sprite2D = $Body
@onready var heart: Hurtbox = $Heart
@onready var contact: Hitbox = $ContactHitbox
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	heart.hit.connect(_on_heart_hit)
	health.died.connect(_on_defeated)
	for mark in fold_marks:
		var fold := mark as FoldMark
		fold.popped.connect(_on_peak_popped.bind(fold))
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag):
		_show_exit()
		queue_free()
		return
	position.y = floor_y - hover_height
	_set_heart_exposed(false)
	contact.active = false
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.DRIFT
	_dive_left = 2.5
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("Lure the Sogg down beside a fold mark, then Pop-Up Slam with %s to spear it with a peak!" % InputGlyphs.hint(&"slam"))


func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	match state:
		State.DRIFT:
			var player := _player()
			var target_x := clampf(player.global_position.x if player else position.x, arena_left + 160.0, arena_right - 160.0)
			position.x = move_toward(position.x, target_x, (230.0 if phase == 0 else 320.0) * delta)
			position.y = lerpf(position.y, floor_y - hover_height + sin(t * 1.4) * 24.0, 3.0 * delta)
			body.rotation = sin(t * 0.9) * 0.04
			_rain_left -= delta
			if _rain_left <= 0.0:
				_rain_left = rain_intervals[phase] * randf_range(0.8, 1.2)
				_rain(player)
			_dive_left -= delta
			if _dive_left <= 0.0:
				_warn(player)
		State.WARN:
			_state_left -= delta
			position.x = move_toward(position.x, _dive_x, 600.0 * delta)
			if _state_left <= 0.0:
				_dive()
		State.SOAK:
			_state_left -= delta
			body.scale.x = absf(body.scale.y) * (1.0 + sin(t * 9.0) * 0.03)
			if _state_left <= 0.0:
				_rise()
		State.STUNNED:
			_state_left -= delta
			body.rotation = sin(t * 14.0) * 0.05
			if _state_left <= 0.0:
				_recover()


func _player() -> Patch:
	return get_tree().get_first_node_in_group("player") as Patch


func _rain(player: Node2D) -> void:
	var x := (player.global_position.x if player else position.x) + randf_range(-320.0, 320.0)
	x = clampf(x, arena_left, arena_right)
	var drip := DRIP_SCENE.instantiate() as Node2D
	drip.position = Vector2(x, position.y - 80.0)
	drip.set("floor_y", floor_y - 20.0)
	drip.modulate = Color(0.75, 0.9, 1.3)
	get_parent().add_child(drip)


func _warn(player: Node2D) -> void:
	state = State.WARN
	_state_left = warn_time
	_dive_x = clampf(player.global_position.x if player else position.x, arena_left + 160.0, arena_right - 160.0)
	# A wet shadow spreads on the floor where it is about to land.
	_shadow = Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var a := i / 24.0 * TAU
		points.append(Vector2(cos(a) * 200.0, sin(a) * 26.0))
	_shadow.polygon = points
	_shadow.color = Color(0.2, 0.26, 0.45, 0.0)
	_shadow.position = Vector2(_dive_x, floor_y)
	get_parent().add_child(_shadow)
	get_parent().move_child(_shadow, get_index())
	var tween := _shadow.create_tween()
	tween.tween_property(_shadow, "color:a", 0.5, warn_time)


func _dive() -> void:
	state = State.DIVE
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", Vector2(_dive_x, floor_y), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if state != State.DIVE:
			return
		contact.active = true
		AudioManager.play_sfx(&"slam", 0.6)
		var player := _player()
		if player:
			player._shake_camera(18.0)
		state = State.SOAK
		_state_left = soak_time)


func _rise() -> void:
	contact.active = false
	_clear_shadow()
	state = State.DRIFT
	_dive_left = dive_intervals[phase] * randf_range(0.85, 1.15)
	body.scale.x = absf(body.scale.y)


func _on_peak_popped(mark: FoldMark) -> void:
	if state != State.SOAK and state != State.DIVE:
		return
	if absf(mark.global_position.x - global_position.x) > catch_range:
		return
	_stun(mark)


func _stun(mark: FoldMark) -> void:
	state = State.STUNNED
	_state_left = stun_time
	_hits_this_stun = 0
	contact.active = false
	_clear_shadow()
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	DialogueUI.narrate("The peak caught the Sogg in the middle! It's pinned. Swipe the little cloud in its chest!")
	# Knocked up and to the side of the peak, so its chest hangs where Patch can reach.
	var side := signf(global_position.x - mark.global_position.x)
	if side == 0.0:
		side = 1.0
	var pinned := Vector2(clampf(mark.global_position.x + side * 190.0, arena_left + 160.0, arena_right - 160.0), floor_y - 60.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position", pinned, 0.35).set_trans(Tween.TRANS_BACK)
	tween.tween_property(body, "self_modulate", Color(0.85, 0.9, 1.15), 0.35)
	_set_heart_exposed(true)


func _on_heart_hit(hitbox: Hitbox) -> void:
	if state != State.STUNNED:
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"enemy_pop", 0.7)
		heart.modulate = Color(1.8, 1.8, 1.8)
		create_tween().tween_property(heart, "modulate", Color.WHITE, 0.25)
		_hits_this_stun += 1
		if not health.is_dead() and _hits_this_stun >= 3:
			_recover()


func _recover() -> void:
	if state == State.DEFEATED:
		return
	_set_heart_exposed(false)
	body.rotation = 0.0
	create_tween().tween_property(body, "self_modulate", Color.WHITE, 0.5)
	if phase == 0 and health.current <= health.max_health / 2:
		phase = 1
		DialogueUI.narrate("The Sogg pulled more water out of the page and swelled up even bigger. Its rain came down harder.")
		create_tween().tween_property(body, "scale", body.scale * 1.12, 0.6).set_trans(Tween.TRANS_BACK)
	if phase == 1:
		for i in 2:
			var soggy := SOGGY_SCENE.instantiate() as Node2D
			soggy.position = Vector2(randf_range(arena_left + 100.0, arena_right - 100.0), floor_y - 300.0)
			get_parent().add_child.call_deferred(soggy)
	_rise()


func _on_defeated() -> void:
	state = State.DEFEATED
	_set_heart_exposed(false)
	contact.active = false
	_clear_shadow()
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	# It isn't beaten. It's only angry.
	var player := _player()
	var tween := create_tween()
	tween.tween_property(body, "self_modulate", Color(0.55, 0.6, 0.85), 0.8)
	tween.parallel().tween_property(self, "position:y", floor_y - 140.0, 0.8)
	await tween.finished
	if not defeat_dialogue.is_empty():
		DialogueUI.start(defeat_dialogue)
		await EventBus.dialogue_finished
	if player and is_instance_valid(player):
		player.input_enabled = false
		var grab := create_tween().set_parallel()
		grab.tween_property(self, "global_position", player.global_position + Vector2(0, 120), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		grab.tween_property(body, "scale", body.scale * 1.6, 0.5)
		await grab.finished
		player.visible = false
		AudioManager.play_sfx(&"slam", 0.5)
		var sink := create_tween()
		sink.tween_property(self, "position:y", floor_y + 700.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await sink.finished
	GameState.save_game()
	if not next_page.is_empty():
		SceneManager.change_page(next_page)
	else:
		_show_exit()


func _clear_shadow() -> void:
	if _shadow and is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null


func _show_exit() -> void:
	if exit_door:
		exit_door.visible = true
		exit_door.set_deferred("monitorable", true)


func _set_heart_exposed(exposed: bool) -> void:
	heart.visible = exposed
	heart.set_deferred("monitoring", exposed)
