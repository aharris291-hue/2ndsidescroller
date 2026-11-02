class_name DarkAtmosphere
extends Node
## The Dark Rebuild's weather and light for a page: the world dimmed to a cold blue,
## a lantern glow that follows Patch, slanting rain, drifting fog, a vignette, film
## grain, rain on the soundtrack and the odd flash of lightning.
## Add one to a page (as a child) and it sets itself up.

const FOG_SHADER := preload("res://resources/shaders/dark_fog.gdshader")
const RAIN_SOUND := preload("res://assets/audio/dark/amb_rain.ogg")

@export var ambient := Color(0.6, 0.65, 0.78)
@export var rain_amount := 420
@export var lightning := true

var _modulate: CanvasModulate
var _rain: CPUParticles2D
var _fog: ShaderMaterial
var _flash_left := 0.0
var _next_flash := 9.0


func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = ambient
	get_parent().add_child.call_deferred(_modulate)
	_add_rain()
	_add_overlay()
	_add_rain_sound()
	_attach_lantern.call_deferred()
	Settings.changed.connect(_apply_settings)
	_apply_settings()


## Follows the pause menu: weather detail (fog layers, grain, rain density) and
## whether lightning may flash.
func _apply_settings() -> void:
	if _fog:
		_fog.set_shader_parameter(&"octaves", 5 if Settings.high_effects else 2)
		_fog.set_shader_parameter(&"grain_amount", 0.05 if Settings.high_effects else 0.0)
	if _rain:
		_rain.amount = rain_amount if Settings.high_effects else maxi(int(rain_amount / 3.0), 1)
	if not Settings.flashing and _flash_left > 0.0:
		_flash_left = 0.0


func _process(delta: float) -> void:
	if _modulate == null:
		return
	_next_flash -= delta if lightning and Settings.flashing else 0.0
	if _next_flash <= 0.0:
		_next_flash = randf_range(10.0, 22.0)
		_flash_left = 0.35
	if _flash_left > 0.0:
		_flash_left -= delta
		# Two quick flickers, then back to the dark.
		var k := 1.0 if fmod(_flash_left, 0.16) > 0.08 else 0.35
		_modulate.color = ambient.lerp(Color(1.25, 1.3, 1.45), k * clampf(_flash_left / 0.35, 0.0, 1.0))
	else:
		_modulate.color = ambient


func _attach_lantern() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or player.has_node(^"Lantern"):
		return
	var light := PointLight2D.new()
	light.name = &"Lantern"
	light.texture = _radial_texture()
	light.texture_scale = 3.2
	light.color = Color(1.0, 0.78, 0.5)
	light.energy = 0.85
	light.position = Vector2(0, -40)
	player.add_child(light)


static func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


func _add_rain() -> void:
	if rain_amount <= 0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var streak := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	streak.gradient = g
	streak.fill_from = Vector2(0.5, 0.0)
	streak.fill_to = Vector2(0.5, 1.0)
	streak.width = 2
	streak.height = 46
	var rain := CPUParticles2D.new()
	_rain = rain
	rain.texture = streak
	rain.amount = rain_amount
	rain.lifetime = 0.75
	rain.preprocess = 1.0
	rain.position = Vector2(1060, -60)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(1300, 10)
	rain.direction = Vector2(-0.22, 1.0)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 1500.0
	rain.initial_velocity_max = 1900.0
	rain.particle_flag_align_y = true
	rain.scale_amount_min = 0.7
	rain.scale_amount_max = 1.3
	rain.color = Color(0.75, 0.8, 0.9, 0.28)
	layer.add_child(rain)


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	rect.material = material
	_fog = material
	layer.add_child(rect)


func _add_rain_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = RAIN_SOUND
	player.bus = &"SFX"
	player.volume_db = -8.0
	player.finished.connect(player.play)
	add_child(player)
	player.play()
