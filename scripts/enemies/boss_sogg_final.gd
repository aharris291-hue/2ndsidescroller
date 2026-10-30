class_name BossSoggFinal
extends BossSogg
## The Sogg's last stand, at the bottom of the Gutter (the finale). The fight is played
## twice, either side of Interlude 4:
##
## 1. Alone (dryer_flag not set yet). Patch can't win this one. Down here the fold
##    marks are too soggy to hold the Sogg, its chest stays shut, and the rain only gets
##    heavier. When Patch is down to his last scrap of paper, or has held out for
##    hold_out_time, it closes over him, and the story cuts to Gran's table (lose_page).
## 2. With Nell (flag set). The hairdryer reaches into the book from the Margin and its
##    warm air follows Patch around (see HairdryerBeam). Whenever the Sogg comes down
##    inside the warm air (a dive, or pinned on a peak) it dries out, one section at a
##    time. Swiping Drizzle while it's pinned helps. Dried out, it isn't destroyed: it
##    shrinks back into Drizzle.

const DRIZZLE_TEXTURE := preload("res://assets/art/characters/drizzle.png")

@export var dryer_flag := "nell_has_dryer"
@export var beam: HairdryerBeam
@export var warm_music: AudioStream
## How much water there is to dry out (the boss bar).
@export var wetness := 16
## Wetness the warm air takes out per second while it's on the Sogg.
@export var dry_rate := 1.7
## How close (horizontally) the warm air must be to the Sogg's middle to reach it.
@export var dry_reach := 180.0
## Said as each quarter of the Sogg dries away.
@export var section_lines: Array[String] = []
@export var hold_out_time := 22.0
@export var lose_dialogue := "gutter_losing"
## The real-world scene the first attempt cuts to.
@export_file("*.tscn") var lose_page := ""
## The conversation that brings the hairdryer in, on the second attempt.
@export var warm_dialogue := "warm_air_arrives"

var _drying := false
var _hold_left := 0.0
var _dry_accum := 0.0
var _sections_left := 4
var _lost := false
var _buckle_cooldown := 0.0
var _steam: CPUParticles2D


func _ready() -> void:
	health.max_health = wetness
	health.set_health(wetness)
	_drying = GameState.get_flag(dryer_flag)
	super._ready()
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_steam = CPUParticles2D.new()
	_steam.position = Vector2(0, -200)
	_steam.amount = 28
	_steam.lifetime = 0.9
	_steam.emitting = false
	_steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = 150.0
	_steam.direction = Vector2.UP
	_steam.spread = 25.0
	_steam.gravity = Vector2(0, -220)
	_steam.initial_velocity_min = 60.0
	_steam.initial_velocity_max = 140.0
	# Soft round puffs of steam.
	var puff := GradientTexture2D.new()
	puff.width = 48
	puff.height = 48
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.gradient = Gradient.new()
	puff.gradient.set_color(0, Color.WHITE)
	puff.gradient.set_color(1, Color(1, 1, 1, 0))
	_steam.texture = puff
	_steam.scale_amount_min = 0.8
	_steam.scale_amount_max = 1.8
	_steam.color = Color(1.0, 0.97, 0.92, 0.55)
	add_child(_steam)
	if _drying:
		# Second time round: no waiting about. The warm air arrives at once.
		_begin_warm.call_deferred()


func _begin_warm() -> void:
	if not warm_dialogue.is_empty():
		DialogueUI.start(warm_dialogue)
		await EventBus.dialogue_finished
	start_fight()


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.DRIFT
	_dive_left = 2.2
	EventBus.boss_started.emit(boss_name, health.max_health)
	var player := _player()
	if _drying:
		if beam:
			beam.switch_on()
		if warm_music:
			AudioManager.play_music(warm_music)
		DialogueUI.narrate("Nell's warm air follows Patch. Lead it to the Sogg whenever it comes down, and stay just out of its reach!")
	else:
		_hold_left = hold_out_time
		if player:
			# This fight ends in a cutscene, not a game over.
			player.health.floor_health = 1
		DialogueUI.narrate("Down here the Sogg was bigger than ever, and the page was too wet to fold.")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_buckle_cooldown = maxf(_buckle_cooldown - delta, 0.0)
	if state == State.WAITING or state == State.DEFEATED:
		if _steam:
			_steam.emitting = false
		return
	if not _drying:
		_hold_left -= delta
		var player := _player()
		if _hold_left <= 0.0 or (player and player.health.current <= 1):
			_lose()
		return
	var low := state == State.SOAK or state == State.STUNNED or state == State.DIVE
	var warmed := low and beam != null and beam.covers(global_position.x, dry_reach)
	_steam.emitting = warmed
	if warmed:
		body.self_modulate = body.self_modulate.lerp(Color(1.3, 1.1, 0.95), 6.0 * delta)
		_dry_accum += dry_rate * delta
		if _dry_accum >= 1.0 and health.take_damage(1, global_position):
			_dry_accum -= 1.0
			EventBus.boss_health_changed.emit(health.current, health.max_health)
			_check_sections()
	elif state != State.STUNNED:
		body.self_modulate = body.self_modulate.lerp(Color.WHITE, 4.0 * delta)


func _on_peak_popped(mark: FoldMark) -> void:
	if _drying:
		super._on_peak_popped(mark)
		return
	if (state == State.SOAK or state == State.DIVE) and absf(mark.global_position.x - global_position.x) <= catch_range \
			and _buckle_cooldown <= 0.0:
		_buckle_cooldown = 4.0
		DialogueUI.narrate("The peak buckled against the Sogg like wet cardboard. Down here, nothing would stand up.")


func _on_heart_hit(hitbox: Hitbox) -> void:
	super._on_heart_hit(hitbox)
	_check_sections()


## Every quarter of its water gone, a piece of the Sogg dries up and shrinks away.
func _check_sections() -> void:
	if health.is_dead():
		return
	var quarter := float(health.max_health) / 4.0
	var expected := ceili(health.current / quarter)
	while _sections_left > expected:
		_sections_left -= 1
		var index := 3 - _sections_left
		if index >= 0 and index < section_lines.size():
			DialogueUI.narrate(section_lines[index])
		AudioManager.play_sfx(&"enemy_pop", 0.6)
		var tween := create_tween()
		tween.tween_property(body, "scale", body.scale * 0.86, 0.5).set_trans(Tween.TRANS_BACK)
		# Wrung out, a bit of its water splashes off as a Soggy.
		var soggy := SOGGY_SCENE.instantiate() as Node2D
		soggy.position = Vector2(clampf(global_position.x + randf_range(-300.0, 300.0), arena_left + 100.0, arena_right - 100.0), floor_y - 300.0)
		get_parent().add_child.call_deferred(soggy)


func _recover() -> void:
	if state == State.DEFEATED:
		return
	_set_heart_exposed(false)
	body.rotation = 0.0
	create_tween().tween_property(body, "self_modulate", Color.WHITE, 0.5)
	_rise()


func _lose() -> void:
	if _lost:
		return
	_lost = true
	state = State.DEFEATED
	contact.active = false
	_clear_shadow()
	var player := _player()
	if player:
		player.input_enabled = false
		player.velocity = Vector2.ZERO
		var grab := create_tween().set_parallel()
		grab.tween_property(self, "global_position", player.global_position + Vector2(0, 140), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		grab.tween_property(body, "scale", body.scale * 1.3, 0.6)
		await grab.finished
		AudioManager.play_sfx(&"slam", 0.45)
		player._shake_camera(20.0)
	if not lose_dialogue.is_empty():
		DialogueUI.start(lose_dialogue)
		await EventBus.dialogue_finished
	if player and is_instance_valid(player):
		player.health.floor_health = 0
	# Whatever happens at the table, Patch comes back to this fight mended.
	GameState.health = GameState.max_health
	if not lose_page.is_empty():
		SceneManager.change_page(lose_page)


func _on_defeated() -> void:
	state = State.DEFEATED
	_set_heart_exposed(false)
	contact.active = false
	_clear_shadow()
	if _steam:
		_steam.emitting = true
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	var player := _player()
	if player:
		player.input_enabled = false
	# It isn't destroyed. It shrinks, and shrinks, back into what it was.
	var center := Vector2(clampf(global_position.x, arena_left + 200.0, arena_right - 200.0), floor_y - 120.0)
	var shrink := create_tween().set_parallel()
	shrink.tween_property(self, "global_position", center, 1.2).set_trans(Tween.TRANS_SINE)
	shrink.tween_property(body, "scale", body.scale * 0.2, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	shrink.tween_property(body, "self_modulate", Color(1.4, 1.4, 1.4), 1.6)
	await shrink.finished
	body.texture = DRIZZLE_TEXTURE
	body.position = Vector2(0, -60)
	body.scale = Vector2(0.1, 0.1)
	body.self_modulate = Color.WHITE
	AudioManager.play_sfx(&"pickup", 0.8)
	var pop := create_tween()
	pop.tween_property(body, "scale", Vector2(0.5, 0.5), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	if _steam:
		_steam.emitting = false
	if beam:
		beam.create_tween().tween_property(beam, "modulate:a", 0.0, 1.5)
	if not defeat_dialogue.is_empty():
		DialogueUI.start(defeat_dialogue)
		await EventBus.dialogue_finished
	GameState.health = GameState.max_health
	GameState.save_game()
	if not next_page.is_empty():
		SceneManager.change_page(next_page)
	else:
		_show_exit()
