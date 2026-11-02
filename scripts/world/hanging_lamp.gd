class_name HangingLamp
extends Node2D
## A small oil lamp on a chain, with its own warm light. Pages can `snuff` it.

const LAMP := preload("res://assets/art/dark/props/hanging_lamp.png")

@export var energy := 1.6
@export var radius := 3.6
## Starts out (already snuffed), e.g. after the lights went out on an earlier visit.
@export var out_flag := ""

var _light: PointLight2D
var _sprite: Sprite2D
var _time := randf() * TAU


func _ready() -> void:
	add_to_group(&"lamps")
	_sprite = Sprite2D.new()
	_sprite.texture = LAMP
	_sprite.offset = Vector2(0, 75)
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = DarkAtmosphere._radial_texture()
	_light.texture_scale = radius
	_light.color = Color(1.0, 0.72, 0.42)
	_light.energy = energy
	_light.position = Vector2(0, 120)
	add_child(_light)
	if not out_flag.is_empty() and GameState.get_flag(out_flag):
		_light.energy = 0.0
		_sprite.modulate = Color(0.45, 0.45, 0.5)


func _process(delta: float) -> void:
	_time += delta
	rotation = sin(_time * 0.9) * 0.03
	if _light.energy > 0.0 and _light.energy <= energy:
		_light.energy = energy * (0.92 + 0.08 * sin(_time * 11.0) * sin(_time * 3.7))


func snuff() -> void:
	set_process(false)
	AudioManager.play_sfx(&"page_flip", 1.6, -8.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_light, "energy", 0.0, 0.25)
	tween.tween_property(_sprite, "modulate", Color(0.45, 0.45, 0.5), 0.25)
