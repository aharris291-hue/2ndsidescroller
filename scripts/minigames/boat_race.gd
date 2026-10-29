class_name BoatRace
extends Node2D
## The Ribbon Regatta: a paper-boat race down the ribbon stream (Chapter 1 minigame).
##
## The stream scrolls by on its own; steer the boat up and down (a little forward and
## back too) to dodge rocks and scoop up Scraps. Reach the finish with no more than
## `max_bumps` bumps to win the regatta. The course is generated from `course_seed`,
## so it's the same every attempt.

@export_file("*.tscn") var return_page := ""
@export var return_spawn: StringName = &"FromRace"
@export var quest_id := "ribbon_regatta"
@export var course_length := 11000.0
@export var start_speed := 420.0
@export var end_speed := 560.0
@export var max_bumps := 3
@export var course_seed := 7
@export var river_top := 340.0
@export var river_bottom := 800.0
@export var music: AudioStream

const ROCK_TEXTURE := preload("res://assets/art/props/stream_rock.png")
const SCRAP_TEXTURE := preload("res://assets/art/props/scrap.png")
const STEER_SPEED := 520.0
const ROCK_RADIUS := 44.0
const BOAT_RADIUS := 40.0

var _distance := 0.0
var _bumps := 0
var _scraps := 0
var _slow_left := 0.0
var _boat_offset := Vector2(520, 560)
var _running := false
var _finished := false
var _rocks: Array[Sprite2D] = []
var _pickups: Array[Sprite2D] = []

@onready var camera: Camera2D = $Camera2D
@onready var boat: Node2D = $Boat
@onready var course: Node2D = $Course
@onready var status_label: Label = $UI/Status
@onready var big_label: Label = $UI/BigLabel


func _ready() -> void:
	GameState.in_gameplay = true
	HUD.show_hud(false)
	if music:
		AudioManager.play_music(music)
	_build_course()
	_update_status()
	camera.position = Vector2(960, 540)
	boat.position = _boat_offset
	await _countdown()
	_running = true


func _build_course() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = course_seed
	var x := 1800.0
	while x < course_length - 600.0:
		var rock := Sprite2D.new()
		rock.texture = ROCK_TEXTURE
		rock.position = Vector2(x, rng.randf_range(river_top + 20.0, river_bottom - 20.0))
		course.add_child(rock)
		_rocks.append(rock)
		# A little arc of Scraps between rocks, away from the rock's lane.
		if rng.randf() < 0.6:
			var lane := river_top + 60.0 if rock.position.y > (river_top + river_bottom) / 2.0 else river_bottom - 60.0
			for i in 3:
				var scrap := Sprite2D.new()
				scrap.texture = SCRAP_TEXTURE
				scrap.position = Vector2(x + 140.0 + i * 70.0, lane + sin(i * 1.2) * 30.0)
				course.add_child(scrap)
				_pickups.append(scrap)
		x += rng.randf_range(260.0, 430.0) * lerpf(1.2, 0.8, x / course_length)
	var finish := Line2D.new()
	finish.points = PackedVector2Array([Vector2(course_length, river_top - 80.0), Vector2(course_length, river_bottom + 80.0)])
	finish.width = 18.0
	finish.default_color = Color("de583d")
	course.add_child(finish)


func _countdown() -> void:
	for word in ["3", "2", "1", "Sail!"]:
		big_label.text = word
		AudioManager.play_sfx(&"voice_blip", 1.6 if word == "Sail!" else 1.0)
		await get_tree().create_timer(0.7).timeout
	big_label.text = ""


func _physics_process(delta: float) -> void:
	if not _running:
		return
	var speed := lerpf(start_speed, end_speed, _distance / course_length)
	if _slow_left > 0.0:
		_slow_left -= delta
		speed *= 0.55
	_distance += speed * delta
	camera.position.x = 960.0 + _distance

	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_boat_offset.y = clampf(_boat_offset.y + input.y * STEER_SPEED * delta, river_top, river_bottom)
	_boat_offset.x = clampf(_boat_offset.x + input.x * STEER_SPEED * 0.5 * delta, 260.0, 900.0)
	boat.position = Vector2(_distance + _boat_offset.x, _boat_offset.y)
	boat.rotation = lerpf(boat.rotation, input.y * 0.18, 8.0 * delta)
	boat.get_node("Sprite2D").position.y = sin(Time.get_ticks_msec() * 0.006) * 4.0

	_check_hits()
	if boat.position.x >= course_length:
		_finish()


func _check_hits() -> void:
	for rock in _rocks:
		if rock.visible and rock.position.distance_to(boat.position) < ROCK_RADIUS + BOAT_RADIUS:
			rock.visible = false
			_bumps += 1
			_slow_left = 0.8
			AudioManager.play_sfx(&"hurt", 1.2)
			var tween := create_tween()
			boat.modulate = Color(1, 0.6, 0.6)
			tween.tween_property(boat, "modulate", Color.WHITE, 0.4)
			_update_status()
	for scrap in _pickups:
		if scrap.visible and scrap.position.distance_to(boat.position) < 30.0 + BOAT_RADIUS:
			scrap.visible = false
			_scraps += 1
			AudioManager.play_sfx(&"pickup", randf_range(0.95, 1.1))
			_update_status()


func _update_status() -> void:
	status_label.text = "Bumps %d/%d     Scraps %d" % [_bumps, max_bumps, _scraps]


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_running = false
	GameState.add_scraps(_scraps)
	var won := _bumps <= max_bumps
	if won:
		big_label.text = "You won the Ribbon Regatta!"
		AudioManager.play_sfx(&"checkpoint")
		GameState.advance_quest(quest_id)
		GameState.complete_quest(quest_id)
	else:
		big_label.text = "Too many bumps! Have another go from the dock."
	await get_tree().create_timer(2.5).timeout
	SceneManager.change_page(return_page, return_spawn)


## True once the race is over (used by the smoke test).
func is_finished() -> bool:
	return _finished
