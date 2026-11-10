class_name ShadowTheater
extends Node2D
## The Lanternfold shadow-puppet show (Chapter 2 minigame): a rhythm game.
##
## Shadow-puppet arrows glide across the lit screen toward the fox puppet. Press the
## matching direction as each one reaches the ring. Hit at least `win_ratio` of them to
## win the show (the "shadow_show" quest). The chart comes from `chart_seed`, so every
## performance is the same.

const LANES: Array[StringName] = [&"move_up", &"move_left", &"move_right", &"move_down"]
const LANE_ANGLES := [-PI / 2.0, PI, 0.0, PI / 2.0]
const FOX_TEXTURE := preload("res://assets/art/dark/patch.png")
const SHADOW := Color(0.16, 0.1, 0.14)
## The screen is old stained cloth lit by one candle behind it: dim amber, hot in the
## middle, falling to brown at the edges.
const LIT := Color(0.34, 0.25, 0.16)
const HOTSPOT := Color(0.8, 0.56, 0.3)
const SCREEN := Rect2(470, 170, 980, 550)

@export_file("*.tscn") var return_page := ""
@export var return_spawn: StringName = &"FromTheater"
@export var quest_id := "shadow_show"
@export var bpm := 112.0
@export var beats := 48
@export var chart_seed := 11
@export var win_ratio := 0.7
## Seconds an arrow takes to cross the screen to the ring.
@export var travel_time := 1.8
## How far from the beat (seconds) still counts as a hit.
@export var hit_window := 0.16
@export var music: AudioStream
## Hits every note by itself (for the smoke test).
@export var autoplay := false

var _notes: Array[Dictionary] = []
var _time := -2.0
var _hits := 0
var _misses := 0
var _streak := 0
var _running := false
var _finished := false
var _flash := 0.0
var _last_word := ""
var _word_left := 0.0
var _fox_pose := 0.0
## The arcade game being played ("" outside the arcade).
var _arcade_id := ""

@onready var status_label: Label = $UI/Status
@onready var big_label: Label = $UI/BigLabel

const HIT_X := 620.0
const SPAWN_X := 1420.0
const LANE_Y := 440.0


func _ready() -> void:
	GameState.in_gameplay = true
	_arcade_id = Arcade.take(self)
	HUD.show_hud(false)
	if music:
		AudioManager.play_music(music)
	_build_chart()
	_update_status()
	await _countdown()
	_running = true


func _build_chart() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = chart_seed
	var beat := 60.0 / bpm
	var b := 0
	while b < beats:
		var lane := rng.randi_range(0, 3)
		_notes.append({"time": b * beat, "lane": lane, "done": false})
		# Mostly on the beat, with the odd quick pair later in the show.
		if b > beats / 2 and rng.randf() < 0.3:
			_notes.append({"time": (b + 0.5) * beat, "lane": (lane + rng.randi_range(1, 3)) % 4, "done": false})
		b += 1 if rng.randf() < 0.7 else 2


func _countdown() -> void:
	for word in ["3", "2", "1", "Curtain."]:
		big_label.text = word
		AudioManager.play_sfx(&"voice_blip", 1.6 if word == "Curtain." else 1.0)
		await get_tree().create_timer(0.6).timeout
	big_label.text = ""


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_word_left = maxf(_word_left - delta, 0.0)
	_fox_pose = move_toward(_fox_pose, 0.0, delta * 3.0)
	if _running:
		_time += delta
		_update_notes()
	queue_redraw()


func _update_notes() -> void:
	for note in _notes:
		if note.done:
			continue
		var offset: float = _time - note.time
		if autoplay and offset >= 0.0:
			_judge(note, true)
		elif offset > hit_window:
			_judge(note, false)
	for i in LANES.size():
		if Input.is_action_just_pressed(LANES[i]):
			_press(i)
	if _notes.all(func(n: Dictionary) -> bool: return n.done):
		_finish()


func _press(lane: int) -> void:
	var best: Dictionary = {}
	var best_offset := INF
	for note in _notes:
		if note.done or note.lane != lane:
			continue
		var offset := absf(_time - float(note.time))
		if offset < best_offset:
			best_offset = offset
			best = note
	if not best.is_empty() and best_offset <= hit_window:
		_judge(best, true)


func _judge(note: Dictionary, hit: bool) -> void:
	note.done = true
	if hit:
		_hits += 1
		_streak += 1
		_flash = 1.0
		_fox_pose = 1.0
		_say("Clean." if _streak % 8 == 0 else "")
		AudioManager.play_sfx(&"voice_blip", [1.0, 1.26, 1.5, 0.84][note.lane], -2.0)
	else:
		_misses += 1
		_streak = 0
		_say("Missed!")
	_update_status()


func _say(word: String) -> void:
	if word.is_empty():
		return
	_last_word = word
	_word_left = 0.6


func _update_status() -> void:
	status_label.text = "Hits %d   Misses %d   Streak %d" % [_hits, _misses, _streak]


func _draw() -> void:
	# The lit screen with the hit ring and the shadow-fox puppet.
	draw_rect(SCREEN, LIT.lerp(HOTSPOT, _flash * 0.5))
	# The candle's hotspot, soft-edged, in the middle of the screen.
	for i in 10:
		var r := 420.0 - i * 36.0
		draw_set_transform(SCREEN.get_center(), 0.0, Vector2(1.0, 0.62))
		draw_circle(Vector2.ZERO, r, Color(HOTSPOT, 0.06))
	draw_set_transform(Vector2.ZERO)
	# Dark, water-stained edges.
	for i in 6:
		var inset := i * 14.0
		draw_rect(SCREEN.grow(-inset), Color(0.06, 0.04, 0.03, 0.22), false, 16.0)
	draw_arc(Vector2(HIT_X, LANE_Y), 64.0, 0.0, TAU, 48, SHADOW, 6.0, true)
	# The painted Patch, 360 px tall, drawn as a shadow about as tall as the old puppet.
	var fox_scale := Vector2(0.7, 0.7 - _fox_pose * 0.11)
	draw_set_transform(Vector2(HIT_X - 120, LANE_Y + 150 - _fox_pose * 40.0), 0.0, fox_scale)
	# Black modulate turns the paper fox into a true shadow puppet.
	var size := FOX_TEXTURE.get_size()
	draw_texture_rect(FOX_TEXTURE, Rect2(-size / 2.0, size), false, Color(0, 0, 0, 0.92))
	draw_set_transform(Vector2.ZERO)
	for note in _notes:
		if note.done:
			continue
		var t: float = (float(note.time) - _time) / travel_time
		if t > 1.0 or t < -0.2:
			continue
		var x := lerpf(HIT_X, SPAWN_X, t)
		_draw_arrow(Vector2(x, LANE_Y), LANE_ANGLES[note.lane])
	if _word_left > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(HIT_X - 60, LANE_Y - 110), _last_word, HORIZONTAL_ALIGNMENT_CENTER, 160, 40, SHADOW)


func _draw_arrow(center: Vector2, angle: float) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(46, 0), Vector2(0, -40), Vector2(0, -16), Vector2(-44, -16), Vector2(-44, 16), Vector2(0, 16), Vector2(0, 40)]:
		points.append(center + (p as Vector2).rotated(angle))
	draw_colored_polygon(points, SHADOW)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_running = false
	var total := _hits + _misses
	var won := total > 0 and float(_hits) / total >= win_ratio
	if not _arcade_id.is_empty():
		var percent := roundi(score() * 100.0)
		var rank := arcade_rank(percent)
		var paid := Arcade.record(_arcade_id, percent, rank, 2)
		big_label.text = "%d%% of the shadows caught. %s.%s" % [percent, Arcade.RANKS[rank],
			"\n%d scraps for a new best." % paid if paid > 0 else ""]
		AudioManager.play_sfx(&"checkpoint" if won else &"hurt", 1.0)
		await get_tree().create_timer(3.0).timeout
		Arcade.back_to_theatre()
		return
	GameState.add_scraps(_hits / 4)
	if won:
		big_label.text = "The candle steadies. Somewhere in the dark, a few hands clap."
		AudioManager.play_sfx(&"checkpoint")
		GameState.advance_quest(quest_id)
		GameState.complete_quest(quest_id)
	else:
		big_label.text = "The candle gutters. The house is quiet. Again?"
	await get_tree().create_timer(2.5).timeout
	SceneManager.change_page(return_page, return_spawn)


## Arcade rank (1 Paper .. 4 Gilt) for the share of shadows caught.
static func arcade_rank(percent: int) -> int:
	if percent >= 95:
		return 4
	if percent >= 85:
		return 3
	if percent >= 70:
		return 2
	return 1


## True once the show is over (used by the smoke test).
func is_finished() -> bool:
	return _finished


## Fraction of notes hit so far.
func score() -> float:
	var total := _hits + _misses
	return float(_hits) / total if total > 0 else 0.0
