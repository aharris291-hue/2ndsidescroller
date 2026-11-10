class_name BossForecast
extends Node2D
## The Unwritten Forecast, the Blank Margins' boss (optional): a storm made of every
## blank page at the edge of the book, with Gran's old barometer caught in the middle of
## it, its needle swinging. Nobody ever wrote what the weather would do out here, so it
## does everything. Its origin is the bottom of its body; it hangs over the arena.
##
## The arena is the last blank page, with a gap torn out of its middle that only the rain
## bridges (RainPlatform; it calls the rain itself, RainShower in manual mode).
## Three phases, at fixed shares of its health (Level Design Bible, "Bosses"):
## 1. Rain: it calls a shower every few seconds; the ledges over the gap appear while
##    it pours. Its moves:
##    - Hail: hard drops of ink out of it over Patch.
##    - Downburst: it hangs over him and glows red, then comes down on the page like a
##      dropped weight (can't be guarded). Down there it is spent and open: the
##      barometer is in reach.
## 2. Lightning (from two thirds): white lines crackle on the floor where the bolts
##    will land, then the bolts come down them (can't be guarded).
## 3. Wind (from one third): a wind across the whole page that turns round every
##    `wind_period` seconds; loose sheets swirl the other way just before it does.
## Cuts glance off it while it hangs in the sky. Hold and the Unstitch: BossStagger.

enum State { WAITING, DRIFT, HAIL, DOWNBURST, LIGHTNING, SPENT, DEFEATED }

const ART := preload("res://assets/art/dark/bosses/forecast.png")
const DRIP := preload("res://scenes/enemies/ink_drip.tscn")
const HANG := 430.0
const BOLT_WIDTH := 110.0

@export var boss_name := "The Unwritten Forecast"
@export var start_zone: Area2D
@export var exit_door: PageDoor
## The heart patch it was keeping (hidden until it's beaten).
@export var reward: Node2D
@export var shower: RainShower
@export var arena_left := 128.0
@export var arena_right := 1792.0
@export var floor_y := 896.0
@export var art_scale := 0.62
@export var rain_every: Array[float] = [6.0, 5.2, 4.6]
@export var pour_time := 3.4
@export var downburst_tell := 0.75
@export var spent_time := 2.1
@export var bolt_tell := 1.0
@export var bolts: Array[int] = [0, 2, 3]
@export var rests: Array[float] = [1.3, 1.1, 0.95]
@export var wind_strength := 300.0
@export var wind_period := 8.0
@export var wind_warn := 1.2
@export var defeated_flag := "boss_forecast_defeated"

var state := State.WAITING
var moves := 0
var downbursts := 0
var art: Sprite2D
var hurt: Hurtbox
var hold: HoldComponent
## +1 blowing right, -1 left, 0 still.
var wind := 0.0
var bestiary_id := "forecast"
@onready var health: HealthComponent = $HealthComponent

var _rest_left := 1.5
var _rain_left := 1.0
var _wind_left := 0.0
var _wind_warned := false
var _tween: Tween
var _open := false
var _contact: Hitbox
var _scraps: CPUParticles2D
var _told := {}
var _phase_told := 0


func _ready() -> void:
	_build()
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	hurt.hit.connect(_on_hit)
	health.died.connect(_on_defeated)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group(&"player"):
				start_fight())
	if GameState.get_flag(defeated_flag) and not Rematch.watch(self):
		_show_exit()
		queue_free()
		return
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)
	if reward:
		reward.visible = false
		reward.set_deferred("monitoring", false)


func _build() -> void:
	art = Sprite2D.new()
	art.name = &"Art"
	art.texture = ART
	art.scale = Vector2(art_scale, art_scale)
	art.offset = Vector2(0, -ART.get_height() / 2.0)
	add_child(art)
	hurt = Hurtbox.new()
	hurt.collision_layer = 0
	hurt.collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(300, 300)
	shape.shape = rect
	shape.position = Vector2(-60, -200)
	hurt.add_child(shape)
	add_child(hurt)
	hurt.owner = self
	_contact = Hitbox.new()
	_contact.collision_layer = 16
	_contact.collision_mask = 0
	_contact.damage = 2
	_contact.knockback = 520.0
	_contact.unblockable = true
	_contact.active = false
	var cshape := CollisionShape2D.new()
	var crect := RectangleShape2D.new()
	crect.size = Vector2(420, 220)
	cshape.shape = crect
	cshape.position = Vector2(0, -110)
	_contact.add_child(cshape)
	add_child(_contact)
	_contact.owner = self
	_scraps = CPUParticles2D.new()
	_scraps.amount = 50
	_scraps.lifetime = 1.6
	_scraps.top_level = true
	_scraps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_scraps.emission_rect_extents = Vector2((arena_right - arena_left) / 2.0, 380)
	_scraps.position = Vector2((arena_left + arena_right) / 2.0, floor_y - 400.0)
	_scraps.spread = 14.0
	_scraps.gravity = Vector2(0, 30)
	_scraps.initial_velocity_min = 380.0
	_scraps.initial_velocity_max = 560.0
	_scraps.scale_amount_min = 8.0
	_scraps.scale_amount_max = 16.0
	_scraps.color = Color(0.86, 0.86, 0.84, 0.6)
	_scraps.emitting = false
	add_child(_scraps)
	_set_open(false)


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.DRIFT
	_rest_left = 1.8
	_rain_left = 0.6
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("Out at the very edge of the book, where nobody had written anything, the weather had been left to itself. It had made itself a body out of the blank pages. In the middle of it, ticking, was the barometer from Gran's hall, the one she tapped every morning. The needle swung all the way round.")


## 0 rain, 1 lightning, 2 wind.
func phase() -> int:
	if health.current <= health.max_health / 3:
		return 2
	if health.current <= health.max_health * 2 / 3:
		return 1
	return 0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if state == State.WAITING or state == State.DEFEATED:
		return
	var t := Time.get_ticks_msec() * 0.001
	art.rotation = sin(t * 1.3) * 0.04
	_weather(delta)
	if state != State.DRIFT:
		return
	var player := _player()
	if player:
		var want := clampf(player.global_position.x + 260.0 * signf(global_position.x - player.global_position.x + 0.01), arena_left + 120.0, arena_right - 120.0)
		global_position.x = move_toward(global_position.x, want, 220.0 * delta)
	global_position.y = move_toward(global_position.y, floor_y - HANG, 400.0 * delta)
	_rest_left -= delta
	if _rest_left <= 0.0:
		_next()


func _weather(delta: float) -> void:
	_announce()
	# The rain: it calls it itself.
	if shower:
		_rain_left -= delta
		if _rain_left <= 0.0 and shower.state == &"dry":
			shower.call_rain(pour_time)
			_rain_left = rain_every[phase()] + shower.gather_time + pour_time
	# The wind (phase 3): turns round every `wind_period`, with scraps blowing the
	# new way just before.
	if phase() < 2:
		return
	if wind == 0.0:
		wind = -1.0
		_wind_left = wind_period
		_scraps.emitting = true
	_wind_left -= delta
	if not _wind_warned and _wind_left <= wind_warn:
		_wind_warned = true
		_scraps.direction = Vector2(-wind, -0.05)
		AudioManager.play_sfx(&"swipe", 0.5, -4.0)
	if _wind_left <= 0.0:
		wind = -wind
		_wind_left = wind_period
		_wind_warned = false
	_scraps.direction = Vector2(wind if not _wind_warned else -wind, -0.05)
	var player := _player() as Patch
	if player:
		player.push.x += wind * wind_strength * (0.7 if player.is_on_floor() else 1.0)


func _announce() -> void:
	var p := phase()
	if p <= _phase_told:
		return
	_phase_told = p
	if p == 1:
		DialogueUI.narrate("The needle stuck on STORMY, and the light went white at the edges. Where the bolts would come down, the paper scorched first.")
	elif p == 2:
		DialogueUI.narrate("Then the wind, the whole page of it, and loose sheets went by him flat as gulls. It would turn. It always turned.")


func _next() -> void:
	moves += 1
	var p := phase()
	if p >= 1 and moves % 3 == 2:
		_lightning(bolts[p])
	elif moves % 2 == 0:
		_downburst()
	else:
		_hail()


func _done() -> void:
	if state == State.DEFEATED:
		return
	state = State.DRIFT
	_rest_left = rests[phase()]


# --- Moves --------------------------------------------------------------------------

func _hail() -> void:
	state = State.HAIL
	_kill_tween()
	_tween = create_tween()
	for i in 6:
		_tween.tween_callback(_drop)
		_tween.tween_interval(0.2)
	_tween.tween_interval(0.4)
	_tween.tween_callback(_done)


func _drop() -> void:
	var player := _player()
	var x := clampf((player.global_position.x if player else global_position.x) + randf_range(-300.0, 300.0), arena_left, arena_right)
	var drip := DRIP.instantiate() as Node2D
	drip.set("floor_y", floor_y - 10.0)
	drip.add_to_group(&"forecast_weather")
	get_parent().add_child(drip)
	drip.global_position = Vector2(x, floor_y - 900.0)


## Over Patch, red, then down on the page: spent.
func _downburst() -> void:
	state = State.DOWNBURST
	downbursts += 1
	var player := _player()
	var x := clampf(player.global_position.x if player else global_position.x, arena_left + 120.0, arena_right - 120.0)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "global_position:x", x, 0.35).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		Tells.red_glow(art, downburst_tell)
		AudioManager.play_sfx(&"growl", 0.5, -4.0))
	_tween.tween_interval(downburst_tell)
	_tween.tween_callback(func() -> void: _contact.active = true)
	_tween.tween_property(self, "global_position:y", floor_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_landed)


func _landed() -> void:
	AudioManager.play_sfx(&"slam", 0.5)
	var player := _player()
	if player and player.has_method("_shake_camera"):
		player._shake_camera(14.0)
	get_tree().create_timer(0.12, false, true).timeout.connect(func() -> void: _contact.active = false)
	_spent()


func _spent() -> void:
	state = State.SPENT
	_set_open(true)
	_say("spent", "It came down on the page and lay there a moment, all its sheets slack, and the barometer was right there, in reach, its glass cracked.")
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(spent_time)
	_tween.tween_callback(_recover)


func _recover() -> void:
	if state != State.SPENT:
		return
	_set_open(false)
	BossStagger.close(hold)
	_done()


## White lines scorch on the floor, then the bolts come down them.
func _lightning(count: int) -> void:
	state = State.LIGHTNING
	var player := _player()
	var xs: Array[float] = []
	var px := player.global_position.x if player else (arena_left + arena_right) / 2.0
	xs.append(clampf(px, arena_left, arena_right))
	while xs.size() < count:
		var x := randf_range(arena_left, arena_right)
		if xs.all(func(o: float) -> bool: return absf(o - x) > BOLT_WIDTH * 1.6):
			xs.append(x)
	for x in xs:
		_mark(x)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(bolt_tell)
	_tween.tween_callback(func() -> void:
		for x in xs:
			_bolt(x))
	_tween.tween_interval(0.6)
	_tween.tween_callback(_done)


func _mark(x: float) -> void:
	var mark := Line2D.new()
	mark.add_to_group(&"forecast_weather")
	mark.add_to_group(&"forecast_marks")
	mark.add_to_group(&"vfx")
	mark.top_level = true
	mark.z_index = 6
	mark.width = 8.0
	mark.default_color = Color(1, 1, 1, 0.85)
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(Vector2(-BOLT_WIDTH / 2.0 + i * BOLT_WIDTH / 8.0, randf_range(-6.0, 4.0)))
	mark.points = pts
	add_child(mark)
	mark.global_position = Vector2(x, floor_y - 4.0)
	var t := mark.create_tween().set_loops(int(bolt_tell / 0.16))
	t.tween_property(mark, "modulate:a", 0.3, 0.08)
	t.tween_property(mark, "modulate:a", 1.0, 0.08)
	get_tree().create_timer(bolt_tell, false).timeout.connect(mark.queue_free)
	AudioManager.play_sfx(&"swipe", 1.7, -10.0)


func _bolt(x: float) -> void:
	var bolt := Node2D.new()
	bolt.add_to_group(&"forecast_weather")
	bolt.add_to_group(&"forecast_bolts")
	bolt.top_level = true
	bolt.z_index = 7
	var line := Line2D.new()
	line.width = 14.0
	line.default_color = Color(0.92, 0.95, 1.0)
	var pts := PackedVector2Array()
	var y := -1100.0
	while y < 0.0:
		pts.append(Vector2(randf_range(-34.0, 34.0), y))
		y += 90.0
	pts.append(Vector2.ZERO)
	line.points = pts
	bolt.add_child(line)
	var hit := Hitbox.new()
	hit.collision_layer = 16
	hit.collision_mask = 0
	hit.damage = 2
	hit.knockback = 480.0
	hit.unblockable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BOLT_WIDTH, 1100)
	shape.shape = rect
	shape.position = Vector2(0, -550)
	hit.add_child(shape)
	bolt.add_child(hit)
	add_child(bolt)
	hit.owner = self
	hit.active = true
	bolt.global_position = Vector2(x, floor_y)
	AudioManager.play_sfx(&"slam", 1.4, -2.0)
	var t := bolt.create_tween()
	t.tween_interval(0.18)
	t.tween_callback(func() -> void: hit.active = false)
	t.tween_property(bolt, "modulate:a", 0.0, 0.25)
	t.tween_callback(bolt.queue_free)


# --- Being cut ----------------------------------------------------------------------

func _on_hit(hitbox: Hitbox) -> void:
	if state == State.DEFEATED:
		return
	if not _open:
		if not health.is_invulnerable():
			AudioManager.play_sfx(&"parry", 1.5, -8.0)
			health.grant_invulnerability(0.25)
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"hit_wet", 1.1)
		art.modulate = Color(1.8, 1.7, 1.6)
		create_tween().tween_property(art, "modulate", Color.WHITE, 0.2)


func can_stagger() -> bool:
	return state == State.SPENT


func is_open() -> bool:
	return _open


func finisher_point() -> Vector2:
	return global_position + Vector2(-60, -200)


func _on_hold_broken() -> void:
	_kill_tween()
	get_tree().create_timer(hold.stagger_time, false).timeout.connect(_recover)


func unstitch(_by: Node) -> void:
	if not can_stagger():
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	if BossStagger.unstitch(self, health, hold):
		DialogueUI.narrate("Patch cut the barometer's chain. It swung, and for a moment the needle stood still, and so did the weather.")
		get_tree().create_timer(0.6, false).timeout.connect(_recover)


func _on_defeated() -> void:
	if Rematch.intercept(self):
		return
	state = State.DEFEATED
	_kill_tween()
	_set_open(false)
	_contact.active = false
	wind = 0.0
	_scraps.emitting = false
	Bestiary.record(self)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	for node in get_tree().get_nodes_in_group(&"forecast_weather"):
		node.queue_free()
	# The pages come apart and settle on the page, blank side up, like snow.
	var t := create_tween().set_parallel()
	t.tween_property(self, "global_position:y", floor_y, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "scale", Vector2(art_scale * 1.2, art_scale * 0.25), 1.8)
	t.tween_property(art, "modulate", Color(0.9, 0.9, 0.92, 0.0), 2.4)
	await t.finished
	DialogueUI.narrate("The barometer dropped onto the paper and lay there, face up, the needle on CHANGE. The rain stopped. Somewhere under the last of the sheets, something red: a heart patch, sewn on a scrap of Gran's apron, that the weather had been keeping.")
	if reward:
		reward.visible = true
		reward.set_deferred("monitoring", true)
	_show_exit()
	GameState.save_game()


func _show_exit() -> void:
	if exit_door:
		exit_door.visible = true
		exit_door.set_deferred("monitorable", true)


func _set_open(open: bool) -> void:
	_open = open
	art.self_modulate = Color(1.05, 1.05, 1.1) if open else Color(0.78, 0.8, 0.86)


func _say(key: String, line: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	DialogueUI.narrate(line)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
