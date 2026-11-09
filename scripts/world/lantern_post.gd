class_name LanternPost
extends Interactable
## A harbour lantern on its post (Region 2, Lanternfold). While it burns, Soggies will
## not come into its light: they stop at the edge and turn back, and one caught in it
## when it is lit flees. Lanterns with `gutter_after` burn out a while after Patch has
## left their light, so the dark closes in behind him. Once Patch carries the hand
## lantern ("hand_lantern" flag) he can light any cold post.
##
## Stands on its origin like the other text-map entities.

const ON := preload("res://assets/art/dark/props/lantern_on.png")
const OFF := preload("res://assets/art/dark/props/lantern_off.png")
const HAND_LANTERN_FLAG := "hand_lantern"

## Burning when the page opens.
@export var lit := true
## How far its light reaches either side of the post, in px. It reaches this far up,
## and a little below the post's foot.
@export var radius := 288.0
## Seconds after Patch leaves its light before it gutters out (0 = burns for good).
@export var gutter_after := 0.0

var _sprite: Sprite2D
var _light: PointLight2D
var _dark_for := 0.0
var _time := randf() * TAU


func _ready() -> void:
	add_to_group(&"light_zones")
	prompt_text = "Light the lantern"
	prompt_offset = Vector2(0, -230)
	collision_layer = 32
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(140, 180)
	shape.shape = rect
	shape.position = Vector2(0, -90)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -90)
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = DarkAtmosphere._radial_texture()
	_light.texture_scale = radius / 128.0 * 1.4
	_light.color = Color(1.0, 0.7, 0.4)
	_light.position = Vector2(-16, -100)
	add_child(_light)
	super._ready()
	_show(lit)


## The lantern whose light covers `point`, or null in the dark.
static func light_at(tree: SceneTree, point: Vector2) -> LanternPost:
	for node in tree.get_nodes_in_group(&"light_zones"):
		var post := node as LanternPost
		if post and post.lit and post.covers(point):
			return post
	return null


func covers(point: Vector2) -> bool:
	var d := point - global_position
	return absf(d.x) < radius and d.y > -radius and d.y < 160.0


func can_interact() -> bool:
	return not lit and GameState.get_flag(HAND_LANTERN_FLAG)


func interact(_player: Patch) -> void:
	if can_interact():
		light()


func light() -> void:
	if lit:
		return
	lit = true
	_dark_for = 0.0
	_show(true)
	AudioManager.play_sfx(&"pickup", 0.6, -4.0)
	# Anything wet caught in the new light runs from it.
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Soggy and covers((enemy as Node2D).global_position):
			(enemy as Soggy).flee_light(self)


func snuff() -> void:
	if not lit:
		return
	lit = false
	_show(false)
	AudioManager.play_sfx(&"page_flip", 1.5, -8.0)


func _show(on: bool) -> void:
	_sprite.texture = ON if on else OFF
	_light.energy = 1.3 if on else 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if not lit:
		return
	_time += delta
	var flicker := 0.92 + 0.08 * sin(_time * 9.0) * sin(_time * 3.1)
	if gutter_after > 0.0:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player and covers(player.global_position):
			_dark_for = 0.0
		else:
			_dark_for += delta
		var left := gutter_after - _dark_for
		if left <= 0.0:
			snuff()
			return
		if left < 1.5:
			# Guttering: it stutters before it goes.
			flicker *= 0.4 + 0.6 * absf(sin(_time * 23.0))
	_light.energy = 1.3 * flicker
