class_name BeamWick
extends StaticBody2D
## A great oil wick in a brass dish (2-3, the Lamp Room, seen from above). It burns
## while the lamp's beam runs through it; the beam carries on past. The page lights
## every wick in a room at once to open that room's grille (see LampRoom).

const COLD := preload("res://assets/art/dark/props/wick_cold.png")
const LIT := preload("res://assets/art/dark/props/wick_lit.png")

var lit := false
var _sprite: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	add_to_group(&"beam_wicks")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = COLD
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = DarkAtmosphere._radial_texture()
	_light.texture_scale = 2.2
	_light.color = Color(1.0, 0.68, 0.36)
	_light.energy = 0.0
	add_child(_light)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_sprite.texture = LIT if on else COLD
	_light.energy = 1.4 if on else 0.0
	if on:
		AudioManager.play_sfx(&"pickup", 0.55, -6.0)
