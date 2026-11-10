class_name RainShower
extends Node2D
## The weather over the Blank Margins: showers that come and go. A page has one. While
## it pours, the rain writes ledges onto the blank paper (RainPlatform) and they hold;
## when it eases off, they fade back into nothing.
##
## Its cycle: `dry_time` of nothing but drizzle, then `gather_time` as the rain thickens
## and the ledges show their outlines (the tell), then `pour_time` of downpour. The last
## `EASE` seconds of the downpour the ledges flicker: it's about to stop.
## With `manual` set it doesn't cycle by itself (the Unwritten Forecast calls the rain).

signal changed(state: StringName)

const RAIN_SOUND := preload("res://assets/audio/dark/amb_rain.ogg")
const EASE := 0.7

@export var dry_time := 2.6
@export var gather_time := 0.9
@export var pour_time := 3.6
## Where in its cycle it starts, in seconds.
@export var phase := 0.0
@export var manual := false

## &"dry", &"gathering" or &"pouring".
var state: StringName = &"dry"
## The downpour is about to stop (ledges flicker).
var easing := false
var _t := 0.0
var _left := 0.0
var _rain: CPUParticles2D
var _dim: ColorRect
var _sound: AudioStreamPlayer


func _ready() -> void:
	add_to_group(&"rain_showers")
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.06, 0.1, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_dim)
	_rain = CPUParticles2D.new()
	var streak := GradientTexture2D.new()
	streak.width = 2
	streak.height = 48
	streak.fill_from = Vector2(0, 0)
	streak.fill_to = Vector2(0, 1)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	streak.gradient = g
	_rain.texture = streak
	_rain.amount = 700
	_rain.lifetime = 0.6
	_rain.position = Vector2(1060, -60)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(1300, 10)
	_rain.direction = Vector2(-0.3, 1.0)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 1900.0
	_rain.initial_velocity_max = 2300.0
	_rain.particle_flag_align_y = true
	_rain.color = Color(0.8, 0.84, 0.95, 0.4)
	_rain.emitting = false
	layer.add_child(_rain)
	_sound = AudioStreamPlayer.new()
	_sound.stream = RAIN_SOUND
	_sound.bus = &"SFX"
	_sound.volume_db = -40.0
	add_child(_sound)
	_t = phase
	if not manual:
		_set_state(_state_at(_t))


func _physics_process(delta: float) -> void:
	if manual:
		if state != &"dry":
			_left -= delta
			if state == &"gathering" and _left <= 0.0:
				_left = pour_time
				_set_state(&"pouring")
			elif state == &"pouring":
				easing = _left <= EASE
				if _left <= 0.0:
					_set_state(&"dry")
		return
	_t = fmod(_t + delta, dry_time + gather_time + pour_time)
	var now := _state_at(_t)
	easing = now == &"pouring" and _t > dry_time + gather_time + pour_time - EASE
	if now != state:
		_set_state(now)


func _state_at(t: float) -> StringName:
	if t < dry_time:
		return &"dry"
	if t < dry_time + gather_time:
		return &"gathering"
	return &"pouring"


func is_pouring() -> bool:
	return state == &"pouring"


## For a manual shower: gather, then pour for `seconds`.
func call_rain(seconds := -1.0) -> void:
	if seconds > 0.0:
		pour_time = seconds
	_left = gather_time
	_set_state(&"gathering")


func _set_state(new_state: StringName) -> void:
	state = new_state
	if state != &"pouring":
		easing = false
	_rain.emitting = state != &"dry"
	_rain.speed_scale = 1.0 if state == &"pouring" else 0.45
	_rain.color.a = 0.4 if state == &"pouring" else 0.14
	var t := create_tween().set_parallel()
	t.tween_property(_dim, "color:a", 0.2 if state == &"pouring" else (0.08 if state == &"gathering" else 0.0), 0.4)
	if state == &"dry":
		t.tween_property(_sound, "volume_db", -40.0, 0.8)
		t.chain().tween_callback(_sound.stop)
	else:
		if not _sound.playing:
			_sound.play()
		t.tween_property(_sound, "volume_db", -4.0 if state == &"pouring" else -16.0, 0.5)
	changed.emit(state)
